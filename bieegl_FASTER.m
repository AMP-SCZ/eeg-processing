function [ eeg, ChanProp, bssccaStats, icaData ] = bieegl_FASTER( eeg, epochEventCodes, epochWinSec, baselineWinSec, icaWinSec,...
	Ieeg, filterFcn, filterBand, Ifilter, refType, IcomputeRef, IremoveRef, IcomputeInterp, IexcludeInterp, zThreshInterp, compMethod, Iocular,...
	logFile, logStr, replaceLog )
% BIEEGL implementation of FASTER with BSS-CCA cleaning inserted
% FASTER is described in doi:10.1016/j.neumeth.2010.07.015
%
%
% Ieeg         indices of EEG channels, not EOG, EMG etc.
% Iref         indices of channels to average for re-referencing
% IrefExclude  indices of channels to exclude from being re-referenced, e.g. non-physiological stuff like photosensor
% IpropExclude indices of channels to exclude from FASTER channel property stats, 
%              e.g. high-offset channels BJR flagged w/ BioSemi system
%              these will get automatically interpolated if they are in Ieeg
% Iocular      indices of EOG channels, used in PCA cleaning
%
% Ieeg, Iref, IrefExclude, IpropExclude can be input either as integer indices
% or cell vector of char labels & they'll get converted to integers
%
% original pipeline by Brian Roach
%
% Dependencies: EEGLAB w/ FASTER plugin, ADJUST

% you could have physiological non-EEG channels that you might want rereferenced, hence the need for the IrefExlude input
% IpropExclude allows for high-offset functionality that was present in older BJR BioSemi code

% Note: For VODMMN task, BJR was doing ICA on MMN epochs only & using that result again for VOD!

% uses R:\ERP Research\Brian\Brian''s Matlab Stuff\ADJUST1.1.1\ADJUST.m

		% SWITCH UP ORDER?  FILTER > CRAZY DATA REMOVAL (time) > ARTIFACT CORRECT (e.g. ICA blinks) > REREF > EPOCH > ARTIFACT REJECT (author thinks OK on continuous)
		% see https://erpinfo.org/order-of-steps


	try

		narginchk( 5, 20 )
		
		% Validate inputs:
		% required inputs
		% -- eeg
		nRun = numel( eeg );
		if any( [ eeg(2:nRun).nbchan ] ~= eeg(1).nbchan )
			error( 'inconsistent #channels per file' )
		end
		for iRun = 2:nRun
			if ~all( strcmp( { eeg(iRun).chanlocs.labels }, { eeg(1).chanlocs.labels } ) )
				error( 'inconsistent channels labels across files' )
			end
		end
		% -- epochEventCodes
		if ~iscell( epochEventCodes )
			error( 'non-cell epoch event codes input' )
		elseif ~all( cellfun( @ischar, epochEventCodes ) )
			error( 'unsupported epoch event codes class' )
		else
			for iRun = 1:nRun
				if ~all( ismember( epochEventCodes, { eeg(iRun).event.type } ) )
					error( 'invalid epoch event codes input' )
				end
			end
		end
		% -- epochWinSec
		if ~isnumeric( epochWinSec ) || numel( epochWinSec ) ~= 2 || diff( epochWinSec ) <= 0
			error( 'invalid epoch window input, must be [ timeLow, timeHigh ] (sec)' )
		end
		% -- baselineWinSec
		if ~isnumeric( baselineWinSec ) || numel( baselineWinSec ) ~= 2 || diff( baselineWinSec ) <= 0
			error( 'invalid baseline window input, must be [ timeLow, timeHigh ] (sec)' )
		end
		% -- icaWinSec
		if ~isnumeric( icaWinSec ) || numel( icaWinSec ) ~= 2 || diff( icaWinSec ) <= 0
			error( 'invalid ICA window input, must be [ timeLow, timeHigh ] (sec)' )
		end
		
		% optional inputs
		% -- EEG channel(s)
		if exist( 'Ieeg', 'var' ) ~= 1
			Ieeg = [];
		else
			Ieeg = getChanInd( Ieeg, 'EEG' );
		end
		if isempty( Ieeg )
			Ieeg = 1:eeg(1).nbchan;		% all channels
		end
		% -- filter function
		if exist( 'filterFcn', 'var' ) ~= 1 || isempty( filterFcn )
			filterFcn = 'removeTrend';
		end
		if ~ischar( filterFcn ) || ~ismember( filterFcn, { 'pop_eegfilt', 'pop_eegfiltnew', 'pop_basicfilter', 'removeTrend' } )
			error( 'invalid filter function' )
		end
		% -- filter passband
		if exist( 'filterBand', 'var' ) ~= 1 || isempty( filterBand )
			filterBand = [ 0.1, inf ];
		elseif ~isnumeric( filterBand ) || numel( filterBand ) ~= 2 || diff( filterBand ) <= 0
			error( 'invalid filter band input, must be [ lowFreq, highFreq ]' )
		end
		if strcmp( filterFcn, 'removeTrend' ) && ~isinf( filterBand(2) )
			error( '%s can''t do bandpass', filterFcn )
		end
		% -- filter channel(s)
		if exist( 'Ifilter', 'var' ) ~= 1
			Ifilter = [];
		else
			Ifilter = getChanInd( Ifilter, 'filter' );
		end
		if isempty( Ifilter )
			Ifilter = 1:eeg(1).nbchan;		% all channels
		end
		% -- reference type
		if exist( 'refType', 'var' ) ~= 1
			refType = 'robust';
		elseif ~ischar( refType ) || ~ismember( refType, { 'robust', 'average', 'mean', 'none' } )
			error( 'invalid reference type' )
		end
		% -- channel(s) used to compute reference
		if exist( 'IcomputeRef', 'var' ) ~= 1
			IcomputeRef = Ieeg;
		else
			IcomputeRef = getChanInd( IcomputeRef, 'reference' );
		end
		% -- channel(s)	that get re-referenced
		if exist( 'IremoveRef', 'var' ) ~= 1
			IremoveRef = Ieeg;
		else
			IremoveRef = getChanInd( IremoveRef, 'reference' );				
		end
		% -- channel(s)	to include in property distributions that are candidates for interpolation
		if exist( 'IcomputeInterp', 'var' ) ~= 1
			IcomputeInterp = Ieeg;
		else
			IcomputeInterp = getChanInd( IcomputeInterp, 'interp' );
		end
		if exist( 'IexcludeInterp', 'var' ) ~= 1
			IexcludeInterp = setdiff( 1:eeg(1).nbchan, Ieeg );
		else
			IexcludeInterp = getChanInd( IexcludeInterp, 'interp' );
		end
		% -- z-score thresholds for interpolating channels [ mean correlation, variance, hurst exponent ]
		if exist( 'zThreshInterp', 'var' ) ~= 1
			zThreshInterp = [ 3, 3, 3 ];		% faster defaults are 3
		elseif ~isnumeric( zThreshInterp ) || numel( zThreshInterp ) ~= 3 || any( zThreshInterp <= 0 )
			error( 'invalid z threshold for channel interpolation' )
		end
		% -- ICA component rejection method
		if exist( 'zThreshInterp', 'var' ) ~= 1
			compMethod = 'ADJUST';
		elseif ~ischar( compMethod ) || ~ismember( compMethod, { 'FASTER', 'ADJUST' } )
			error( 'invalid ICA component rejection method' )
		end
		% -- EOG channel(s) used by FASTER ICA rejection method only
		if exist( 'Iocular', 'var' ) ~= 1
			Iocular = [];
		else
			Iocular = getChanInd( Iocular, 'ocular' );
		end
		% -- log file
		if exist( 'replaceLog', 'var' ) ~= 1
			replaceLog = false;
		elseif ~islogical( replaceLog ) || ~isscalar( replaceLog )
			error( 'replaceLog must be logical scalar' )
		end
		writeLog = exist( 'logFile', 'var' ) == 1 && ~isempty( logFile );
		if writeLog
			if replaceLog
				permStr = 'w';
			else
				permStr = 'a+';		% is the + needed?
			end
			fidLog = fopen( logFile, permStr );		% creates empty file if it doesn't exist
			if fidLog == -1
				error( 'Can''t open log file %s', logFile )
			end
			writeToLog( '%s\n', repmat( '-', [ 1, 80 ] ) )
			if exist( 'logStr', 'var' ) == 1 && ~isempty( logStr )
				writeToLog( '%s\n', logStr )
			end
			writeToLog( '%s started @ %s\n', mfilename, datestr( now, 'yyyymmddTHHMMSS' ) )
		end

		
		% ======================================================================

% 		for iRun = 1:nRun
% 			if ~isdouble( eeg(iRun).data )
% 				eeg(iRun).data = double( eeg(iRun).data );
% 			end
% 		end
		
		% 0.2: Filter
		%      add in input option for this switch?
		if filterBand(1) <= 0 && isinf( filterBand(2) )
			writeToLog( 'passband = [ %g, %g ] Hz, i.e. no filtering!\n', filterBand )
		else
			switch filterFcn
				case 'pop_eegfilt'		% Legacy EEGLAB
					writeToLog( 'Legacy EEGLAB filter (%s)', filterFcn )
					for iRun = 1:nRun
						eegOut = pop_eegfilt( eeg(iRun), filterBand(1), filterBand(2) );	% much slower, way steeper falloff
						eeg(iRun).data(Ifilter,:) = eegOut.data(Ifilter,:);
					end
					clear eegOut
				case 'pop_eegfiltnew'		% Modern EEGLAB
					writeToLog( 'Modern EEGLAB filter (%s)', filterFcn )
					if isinf( filterBand(2) )
						for iRun = 1:nRun
							eegOut = pop_eegfiltnew( eeg(iRun), filterBand(1), [] );
							eeg(iRun).data(Ifilter,:) = eegOut.data(Ifilter,:);
						end
					elseif filterBand(1) == 0
						for iRun = 1:nRun
							eegOut = pop_eegfiltnew( eeg(iRun), [], filterBand(2) );
							eeg(iRun).data(Ifilter,:) = eegOut.data(Ifilter,:);
						end
					else
						for iRun = 1:nRun
							eegOut = pop_eegfiltnew( eeg(iRun), filterBand(1), filterBand(2) );
							eeg(iRun).data(Ifilter,:) = eegOut.data(Ifilter,:);
						end
					end
					clear eegOut
				case 'pop_basicfilter'		% ERPLAB
					% note: pop_basicfilter requires numeric channel inputs
					removeDC   = 'on';
					filterType = 'butter';		% 'butter' or 'fir'
					filterOpts = { 'RemoveDC', removeDC, 'Design', filterType };
					writeToLog( 'ERPLAB filter (%s), type = %s, remove DC = %s', filterFcn, filterType, removeDC )
					if isinf( filterBand(2) )
						for iRun = 1:nRun
							eeg(iRun) = pop_basicfilter( eeg(iRun), Ifilter, filterOpts{:}, 'Filter', 'highpass', 'Cutoff', filterBand(1) );
						end
					elseif filterBand(1) == 0
						for iRun = 1:nRun
							eeg(iRun) = pop_basicfilter( eeg(iRun), Ifilter, filterOpts{:}, 'Filter', 'lowpass',  'Cutoff', filterBand(2) );
						end
					else
						for iRun = 1:nRun
							eeg(iRun) = pop_basicfilter( eeg(iRun), Ifilter, filterOpts{:}, 'Filter', 'bandpass', 'Cutoff', filterBand    );
						end
					end
				case 'removeTrend'		% PREP
					writeToLog( 'PREP filter (%s)', filterFcn )
					% see http://vislab.github.io/EEG-Clean-Tools/
					% removeTrend converts eeg.data to double
					% no band pass option even though pop_eegfiltnew.m supports it
					% w/ 'high pass' option, basically does eeg.data(detrendChannels,:) = pop_eegfiltnew( eeg.data(detrendChannels,:), detrendCutoff, [] );
					% high pass cutoff is barely attenuated.
					%	w/ 0.1 Hz, -3dB is around 0.062 & @0.1 Hz there's ~-0.04 dB
					%	w/ 0.2 Hz, -3dB is around 0.125 & @0.1 Hz there's ~-6 dB & @0.2Hz ~-0.03 dB
					% work as advertised, only requested channels are detrended
					detrendOpts = struct(...
						'detrendCutoff'  , filterBand(1),...	% default = 1Hz
						'detrendChannels', Ifilter );
				% 		'detrendType'    , 'high pass',...		% ['high pass'], 'high pass sinc', 'linear', 'none'
				% 		'detrendStepSize', 0.02,...				% only used for linear detrendType
% 					[ eeg, detrendOpts ] = removeTrend( eeg, detrendOpts );		% fills & defaults & adds detrendOpts.detrendCommand
					% I don't like the output of PREP's cleanLineNoise at all
% 					lineNoiseOpts = struct( ... );
					for iRun = 1:nRun
						eeg(iRun) = removeTrend( eeg(iRun), detrendOpts );
%						[ eeg(iRun), lineNoiseOptsOut ] = cleanLineNoise( eeg(iRun), lineNoiseOpts );
					end
			end
			writeToLog( ', passband = [ %g, %g ] Hz\n\tfilter channels:', filterBand )
			writeToLog( ' %s', eeg(1).chanlocs(Ifilter).labels )
			writeToLog( '\n' )
		end

		% 0.1: Re-reference
		%      FASTER paper uses Fz reference here, BIEEGL does not
		%      erpinfo.org suggesting filtering before re-referencing
		%      BIEEGL has done it the other way to avoid onset transients
		%      FASTER re-references before filtering too
		%      really doesn't make a lot of difference
		switch refType
			case 'none'
				writeToLog( 'No Re-Referencing' )
			case 'robust'
				writeToLog( 'Robust Re-Referencing\n\tcompute ref channels:' )
				writeToLog( ' %s', eeg(1).chanlocs(IcomputeRef).labels )
				writeToLog( '\n\tremove ref channels:' )
				writeToLog( ' %s', eeg(1).chanlocs(IremoveRef).labels )
				% see http://vislab.github.io/EEG-Clean-Tools/
				rerefOpts = struct(...
					'referenceChannels'          , IcomputeRef,...		% channel indices for rereferencing, eeg only, not eog or mastoids
					'evaluationChannels'         , IcomputeRef,...		% channel indices for evaluating noisy channels, not extraneous channels, often same as referenceChannels
					'rereference'                , IremoveRef,...		% channel indices from which to subtract computed reference
					'robustDeviationThreshold'   , 5,...
					'referenceType'              , 'robust' );
% 					'interpolationOrder'         , 'post-reference',...
% 					'meanEstimationType'         , 'median',...
% 					'highFrequencyNoiseThreshold', 5,...
% 					'correlationWindowSeconds'   , 1,...
% 					'correlationThreshold'       , 0.4,...
% 					'badTimeThreshold'           , 0.01,...
% 					'ransacOff'                  , false,...
% 					'ransacSampleSize'           , 50,...
% 					'ransacChannelFraction'      , 0.25,...
% 					'ransacCorrelationThreshold' , 0.75,...
% 					'ransacUnbrokenTime'         , 0.4,...
% 					'ransacWindowSeconds'        , 5,...
% 					'maxReferenceIterations'     , 4,...
% 					'reportingLevel'             , 'verbose',...
				for iRun = 1:nRun
%					[ eeg(iRun), rerefOptsOut ] = performReference( eeg(iRun), rerefOpts );
					[ ~, rerefOptsOut ] = performReference( eeg(iRun), rerefOpts );
					eeg(iRun).data(IremoveRef,:) = bsxfun( @minus, eeg(iRun).data(IremoveRef,:), rerefOptsOut.referenceSignal );
				end
			otherwise
				writeToLog( 'Average Re-Referencing\n\tcompute ref channel(s):' )
				writeToLog( ' %s', eeg(1).chanlocs(IcomputeRef).labels )
				writeToLog( '\n\tremove ref channels:' )
				writeToLog( ' %s', eeg(1).chanlocs(IremoveRef).labels )
				IexcludeRef = setdiff( 1:eeg(1).nbchan, IremoveRef );
% 				writeToLog( '\nexclude ref channels:' )
% 				writeToLog( ' %s', eeg(1).chanlocs(IexcludeRef).labels )
				if numel( IcomputeRef ) == 1
					keepRef = 'off';
				else
					keepRef = 'on';
				end
				for iRun = 1:nRun
					if isempty( IexcludeRef )
						eeg(iRun) = pop_reref( eeg(iRun), IcomputeRef, 'keepref', keepRef );
					else
						eeg(iRun) = pop_reref( eeg(iRun), IcomputeRef, 'keepref', keepRef, 'exclude', IexcludeRef );
					end
				end
		end
		writeToLog( '\n' )

		% FASTER channel properties
		% 1: mean correlation coeffiecient of each channel w/ all other channels
		%    corrected for quadratic fit of correlation vs polar distance from ref electrode
		%    if a single electrode is used for re-referencing
		% 2: variance of each channel
		%    corrected as above
		% 3: Hurst exponent
		% all 3 properties get NaNs replaced with the non-NaN mean, then subtract the median
		chanPropName = { 'corr', 'var', 'hurst' };
		ChanProp = nan( eeg(1).nbchan, 3, nRun );
		interpOpts = struct( 'measure', true( 1, 3 ), 'z', zThreshInterp(:)' );
		if writeLog
			writeToLog( 'Outlier channel interpolation\n' )
		end
		for iRun = 1:nRun
			% ======================================================================
			% 1: Interpolate outlier channels, whole recording
			%    FASTER's channel_properties.m had errors, replaced by edited version in "modifications" folder
			if isscalar( IcomputeRef )		% refChan would be all zeros in this case
				ChanProp(IcomputeInterp,:,iRun) = channel_properties( eeg(iRun), IcomputeInterp, IcomputeRef );		% note: I had to modify channel_properties to fix a bug!
			else
				ChanProp(IcomputeInterp,:,iRun) = channel_properties( eeg(iRun), IcomputeInterp, [] );				% 3rd input is refChan, removes corr vs distance fit if scalar
			end
			chanOutlier = min_z( ChanProp(IcomputeInterp,:,iRun), interpOpts );
			IchanInterp = IcomputeInterp(chanOutlier);
			nChanInterp = numel( IchanInterp );
			if nChanInterp ~= 0
				eeg(iRun) = h_eeg_interp_spl( eeg(iRun), IchanInterp, IexcludeInterp );			% note: help says 3rd input is interpolation method, but really its channels to ignore!
			end
			if writeLog
				ChanProp(IcomputeInterp,:,iRun) = abs( zscore( ChanProp(IcomputeInterp,:,iRun), [], 1 ) );
				writeToLog( '\tRun %d/%d Interpolated channel(s):', iRun, nRun )
				if nChanInterp == 0
					writeToLog( ' none' )
				else
% 					writeToLog( ' %s', eeg(iRun).chanlocs(IchanInterp).labels )
					for iChan = IchanInterp(:)'
						[ ~, iProp ] = max( ChanProp(iChan,:,iRun) - interpOpts.z );
						writeToLog( ' %s (%s)', eeg(iRun).chanlocs(iChan).labels, chanPropName{iProp} )
					end
				end
				writeToLog( ' (%d/%d)\n', nChanInterp, eeg(iRun).nbchan )
			end

			% ======================================================================	
			% 2: Epoch data
			eeg(iRun) = pop_epoch( eeg(iRun), epochEventCodes, epochWinSec );
			
			if iRun ~= 1
				eeg(1) = pop_mergeset( eeg(1), eeg(iRun), 0 );	% 3rd input is flag for preserving ICA activations
				% free up some memory?
				eeg(iRun).data = [];
			end
	
		end
		
		if iRun ~= 1
			eeg(2:nRun) = [];
		end
		
		% BSS-CCA 
		% don't need 2nd round of channel interpolation anymore w/ my changes
		% consider doing this up front outside faster, before epoching?  
		[ eeg, bssccaStats ]= bieegl_BSSCCA( eeg, Ieeg, [ 0, 125 ], 1e3, 0.95 );

		%    Baseline correct
		%    Dan found suggestion of not doing this before ICA?
		eeg = pop_rmbase( eeg, baselineWinSec * 1e3 );

		%    Store some stuff so you can restore dimensions of eeg.data later
		%    filling rejected epochs with NaNs
		origEpoch = rmfield( eeg, setdiff( fieldnames( eeg ), { 'event', 'epoch' } ) );

		%    Remove outlier epochs
		%    eeg.chaninfo.removedchans gets added by pop_rejepoch
		epochProp    = epoch_properties( eeg, Ieeg );		% mean deviation from channel means, variance, max amplitude difference
		epochOutlier = min_z( epochProp );
		IepochRej    = find( epochOutlier );
		nEpochRej    = numel( IepochRej );
%		eeg = pop_select( eeg, 'notrial', IepochRej );	% equivalent
		eeg = pop_rejepoch( eeg, IepochRej, 0 );		% 3rd input is confirm query flag
		if writeLog
			writeToLog( 'Outlier epoch removal\n\tRejected epoch(s):' )
			if isempty( IepochRej )
				writeToLog( ' none' )
			else
				writeToLog( ' %d', IepochRej )
			end
			writeToLog( ' (%d/%d)\n', nEpochRej, numel( origEpoch.epoch ) )
		end
		

		% ======================================================================
		% 3: ICA
		%    FASTER paper says you should have at least k*#compoments^2 total data points per channel, w/ k=25
		%    pop_runica:
		%    adds a line to eeg.history			[ char ]
		%    populates empty fields 
		%		eeg.icawinv						[ nEEG  x nComp double ] pinv( icaweights ) or pinv( icaweights * icasphere )? can't tell because icasphere is identity matrix
		%		eeg.icasphere					[ nEEG  x nEEG  double ] identity matrix.  is this because of a standad locs file?
		%		eeg.icaweights					[ nComp x nEEG  double ]
		%		eeg.icachansind					[     1 x nEEG  double ]
		%		eeg.chaninfo.icachansind		[     1 x nEEG  double ]
		%       eeg.reject.gcompreject			[     1 x nComp double ] all zeros?
		%   creates new fields
		%		eeg.etc.icaweights_beforerms	[ nComp x nEEG  double ]
		%		eeg.etc.icasphere_beforerms		[ nEEG  x nEEG  double ]
		%   note
		%		eeg.icaact is still empty
		nComp = min( floor( sqrt( eeg.pnts * eeg.trials / 25 ) ), numel( Ieeg ) - nChanInterp - 1 );
		icaOpts = { 'icatype', 'runica', 'verbose', 'off', 'chanind', Ieeg, 'options', { 'extended', 1, 'pca', nComp } };
		if icaWinSec(1) > eeg.times(1) || icaWinSec(2) < eeg.times(eeg.pnts)
			eegICA = pop_select( eeg, 'time', icaWinSec );		% eeg.times >= icaWinSec(1)*1e3 & eeg.times < icaWinSec(2)*1e3
			eegICA = pop_runica( eegICA, icaOpts{:} );
			for fname = { 'icawinv', 'icasphere', 'icaweights', 'icachansind' }
				eeg.(fname{1}) = eegICA.(fname{1});
			end
			eeg.chaninfo.icachansind     = eegICA.chaninfo.icachansind;
			eeg.reject.gcompreject       = eegICA.reject.gcompreject;
			eeg.etc.icaweights_beforerms = eegICA.etc.icaweights_beforerms;
			eeg.etc.icasphere_beforerms  = eegICA.etc.icasphere_beforerms;
			clear eegICA
			% full set of components including any that will get removed
			icaData          = rmfield( eeg         , setdiff( fieldnames( eeg          ), { 'icawinv', 'icasphere', 'icaweights', 'icachansind', 'chaninfo', 'reject', 'etc' } ) );
			icaData.chaninfo = rmfield( eeg.chaninfo, setdiff( fieldnames( eeg.chaninfo ), { 'icachansind' } ) );
			icaData.reject   = rmfield( eeg.reject  , setdiff( fieldnames( eeg.reject   ), { 'gcompreject' } ) );
			icaData.etc      = rmfield( eeg.etc     , setdiff( fieldnames( eeg.etc      ), { 'icaweights_beforerms', 'icasphere_beforerms' } ) );
% 			icaData.Iremove  = [];
		else
			eeg = pop_runica( eeg, icaOpts{:} );
% 			icaData = struct( 'Iremove', [] );
		end

		% note: eeg_getdatact( eeg, 'component', Icomp ) is getting the ICA component waveforms for a chosen set of components
		%       eeg_getdatact( eeg, 'component', Icomp ) = reshape( eeg.icaweights(Icomp,:) * eeg.icasphere * eegICA.data(Ichan,:), [ numel(Icomp), eeg.pnts, eeg.trials ] )
		eeg.icaact = eeg_getdatact( eeg, 'component', 1:nComp );
% 		eeg.icaact = eeg_getica( eeg, 1:nComp );		% from inside component_properties.m a much simpler m-file.  eeg_getdatact.m is capable of loading components from *.icaact files
														% eeg_getica is considerably slower & dumps text to command window

		icaData.icaact = eeg.icaact;

		switch compMethod
			case 'FASTER'		% default EEGLAB FASTER plugin component rejection

				compProp        = component_properties( eeg, Iocular, [ 1.5, 55 ] );		% compProp    = #components x 5
				compOutlier     = min_z( compProp );									% compOutlier = #components x 1
				icaData.Iremove = find( compOutlier );									% IcompRempve = # x 1

			case 'ADJUST'		% ADJUST component rejection

				% addpath( 'R:\ERP Research\Brian\Brian''s Matlab Stuff\ADJUST1.1.1', '-begin' )

				% note: pop_select as below removes icaact, needs to be recalculated
				eegOnly        = pop_select( eeg, 'channel', Ieeg );
				eegOnly.icaact = eeg_getdatact( eegOnly, 'component', 1:size( eegOnly.icaweights, 1 ) );	% can size( icaweights, 1 ) ever not equal nComp here?

				% logFile = fullfile( matDir, sprintf( '%s_%s_%s.log', subjTag(5:end), sessTag(5:end), epochName ) );
				[ logPath, logName ] = fileparts( logFile );
				adjustFile           = fullfile( logPath, [ logName, '_ADJUST.txt' ] );
				icaData.Iremove      = ADJUST( eegOnly, adjustFile )';		% 1st output is "List of artifacted ICs" does it need to be transposed? returns a row vector
																			% output file is mandatory, gets overwritten

				% Iart is the union of the others
% 				[ Iart, Ihem, Ivem, Iblink, Idisc ] = ADJUST( eegOnly, adjustFile );
% 				icaData.Iremove = Iart';
% 				keyboard
				% Outputs:
				%   art        - List of artifacted ICs
				%   horiz      - List of HEM ICs 
				%   vert       - List of VEM ICs   
				%   blink      - List of EB ICs     
				%   disc       - List of GD ICs     
				%   soglia_DV  - SVD threshold      
				%   diff_var   - SVD feature values
				%   soglia_K   - TK threshold      
				%   meanK      - TK feature values
				%   soglia_SED - SED threshold      
				%   SED        - SED feature values
				%   soglia_SAD - SAD threshold      
				%   SAD        - SAD feature values
				%   soglia_GDSF- GDSF threshold      
				%   GDSF       - GDSF feature values
				%   soglia_V   - MEV threshold      
				%   nuovaV     - MEV feature values

				clear eegOnly
		end
		
		nCompRemove = numel( icaData.Iremove );
		if writeLog
			writeToLog( '%s ICA artifact rejection\n\tRemoved ICA components(s):', compMethod )
			if isempty( icaData.Iremove )
				writeToLog( ' none (%d/%d)\n', nCompRemove, nComp )
			else
				% project components and compute variance accounted for (%)
% 				if strcmp( compMethod, 'ADJUST' )
% 					[ ~, varRemove ] = compvar( eeg.data(Ieeg,:,:),   eegOnly.icaact                 , eeg.icawinv, icaData.Iremove );
% 				else
					[ ~, varRemove ] = compvar( eeg.data(Ieeg,:,:), { eeg.icasphere, eeg.icaweights }, eeg.icawinv, icaData.Iremove );
% 				end
				writeToLog( ' %d', icaData.Iremove )
				writeToLog( ' (%d/%d) %0.2f%% variance\n', nCompRemove, nComp, varRemove )
			end
		end
		% compvar() call has to be before components get removed by pop_subcomp, logging before doing in reverse of the normal order
		eeg = pop_subcomp( eeg, icaData.Iremove, 0, 0 );		% icaact will get reset to []

%{
		% ======================================================================
		% 4: Channels within non-rejected epochs
		%    bad channels have already been interpolated, use them all here
		%    this is currently overwriting chanOutlier, IchanInterp, nChanInterp & not storing individual trial parameters
		IchanInterp = cell( 1, eeg.trials );
% 		mu = mean( eeg.data(Ieeg,:), 2 );
		for iEpoch = 1:eeg.trials
			% the only difference of BJR's single_epoch_channel_propertiesMu.m is that it computes the mean over for each channel over dimensions 2&3 outside this loop to save time
% 			chanProp    = single_epoch_channel_propertiesMu( eeg, iEpoch, Ieeg, mu );
			chanProp    = single_epoch_channel_properties(   eeg, iEpoch, Ieeg );
			chanOutlier = min_z( chanProp );
			IchanInterp{iEpoch} = Ieeg(chanOutlier);
		end
		nChanInterp = cellfun( @numel, IchanInterp );

		% interpolate channels w/i epochs
		eeg = h_epoch_interp_spl( eeg, IchanInterp, IrefExclude );
		if writeLog
			writeToLog( 'Within-epoch channel interpolation\n' )
			IepochKeep = setdiff( 1:eeg.trials+nEpochRej, IepochRej );
			for iEpoch = 1:eeg.trials
				writeToLog( 'Epoch %03d, Interpolated channel(s):', IepochKeep(iEpoch) )	% label epoch correctly with rejected epochs included in the indexing
				if isempty( IchanInterp{iEpoch} )
					writeToLog( ' none' )
				else
					writeToLog( ' %s', eeg.chanlocs(IchanInterp{iEpoch}).labels )
				end
				writeToLog( ' (%d/%d)\n', nChanInterp(iEpoch), eeg.nbchan )
			end
		end
%}

		% remove baseline
		eeg = pop_rmbase( eeg, baselineWinSec * 1e3 );

		% Return rejected trials to the data structure as NaN
		eeg.trials = eeg.trials + nEpochRej;
		dataFull = nan( eeg.nbchan, eeg.pnts, eeg.trials );
		dataFull(:,:,setdiff( 1:eeg.trials, IepochRej )) = eeg.data;
		eeg.data = dataFull;
		clear dataFull

		% put the events back in to position:
		eeg.event   = origEpoch.event;
		eeg.epoch   = origEpoch.epoch;
		clear origEpoch
		
		writeToLog( '%s finished @ %s\n\n\n', mfilename, datestr( now, 'yyyymmddTHHMMSS' ) )
		if fclose( fidLog ) == -1
			warning( 'MATLAB:fcloseError', 'fclose error' )
		end
		
	catch ME

		if exist( 'fidLog', 'var' ) == 1 && fidLog ~= -1 && ~isempty( fopen( fidLog ) )		% log file still open
			writeToLog( '%s: %s\n', ME.stack(1).name, ME.message )
			if fclose( fidLog ) == -1
				warning( 'MATLAB:fcloseError', 'fclose error' )
			end
		end
		fclose( 'all' );		% close any open BV files
		assignin( 'base', 'ME', ME )
% 		keyboard
		rethrow( ME )

	end
	
	return
	
	function chanInds = getChanInd( chanList, listType )
		% convert cell or char channels to numeric indices
		% or check numeric indices for having valid values
		if iscell( chanList ) || ischar( chanList )
% 			chanInds = eeg_chaninds( eeg, chanList );							% eeg_chaninds.m sorts outputs! misleading an generally undesirable
			[ ~, chanInds ] = ismember( chanList, { eeg(1).chanlocs.labels } );
			if any( chanInds == 0 )
				error( 'invalid %s channel(s) input', listType )
			end
		elseif ~isnumeric( chanList ) || ~all( ismember( chanList, 1:eeg(1).nbchan ) )
			error( 'invalid %s channel(s) input', listType )
		else
			chanInds = chanList;
		end		
	end

	function writeToLog( fmt, varargin )
		if writeLog
			fprintf( fidLog, fmt, varargin{:} );
			fprintf(      1, fmt, varargin{:} )		% echo to command window
		end
	end

end
	