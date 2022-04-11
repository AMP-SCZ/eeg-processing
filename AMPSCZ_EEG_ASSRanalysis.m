function [ POW, ITC, PLA, EPM, toi, ERP, t, chanLabel ] = AMPSCZ_EEG_ASSRanalysis( eeg, toiRange, foi )
% Time-frequency analyses
% written for ASSR task, but could be more general purpose
%
% usage:
% >> [ POW, ITC, PLA, EPM, toi, foi, ERP, t, chanLabel ] = AMPSCZ_EEG_ASSRanalysis( eeg )
%
% input:
% eeg      = EEGLAB structure
% toiRange = 1x2 vector of endpoints of time window for ft_freqanalysis, choose endpoints that will be in eeg.times
% foi      = frequency vector (Hz), column
%
% outputs:
% POW = channel x frequency x time 3D array, average power across trials
% ITC = channel x frequency x time 3D array, inter-trial phase coherence
% PLA = channel x frequency x time 3D array, phase-locking angle
% EPM = channel x frequency x time 3D array, power from average across trials
% toi = time vector (s), row
% ERP = channel x time matrix of average waveforms
% t   = ERP waveform time vector (s), row
% chanLabel = 1 x channel cell array of channel names

	narginchk( 3, 3 )

	if isempty( which( 'ft_freqanalysis.m' ) )
		AMPSCZ_EEG_addFieldTrip
	end

% 	toiRange = [ -0.248, 0.748 ];		% choose endpoints that will be in EEG.times, i.e. multiples of 4ms
% 	foi      = (4:2:100)';

	toi = toiRange(1):1/eeg.srate:toiRange(2);

	% remove ICA stuff
	eeg.icawinv     = [];
	eeg.icasphere   = [];
	eeg.icaweights  = [];
	eeg.icachansind = [];
	
	% only keep EEG data, e.g. remove photosensor 'VIS' channel
	% it's cleaner to remove unused channels here, rather than in cfg structures.
	eeg = pop_select( eeg, 'channel', find( strcmp( { eeg.chanlocs.type }, 'EEG' ) ) );

	% ft_freqanalysis configuration
	% variable width values came from BJR NAPLS ASSR code
	cfgTFA            = struct;
	cfgTFA.method     = 'wavelet';				% 'wavelet' was formerly 'wltconvol'
	cfgTFA.output     = 'fourier';				% 'pow' = power-spectra, 'fourier' = complex Fourier spectrum
	cfgTFA.channel    = 'all';					% #x1 cell array, default = 'all'
	cfgTFA.trials     = 'all';					% 1x# vector
	cfgTFA.keeptrials = 'yes';					% return individual trials or average, default = 'no'
	cfgTFA.foi        = foi(:)';				% 1 x #frequencies vector
	cfgTFA.toi        = toi;					% 1 x #times vector.  centers of analysis windows (sec)
	cfgTFA.gwidth     = 3;										% length of used wavelets in standard deviations of the implicit Gaussian kernel, default = 3
	cfgTFA.width      = 7 + 7 * min( max( cfgTFA.foi / 20 - 1, 0 ), 1 );	% #cycles of the wavelet, default = 7. 
																			% non-vector width not mentioned in help, but clearly supported
																			% see ft_freqanalysis.m > ft_specest_wavelet.m
																			% this is 7 from [0,20]Hz, 14 from [40,Inf]Hz and linear between
	% exclude NaN epochs
	kNaN = shiftdim( isnan( eeg.data(1,1,:) ), 1 );
	if any( kNaN )
		% could have also used
		% eeg = pop_select( eeg, 'trial', find( ~kNaN ) );
		cfgTFA.trials = find( ~kNaN );
	end
	
	% convert EEGLAB eeg to FieldTrip data structure
	data = eeglab2fieldtrip( eeg, 'preprocessing' );
	data.sampleinfo = [ (0:eeg.trials-1)' * eeg.pnts + 1, (1:eeg.trials)' * eeg.pnts ];		% suppress "the data does not contain sampleinfo" warnings

	% ft_timelockanalysis configuration
	cfgTLA = struct(...
		'channel'   , 'all',...							% selecting subset of channels in EEGLAB structure before converting to Fieldtrip
		'latency'   , 'all',...
		'trials'    , cfgTFA.trials,...					% this will get replaced with specific trial indices below
		'keeptrials', 'no' );

	% Time-Frequency analysis, all trials
	% labels not reordered here like they were in NAPLS data?
	TFA = ft_freqanalysis( cfgTFA, data );
	if numel( TFA.label ) ~= numel( eeg.chanlocs ) || ~all( strcmp( TFA.label, { eeg.chanlocs.labels } ) )
		warning( 'EEG channel labels changed/reordered by ft_freqanalysis.m' )
	end
	spectAbs = abs( TFA.fourierspctrm );
	% power
	POW = shiftdim( mean( spectAbs.^2, 1 ), 1 );
	% normalize spectral components to unit amplitude
	spectMean = shiftdim( mean( TFA.fourierspctrm ./ spectAbs, 1 ), 1 );
	% inter-trial coherence and phase locking angle
	ITC =   abs( spectMean );		% inter-trial phase coherence, not inter-trial linear coherence, see https://www.fieldtriptoolbox.org/faq/itc/
	PLA = angle( spectMean );


	% Time-locking analysis
	% do we really need FieldTrip?  EEG epochs are already time-locked
	% TLA.avg is basically the same thing as mean( eeg.data(:,:,~kNaN), 3 )	
	% labels not reordered here like they were in NAPLS data?
	TLA = ft_timelockanalysis( cfgTLA, data );
	if numel( TFA.label ) ~= numel( TLA.label ) || ~all( strcmp( TFA.label(:), TLA.label ) )		% sanity check, probably not possible, here TFA.label is row, TLA.label is column
		error( 'FieldTrip channel label disagreement' )
	end
	t   = TLA.time;
	ERP = TLA.avg;

	% Time-Frequency analysis, on average across trials
	TLA.sampleinfo = [ 1, numel( TLA.time ) ];						% suppress "the data does not contain sampleinfo" warnings
	TFA = ft_freqanalysis( rmfield( cfgTFA, 'trials' ), TLA );		% note: I'm reusing TFA here
	if numel( TFA.label ) ~= numel( TLA.label ) || ~all( strcmp( TFA.label, TLA.label ) )		% sanity check, probably not possible, here TFA.label is a column
		error( 'FieldTrip channel label disagreement' )
	end
	EPM = shiftdim( abs( TFA.fourierspctrm ).^2, 1 );


	% SCN playing with making a stable phase angle over time
% 	PLA2 = bsxfun( @minus, unwrap( PLA, [], 3 ), shiftdim( 2*pi*foi(:)*toi, -1 ) );
% 	PLA2(:) = atan2( sin( PLA2 ), cos( PLA2 ) );

	chanLabel = TFA.label;		% column
	
end