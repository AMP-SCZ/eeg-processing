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
%	VODMMNruns = vector of VODMMN  runs.  default = 1:5.  use 0 for none
%	AODruns    = vector of AOD     runs.  default = 1:4.  use 0 for none
%	ASSRruns   = vector of ASSR    runs.  default = 1.    use 0 for none
%	RestEOruns = vector of Rest EO runs.  default = 1.    use 0 for none
%	RestECruns = vector of Rest EC runs.  default = 1.    use 0 for none
%	bandWidth  = EEG filter pass band.    default = [ 0.2, Inf ] (Hz)
%	padTime    = time [ before, after ] [ first, last ] event.  default = [ -1, 2 ] (sec)
%
% e.g. load 4 AOD runs only
% >> EEG = AMPSCZ_EEG_eegMerge( 'SF12345', '20220101', 0, [], 0, 0, 0 )


	narginchk( 2, 9 )

	useDefaultRuns = [
		exist( 'VODMMNruns', 'var' ) ~= 1 || isempty( VODMMNruns )
		exist( 'AODruns'   , 'var' ) ~= 1 || isempty( AODruns    )
		exist( 'ASSRruns'  , 'var' ) ~= 1 || isempty( ASSRruns   )
		exist( 'RestEOruns', 'var' ) ~= 1 || isempty( RestEOruns )
		exist( 'RestECruns', 'var' ) ~= 1 || isempty( RestECruns )
	];
	
	if useDefaultRuns(1)
		VODMMNruns = 1:5;
	else
		VODMMNruns = validateRuns( VODMMNruns, 'VODMMNruns' );
	end
	if useDefaultRuns(2)
		AODruns = 1:4;
	else
		AODruns = validateRuns( AODruns, 'AODruns' );
	end
	if useDefaultRuns(3)
		ASSRruns = 1;
	else
		ASSRruns = validateRuns( ASSRruns, 'ASSRruns' );
	end
	if useDefaultRuns(4)
		RestEOruns = 1;
	else
		RestEOruns = validateRuns( RestEOruns, 'RestEOruns' );
	end
	if useDefaultRuns(5)
		RestECruns = 1;
	else
		RestECruns = validateRuns( RestECruns, 'RestECruns' );
	end
	function Irun = validateRuns( Irun, runLabel )
		if ~isnumeric( Irun ) || ~isvector( Irun ) || any( mod( Irun, 1 ) ~= 0 )
			error( 'non-numeric, non-vector, or non-integer %s', runLabel )
		elseif isscalar( Irun ) && Irun == 0
			Irun = [];
		end
	end
	
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

	siteId   = subjectID(1:2);
	siteInfo = AMPSCZ_EEG_siteInfo;
	iSite    = ismember( siteInfo(:,1), siteId );
	switch nnz( iSite )
		case 1
% 			iSite = find( iSite );
		case 0
			error( 'Invalid site identifier' )
		otherwise
			error( 'non-unique site bug' )
	end
	
	AMPSCZdir   = AMPSCZ_EEG_paths;
	networkName = siteInfo{iSite,2};
	bidsDir     = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ],...
	                        'processed', subjectID, 'eeg', [ 'ses-', sessionDate ], 'BIDS' );
	if ~isfolder( bidsDir )
		error( '%s is not a valid directory', bidsDir )
	end
	vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-%s_run-%02d_eeg.vhdr' ];
	vhdr = dir( fullfile( bidsDir, strrep( strrep( vhdrFmt, '%s', '*' ), '%02d', '*' ) ) );
	nHdr = numel( vhdr );
	
	runNames = [...
		cellfun( @(u)sprintf( vhdrFmt, 'VODMMN', u ), num2cell( VODMMNruns ), 'UniformOutput', false ),...
		cellfun( @(u)sprintf( vhdrFmt, 'AOD'   , u ), num2cell( AODruns    ), 'UniformOutput', false ),...
		cellfun( @(u)sprintf( vhdrFmt, 'ASSR'  , u ), num2cell( ASSRruns   ), 'UniformOutput', false ),...
		cellfun( @(u)sprintf( vhdrFmt, 'RestEO', u ), num2cell( RestEOruns ), 'UniformOutput', false ),...
		cellfun( @(u)sprintf( vhdrFmt, 'RestEC', u ), num2cell( RestECruns ), 'UniformOutput', false ) ];
	
	% check that all requested files exist
	if ~all( ismember( runNames, { vhdr.name } ) )
		error( '%s %s: requested run(s) don''t exist', subjectID, sessionDate )
	end

	% if you're using default runs, make sure there's no extra data files
	kHdr = ismember( { vhdr.name }, runNames );
	if all( useDefaultRuns ) && ~all( kHdr )	% ( nHdr ~= 12 || ~all( kHdr ) )
		% if using all defaults then there are 12 runNames
		% if there are extra files then they won't all be in run names
		% it there are too few then you've already thrown error above
		error( '%s %s: Non-standard run sequence, run indices must be supplied for this session', subjectID, sessionDate )
	end
	
	% remove unused data files
	if ~all( kHdr )
		vhdr(~kHdr) = [];
		nHdr(:) = numel( vhdr );
	end
	clear kHdr

	% sort remaining data files by date/time stamp in vmrk files
	dateint = nan( nHdr, 1 );
	for iHdr = 1:nHdr
		M = bieegl_readBVtxt( fullfile( vhdr(iHdr).folder, [ vhdr(iHdr).name(1:end-3), 'mrk' ] ) );
		dateint(iHdr) = eval( M.Marker.Mk(1).date );
	end
	if any( isnan( dateint ) )
		error( 'can''t resolved time/date stamps' )
	end
	[ ~, Isort ] = sort( dateint, 'ascend' );
	vhdr(:) = vhdr(Isort);
	
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
		eeg = pop_resample( eeg, 250 );
		if isinf( bandWidth(2) )
			if ~isinf( bandWidth(1) )
				eeg = pop_eegfiltnew( eeg, bandWidth(1),           [] );
			end
		elseif isinf( bandWidth(1) )
				eeg = pop_eegfiltnew( eeg,           [], bandWidth(2) );
		else
				eeg = pop_eegfiltnew( eeg, bandWidth(1), bandWidth(2) );
		end
		if iHdr == 1
			EEG = eeg;
		else
			EEG = pop_mergeset( EEG, eeg, 0 );	% 3rd input is flag for preserving ICA activations
		end
	end

	return

end
