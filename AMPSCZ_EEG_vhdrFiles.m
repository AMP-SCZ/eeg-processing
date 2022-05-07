function vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, sortFlag )
% returns dir output for segmented .vdhr files for specified runs
%
% usage:
% >> vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, [VODMMNruns], [AODruns], [ASSRruns], [RestEOruns], [RestECruns], [sortFlag] )
%
% inputs:
% VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns default to 1:5, 1:4, 1, 1, 1 respectively
%         []  will lead to defaults
%		   0  will exclude all runs of this type
%		'all' will include everything found
% sortFlag defaults to true which sorts files chronologically

	narginchk( 2, 8 )

	bidsDir     = fullfile( AMPSCZ_EEG_procSessionDir( subjectID, sessionDate ), 'BIDS' );
	if ~isfolder( bidsDir )
		error( '%s is not a valid directory', bidsDir )
	end
	vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-%s_run-%02d_eeg.vhdr' ];
	vhdr = dir( fullfile( bidsDir, strrep( strrep( vhdrFmt, '%s', '*' ), '%02d', '*' ) ) );
	nHdr = numel( vhdr );

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
		VODMMNruns = validateRuns( VODMMNruns, 'VODMMN' );
	end
	if useDefaultRuns(2)
		AODruns = 1:4;
	else
		AODruns = validateRuns( AODruns, 'AOD' );
	end
	if useDefaultRuns(3)
		ASSRruns = 1;
	else
		ASSRruns = validateRuns( ASSRruns, 'ASSR' );
	end
	if useDefaultRuns(4)
		RestEOruns = 1;
	else
		RestEOruns = validateRuns( RestEOruns, 'RestEO' );
	end
	if useDefaultRuns(5)
		RestECruns = 1;
	else
		RestECruns = validateRuns( RestECruns, 'RestEC' );
	end
	function Irun = validateRuns( Irun, taskName )
		if ischar( Irun )
			if strcmpi( Irun, 'all' )
				Irun = cellfun( @(u)str2double(u(end-10:end-9)),...
					{ vhdr(~cellfun( @isempty, regexp( {vhdr.name}, [ '_task-', taskName, '_' ], 'start', 'once' ) )).name } );
			else
				error( 'unknown run code %s', Irun )
			end
		elseif ~isnumeric( Irun ) || ~isvector( Irun ) || any( mod( Irun, 1 ) ~= 0 )
			error( 'non-numeric, non-vector, or non-integer %sruns', taskName )
		elseif isscalar( Irun ) && Irun == 0
			Irun = [];
		end
	end

	if exist( 'sortFlag', 'var' ) ~= 1 || isempty( sortFlag )
		sortFlag = true;
	elseif ~islogical( sortFlag ) || ~isscalar( sortFlag )
		error( 'sortFlag input must be logical scalar' )
	end
	
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