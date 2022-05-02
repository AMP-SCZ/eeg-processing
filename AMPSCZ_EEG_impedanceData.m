function [ Z, Zname, Zrange, Ztime ] = AMPSCZ_EEG_impedanceData( subjectID, sessionDate, impedanceType )
%
% usage:
% >> AMPSCZ_EEG_impedanceData( subjectID, sessionDate, [impedanceType] )
% impedanceType = 'first', 'last', 'best', 'worst', 'mean', or 'median'
%                 default is 'last'
	
	narginchk( 2, 3 )

	if exist( 'impedanceType', 'var' ) ~= 1 || isempty( impedanceType )
		impedanceType = 'last';
	elseif ~ischar( impedanceType )
		error( 'impedanceType must be char' )
	else
		impedanceType = lower( impedanceType );
		if ~ismember( impedanceType, { 'first', '1st', 'begin', 'last', 'end',...
				'best', 'minimum', 'min', 'worst', 'maximum', 'max', 'mean', 'average', 'avg', 'median', 'med' } )
			error( 'invalid impedanceType %s', impedanceType )
		end
	end
	
	if false
		[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( 'all' );
		vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, false );
	else	% faster if you're for sure finding all vhdr files
		AMPSCZdir = AMPSCZ_EEG_paths;
		siteInfo  = AMPSCZ_EEG_siteInfo;
		siteId    = subjectID(1:2);
		iSite     = ismember( siteInfo(:,1), siteId );
		switch nnz( iSite )
			case 1
% 				iSite = find( iSite );
			case 0
				error( 'Invalid site identifier' )
			otherwise
				error( 'non-unique site bug' )
		end
		networkName = siteInfo{iSite,2};
		bidsDir     = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ],...
								'processed', subjectID, 'eeg', [ 'ses-', sessionDate ], 'BIDS' );
		if ~isfolder( bidsDir )
			error( '%s is not a valid directory', bidsDir )
		end
% 		vhdrFmt = '*.vhdr';
		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-*_run-*_eeg.vhdr' ];
		vhdr = dir( fullfile( bidsDir, vhdrFmt ) );
	end
	nHdr = numel( vhdr );

	[ Z, Zrange, Ztime ] = deal( cell( 1, nHdr ) );
	for iHdr = 1:nHdr
		[ Z{iHdr}, Zrange{iHdr}, Ztime{iHdr} ] = AMPSCZ_EEG_readBVimpedance( fullfile( vhdr(iHdr).folder, vhdr(iHdr).name ) );
		if iHdr == 1
			Zname = Z{iHdr}(:,1);
		elseif size( Z{iHdr}, 1 ) ~= numel( Zname ) || ~all( strcmp( Z{iHdr}(:,1), Zname ) )
			error( 'Impedance channel mismatch across measures' )
		end
		Z{iHdr} = cell2mat( permute( Z{iHdr}(:,2,:), [ 1, 3, 2 ] ) );		% channels x measurements matrix, drop names
	end
	Z      = cat( 2, Z{:} );
	Zrange = cat( 1, Zrange{:} );
	Ztime  = cat( 1, Ztime{:}  ) * [ 3600; 60; 1 ];
	
	% Get rid of redudant copies of measurements & sort chronologically
	[ Ztime, Iu ] = unique( Ztime, 'sorted' );
	Z      = Z(:,Iu);
	Zrange = Zrange(Iu,:);
	
	% drop ground, not in locs files
	kZ = strcmp( Zname, 'Gnd' );
	Zname(kZ) = [];
	Z(kZ,:)   = [];
	clear kZ

	% drop all-NaN colums
	kNaN = all( isnan( Z ), 1 );
	if all( kNaN )
		warning( 'no impedance data found' )
	else
		Z(:,kNaN) = [];
	end
		
	% Choose measurement - this is done inside AMPSCZ_EEG_plotImpedanceTopo
	switch impedanceType
		case { 'first', '1st', 'begin' }
			Z      = Z(:,1);
			Zrange = Zrange(1,:);
		case { 'last', 'end' }
			Z      = Z(:,end);
			Zrange = Zrange(end,:);
		case { 'best', 'minimum', 'min' }
			Z = min( Z, [], 2 );
			Zrange = min( Zrange, [], 1 );
% 			Zrange = mean( Zrange, 1 );
		case { 'worst', 'maximum', 'max' }
			Z = max( Z, [], 2 );
			Zrange = max( Zrange, [], 1 );
% 			Zrange = mean( Zrange, 1 );
		case { 'mean', 'average', 'avg' }
			Z = mean( Z, 2 );
			Zrange = mean( Zrange, 1 );
		case { 'median', 'med' }
			Z = median( Z, 2 );
% 			Zrange = median( Zrange, 1 );
			Zrange = mean( Zrange, 1 );
	end
	
	if nargout ~= 0
		return
	end

% 	locsFile = 'AMPSCZ_EEG_actiCHamp65ref_noseX.ced';		% let's drop this once and for all
% 	chanlocs = readlocs( locsFile, 'importmode', 'native', 'filetype', 'chanedit' );
	locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
	chanlocs = readlocs( locsFile, 'importmode', 'eeglab', 'filetype', 'chanedit' );	% nose +X, left +Y
% 	chanlocs = pop_chanedit( chanlocs, 'lookup', Zname );
	[ ~, Iloc ] = ismember( Zname, { chanlocs.labels } );
	if any( Iloc == 0 )
		error( 'Can''t identify channel(s)' )
	end
	chanlocs = chanlocs(Iloc);
	clear Iloc


	figure( 'Position', [ 500, 300, 525, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' )		
	hAx = axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
	zThresh = 25;				% impedance threshold
	zLimit  = zThresh * 2;
	AMPSCZ_EEG_plotImpedanceTopo( hAx, Zname, Z, chanlocs, Zrange, zThresh, zLimit )

	return
	
	%%
	
	clear
	
	switch 'average'
		case 'session'
			subjectID     = 'AD00051';
			sessionDate   = '20220429';
			subjectID     = 'HK00068';		sessionDate   = '20220104';		% no impedance data found
			subjectID     = 'HK00074';		sessionDate   = '20220105';		% no impedance data found
			subjectID     = 'HK00080';		sessionDate   = '20220106';
			subjectID     = 'HK00096';		sessionDate   = '20220111';		% no impedance data found
			impedanceType = 'last';
			AMPSCZ_EEG_impedanceData( subjectID, sessionDate, impedanceType );
			
% 			vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, 'all', 'all', 'all', 'all', 'all', false ); vhdr = fullfile( { vhdr.folder }, { vhdr.name } )'
		case 'site'
			% restrict to single site
			impedanceType = 'last';

			AMPSCZdir   = AMPSCZ_EEG_paths;
			allSessions = AMPSCZ_EEG_findProcSessions;
			siteNames   = unique( allSessions(:,1), 'stable' );
			nSite       = numel( siteNames );
			status      = zeros( nSite, 1 );
			errMsg      =  cell( nSite, 1 );
			for iSite = 1:nSite

				siteName = siteNames{iSite};

				pngDir = fullfile( AMPSCZdir, siteName(1:end-2), 'PHOENIX', 'PROTECTED', siteName,...
									'processed', [ siteName(end-1:end), 'avg' ], 'eeg', 'ses-00000000', 'Figures' );
				if ~isfolder( pngDir )
					mkdir( pngDir )
					fprintf( 'created %s\n', pngDir )
% 					warning( '%s does not exist', pngDir )
% 					status(iSite) = -1;
% 					continue
				end
				pngName = [ siteName(end-1:end), 'avg_00000000_QCimpedance.png' ];
				pngFile = fullfile( pngDir, pngName );
				if exist( pngFile, 'file' ) == 2
					fprintf( '%s exists\n', pngName )
					status(iSite) = 1;
					continue
				end

				sessions  = allSessions( strcmp( allSessions(:,1), siteName ), : );
				nSession  = size( sessions, 1 );
				Z = nan( 64, nSession );
				Zrange = nan( nSession, 2 );
				try
					for iSession = 1:nSession
						[ Z(:,iSession), Zname, Zrange(iSession,:) ] = AMPSCZ_EEG_impedanceData( sessions{iSession,2}, sessions{iSession,3}, impedanceType );
					end
				catch ME
					errMsg{iSite} = ME.message;
					warning( ME.message )
					status(iSite) = -2;
					continue
				end
				locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
				chanlocs = readlocs( locsFile, 'importmode', 'eeglab', 'filetype', 'chanedit' );	% nose +X, left +Y
				[ ~, Iloc ] = ismember( Zname, { chanlocs.labels } );
				if any( Iloc == 0 )
					error( 'Can''t identify channel(s)' )
				end
				chanlocs = chanlocs(Iloc);
				clear Iloc
				close all
				hFig = figure( 'Position', [ 500, 300, 525, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
				hAx = axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
				zThresh = 25;				% impedance threshold
				zLimit  = zThresh * 2;
				AMPSCZ_EEG_plotImpedanceTopo( hAx, Zname, mean( Z, 2, 'omitnan' ), chanlocs, mean( Zrange, 1, 'omitnan' ), zThresh, zLimit, nSession )
			
				figPos = get( hFig, 'Position' );
				img = getfield( getframe( hFig ), 'cdata' );
				if size( img, 1 ) ~= figPos(4)
					img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
				end
				% save
				imwrite( img, pngFile, 'png' )
				fprintf( 'wrote %s\n', pngFile )
				status(iSite) = 2;
				
			end
			if any( status <= 0 )
				disp( siteNames( status <= 0 ) )
			end
			
		case 'average'

			% average all sites
			impedanceType = 'last';

			AMPSCZdir = AMPSCZ_EEG_paths;
			sessions  = AMPSCZ_EEG_findProcSessions;
			nSession  = size( sessions, 1 );
			status    = false( nSession, 1 );
			errMsg    =  cell( nSession, 1 );

			pngDir = fullfile( AMPSCZdir, 'Pronet', 'PHOENIX', 'PROTECTED', 'PredictGRAN',...
								'processed', 'GRANavg', 'eeg', 'ses-00000000', 'Figures' );
			if ~isfolder( pngDir )
				mkdir( pngDir )
				fprintf( 'created %s\n', pngDir )
% 				warning( '%s does not exist', pngDir )
			end
			
			pngName = 'GRANavg_00000000_QCimpedance.png';
			pngFile = fullfile( pngDir, pngName );
			if exist( pngFile, 'file' ) == 2
				fprintf( '%s exists\n', pngName )
% 				return
			end

			Z = nan( 64, nSession );
			Zrange = nan( nSession, 2 );

			for iSession = 1:nSession
				try
					[ Z(:,iSession), Zname, Zrange(iSession,:) ] = AMPSCZ_EEG_impedanceData( sessions{iSession,2}, sessions{iSession,3}, impedanceType );
					status(iSession) = true;
				catch ME
					errMsg{iSession} = ME.message;
					warning( ME.message )
					continue
				end
			end
			locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
			chanlocs = readlocs( locsFile, 'importmode', 'eeglab', 'filetype', 'chanedit' );	% nose +X, left +Y
			[ ~, Iloc ] = ismember( Zname, { chanlocs.labels } );
			if any( Iloc == 0 )
				error( 'Can''t identify channel(s)' )
			end
			chanlocs = chanlocs(Iloc);
			clear Iloc
			close all
			hFig = figure( 'Position', [ 500, 300, 525, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
			hAx = axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
			zThresh = 25;				% impedance threshold
			zLimit  = zThresh * 2;
			AMPSCZ_EEG_plotImpedanceTopo( hAx, Zname, mean( Z, 2, 'omitnan' ), chanlocs, mean( Zrange, 1, 'omitnan' ), zThresh, zLimit, nnz( status ) )

			figPos = get( hFig, 'Position' );
			img = getfield( getframe( hFig ), 'cdata' );
			if size( img, 1 ) ~= figPos(4)
				img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
			end
			% save
% 			imwrite( img, pngFile, 'png' )
% 			fprintf( 'wrote %s\n', pngFile )
				
			if ~all( status )
				disp( sessions(~status,2:3) )
			end

		case 'loop'
	end
	
	


end
