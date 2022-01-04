function [ eeg, ChanProp, bssccaStats, icaData ] = bieegl_FASTER( eeg, epochEventCodes, filterBand, epochWinSec, baselineWinSec, icaWinSec, Ieeg, Iref, IrefExclude, IpropExclude, Ieog, logFile, logStr )
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
% Ieog         indices of EOG channels, used in PCA cleaning
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

		narginchk( 4, 13 )
		
		nRun = numel( eeg );
		if any( [ eeg(2:nRun).nbchan ] ~= eeg(1).nbchan )
			error( 'inconsistent #channels per file' )
		end
		for iRun = 2:nRun
			if ~all( strcmp( { eeg(iRun).chanlocs.labels }, { eeg(1).chanlocs.labels } ) )
				error( 'inconsistent channels labels across files' )
			end
		end

		% Validate inputs:
		% -- epochEventCodes
		if ~iscell( epochEventCodes )
			error( 'invalid epoch event codes input' )
		elseif ischar( epochEventCodes{1} )
			for iRun = 1:nRun
				if ~all( ismember( epochEventCodes, { eeg(iRun).event.type } ) )
					error( 'invalid epoch event codes input' )
				end
			end
		% I was using numeric types for a bit - turned out to be a bad idea, no more.
% 		elseif isnumeric( epochEventCodes{1} ) 		% can't do ismember on cell of numeric!
% 			for iRun = 1:nRun
% 				if ~all( ismember( [ epochEventCodes{:} ], [ eeg(iRun).event.type ] ) )
% 					error( 'invalid epoch event codes input' )
% 				end
% 			end
		else
			error( 'unsupported epoch event codes class' )
		end
		% -- filter passband
		if exist( 'filterBand', 'var' ) ~= 1 || isempty( filterBand )
			filterBand = [ 1, inf ];
		elseif ~isnumeric( filterBand ) || numel( filterBand ) ~= 2 || diff( filterBand ) <= 0
			error( 'invalid filter band input, must be [ lowFreq, highFreq ]' )
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
		% -- EEG channel(s)
		if exist( 'Ieeg', 'var' ) ~= 1
			Ieeg = [];
		else
			Ieeg = getChanInd( Ieeg, 'EEG' );
		end
		if isempty( Ieeg )
			Ieeg = 1:eeg(1).nbchan;
		end
		% -- reference channel(s)
		if exist( 'Iref', 'var' ) ~= 1
			Iref = [];
		else
			Iref = getChanInd( Iref, 'reference' );
		end
		% -- exclude channel(s)	
		if exist( 'IrefExclude', 'var' ) ~= 1
			IrefExclude = [];
		else
			IrefExclude = getChanInd( IrefExclude, 'exclude' );				
		end
		% -- channel(s)	to interpolate no matter what
		if exist( 'IpropExclude', 'var' ) ~= 1
			IpropExclude = [];
		else
			IpropExclude = getChanInd( IpropExclude, 'exclude' );
		end
		% -- EOG channel(s)
		if exist( 'Ieog', 'var' ) ~= 1
			Ieog = [];
		else
			Ieog = getChanInd( Ieog, 'exclude' );
		end
		% -- log file
		writeLog = exist( 'logFile', 'var' ) == 1 && ~isempty( logFile );
		if writeLog
			fidLog  = fopen( logFile, 'a+' );		% creates empty file if it doesn't exist
			if fidLog == -1
				error( 'Can''t open log file %s', logFile )
			end
			writeToLog( '%s\n', repmat( '-', [ 1, 80 ] ) )
			if exist( 'logStr', 'var' ) == 1 && ~isempty( logStr )
				writeToLog( '%s\n', logStr )
			end
			writeToLog( '%s started @ %s\n', mfilename, datestr( now, 'yyyymmddTHHMMSS' ) )
		end
		eegNoRef = ismember( Ieeg, IrefExclude );
		if writeLog && any( eegNoRef )
			writeToLog( 'WARNING: %d EEG channels excluded from re-referencing!', sum( eegNoRef ) )
			writeToLog( ' %s', eeg(1).chanlocs(Ieeg(eegNoRef)).labels )
			writeToLog( '\n' )
		end

		
		% ======================================================================
		% 0.1: Re-reference
		%      FASTER paper uses Fz reference here, BIEEGL does not
		%      erpinfo.org suggesting filtering before re-referencing
		%      BIEEGL has done it the other way to avoid onset transients
		%      FASTER re-references before filtering too
		%      really doesn't make a lot of difference
		writeToLog( 'Reference channel(s):' )
		if isempty( Iref )
			writeToLog( ' none given.  Skipping re-referencing!' )
		elseif isempty( IrefExclude )		% would empty cell {} work as pop_reref input? - no, throws error
			for iRun = 1:nRun
				eeg(iRun) = pop_reref( eeg(iRun), Iref, 'keepref', 'on' );
			end
			writeToLog( ' %s', eeg(1).chanlocs(Iref).labels )
		else
			for iRun = 1:nRun
				eeg(iRun) = pop_reref( eeg(iRun), Iref, 'keepref', 'on', 'exclude', IrefExclude );
			end
			if writeLog
				writeToLog( ' %s', eeg(1).chanlocs(Iref).labels )
				writeToLog( '\nChannel(s) excluded from re-referencing:' )
				writeToLog( ' %s', eeg(1).chanlocs(IrefExclude).labels )
			end
		end
		writeToLog( '\n' )

		% 0.2: Filter
		%      add in input option for this switch?
		if filterBand(1) == 0 && isinf( filterBand(2) )
			writeToLog( 'passband = [ %g, %g ] Hz, i.e. no filtering!\n', filterBand )
		else
			switch 2
				case 0		% Legacy EEGLAB
					writeToLog( 'Legacy EEGLAB filter' )
					for iRun = 1:nRun
						eeg(iRun) = pop_eegfilt( eeg(iRun), filterBand(1), filterBand(2) );	% much slower, way steeper falloff
					end
				case 1		% Modern EEGLAB
					writeToLog( 'Modern EEGLAB filter' )
					if isinf( filterBand(2) )
						for iRun = 1:nRun
							eeg(iRun) = pop_eegfiltnew( eeg(iRun), filterBand(1),            [] );
						end
					elseif filterBand(1) == 0
						for iRun = 1:nRun
							eeg(iRun) = pop_eegfiltnew( eeg(iRun),            [], filterBand(2) );
						end
					else
						for iRun = 1:nRun
							eeg(iRun) = pop_eegfiltnew( eeg(iRun), filterBand(1), filterBand(2) );
						end
					end
				case 2		% ERPLAB
					% note: pop_basicfilter requires numeric channel inputs
					removeDC   = 'on';
					filterType = 'butter';		% 'butter' or 'fir'
					filterOpts = { 'RemoveDC', removeDC, 'Design', filterType };
					writeToLog( 'ERPLAB %s filter, remove DC = %s', filterType, removeDC )
					if isinf( filterBand(2) )
						for iRun = 1:nRun
							eeg(iRun) = pop_basicfilter( eeg(iRun), Ieeg, filterOpts{:}, 'Filter', 'highpass', 'Cutoff', filterBand(1) );
						end
					elseif filterBand(1) == 0
						for iRun = 1:nRun
							eeg(iRun) = pop_basicfilter( eeg(iRun), Ieeg, filterOpts{:}, 'Filter', 'lowpass',  'Cutoff', filterBand(2) );
						end
					else
						for iRun = 1:nRun
							eeg(iRun) = pop_basicfilter( eeg(iRun), Ieeg, filterOpts{:}, 'Filter', 'bandpass', 'Cutoff', filterBand    );
						end
					end
			end
			writeToLog( ', passband = [ %g, %g ] Hz\n', filterBand )
		end

		IpropInclude = setdiff( Ieeg, IpropExclude );
		% FASTER channel properties
		% 1: mean correlation coeffiecient of each channel w/ all other channels
		%    corrected for quadratic fit of correlation vs polar distance from ref electrode
		%    if a single electrode is used for re-referencing
		% 2: variance of each channel
		%    corrected as above
		% 3: Hurst exponent
		% all 3 properties get NaNs replaced with the non-NaN mean, then subtract the median
		ChanProp = nan( eeg(1).nbchan, 3, nRun );
		for iRun = 1:nRun
			% ======================================================================
			% 1: Interpolate outlier channels, whole recording
			%    FASTER's channel_properties.m had errors, replaced by edited version in "modifications" folder
			if isscalar( Iref )		% refChan would be all zeros in this case
				ChanProp(IpropInclude,:,iRun) = channel_properties( eeg(iRun), IpropInclude, Iref );		% note: I had to modify channel_properties to fix a bug!
			else
				ChanProp(IpropInclude,:,iRun) = channel_properties( eeg(iRun), IpropInclude, [] );				% 3rd input is refChan, removes corr vs distance fit if scalar
			end
			chanOutlier = min_z( ChanProp(IpropInclude,:,iRun) );
			IchanInterp = union( IpropInclude(chanOutlier), intersect( Ieeg, IpropExclude ), 'sorted' );	% note: re-referencing exclusions e.g. VIS not getting interpolated
			nChanInterp = numel( IchanInterp );
			if nChanInterp ~= 0
				eeg(iRun) = h_eeg_interp_spl( eeg(iRun), IchanInterp, IrefExclude );			% note: help says 3rd input is interpolation method, but really its channels to ignore!
			end
			if writeLog
				writeToLog( 'Run %d/%d Interpolated channel(s):', iRun, nRun )
				if isempty( IchanInterp )
					writeToLog( ' none' )
				else
					writeToLog( ' %s', eeg(iRun).chanlocs(IchanInterp).labels )
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
		eeg = pop_rmbase( eeg, baselineWinSec * 1e3 );

		%    Store some stuff so you can restore dimensions of eeg.data later
		%    filling rejected epochs with NaNs
		origEpoch = rmfield( eeg, setdiff( fieldnames( eeg ), { 'event', 'epoch' } ) );

		%    Remove outlier epochs
		%    eeg.chaninfo.removedchans gets added by pop_rejepoch
		epochProp    = epoch_properties( eeg, Ieeg );
		epochOutlier = min_z( epochProp );
		IepochRej    = find( epochOutlier );
		nEpochRej    = numel( IepochRej );
%		eeg = pop_select( eeg, 'notrial', IepochRej );	% equivalent
		eeg = pop_rejepoch( eeg, IepochRej, 0 );		% 3rd input is confirm query flag
		if writeLog
			writeToLog( 'Rejected epoch(s):' )
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

		compMethod = 'ADJUST';									
		switch compMethod
			case 'FASTER'		% default EEGLAB FASTER plugin component rejection

				compProp        = component_properties( eeg, Ieog, [ 1.5, 55 ] );		% compProp    = #components x 5
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
				clear eegOnly
		end
		
		nCompRemove = numel( icaData.Iremove );
		if writeLog
			writeToLog( 'Removed ICA components(s):' )
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
	