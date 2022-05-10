function EEG = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, bandWidth, padTime )
% Load segmented runs into a single EEG structure
% There's no re-referencing or channel interpolation here, data are FCz referenced, but FCz is not in montage
% 
% Usage:
% >> EEG = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, bandWidth, padTime )
%
% mandatory inputs:
%	subjectID   = 2-char site code + 5-digit ID#.  e.g. 'SF12345'
%	sessionDate = 8-digit char date in YYYYMMDD format.  e.g. '20220101'
% optional inputs:
%	VODMMNruns = vector of VODMMN  runs.  default = 1:5.  use 0 for none, 'all' for all
%	AODruns    = vector of AOD     runs.  default = 1:4.  use 0 for none, 'all' for all
%	ASSRruns   = vector of ASSR    runs.  default = 1.    use 0 for none, 'all' for all
%	RestEOruns = vector of Rest EO runs.  default = 1.    use 0 for none, 'all' for all
%	RestECruns = vector of Rest EC runs.  default = 1.    use 0 for none, 'all' for all
%	bandWidth  = EEG filter pass band.    default = [ 0.2, Inf ] (Hz)
%	padTime    = time [ before, after ] [ first, last ] event.  default = [ -1, 2 ] (sec)
%
% e.g. load 4 AOD runs only
% >> EEG = AMPSCZ_EEG_eegMerge( 'SF12345', '20220101', 0, [], 0, 0, 0 )

	narginchk( 2, 9 )

	if exist( 'bandWidth', 'var' ) ~= 1 || isempty( bandWidth )
		bandWidth = [ 0.2, Inf ];
	elseif ~isnumeric( bandWidth ) || ~isvector( bandWidth ) || numel( bandWidth ) ~= 2 || diff( bandWidth ) <= 0
		error( 'bandWidth must be 2-element increasing numeric vector' )
	end
	if exist( 'padTime', 'var' ) ~= 1 || isempty( padTime )
		padTime = [ -1, 2 ];
	elseif ~isnumeric( padTime ) || ~isvector( padTime ) || numel( padTime ) ~= 2 || diff( padTime ) <= 0
		error( 'padTime must be 2-element increasing numeric vector' )
	end

	vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, true );
	nHdr = numel( vhdr );

	% concatenate into a single eeg structure
	for iHdr = 1:nHdr
		eeg = pop_loadbv( vhdr(iHdr).folder, vhdr(iHdr).name );
		% remove photosensor channel?
		eeg = pop_select( eeg, 'nochannel', { 'VIS' } );
		% trim?
		kEvent = ~ismember( { eeg.event.type }, 'boundary' );
		i1 = max( eeg.event(find(kEvent,1,'first')).latency +  ceil( eeg.srate * padTime(1) ),        1 );
		i2 = min( eeg.event(find(kEvent,1, 'last')).latency + floor( eeg.srate * padTime(2) ), eeg.pnts );
		if i1 > 1 || i2 < eeg.pnts
			eeg = pop_select( eeg, 'point', [ i1, i2 ] );
		end
		% resample
		eeg.data = double( eeg.data );
		eeg = pop_resample( eeg, 250 );
		% filter
		eeg.data = double( eeg.data );
		if isinf( bandWidth(2) )
			if ~isinf( bandWidth(1) )
				eeg = pop_eegfiltnew( eeg, bandWidth(1),           [] );
			end
		elseif isinf( bandWidth(1) )
				eeg = pop_eegfiltnew( eeg,           [], bandWidth(2) );
		else
				eeg = pop_eegfiltnew( eeg, bandWidth(1), bandWidth(2) );
		end
		% merge
		if iHdr == 1
			EEG = eeg;
		else
			EEG = pop_mergeset( EEG, eeg, 0 );	% 3rd input is flag for preserving ICA activations
		end
	end

	return

end
