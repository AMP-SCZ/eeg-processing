function vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, sortFlag )

	narginchk( 2, 8 )

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

	if exist( 'sortFlag', 'var' ) ~= 1 || isempty( sortFlag )
		sortFlag = true;
	elseif ~islogical( sortFlag ) || ~isscalar( sortFlag )
		error( 'sortFlag input must be logical scalar' )
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
	if sortFlag
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
	end

end