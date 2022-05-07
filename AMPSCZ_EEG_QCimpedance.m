function AMPSCZ_EEG_QCimpedance( loopType, impedanceType, replacePng, subjectID, sessionDate )
% AMPSCZ_EEG_QCimpedance( loopType, impedanceType, replacePng, [subjectID], [sessionDate] )
% loopType      = 'session', 'site', 'grand', or 'single'
% impedanceType = 'first', 'last', 'min', 'max', 'mean', or 'median'
% replacePng    = true or false
% subjectID, sessionDate are only used when loopType is 'single'

% 	impedanceType = 'last';

	narginchk( 3, 5 )
			
	switch loopType

		case 'session'
			
			if nargin > 3
				warning( 'subjectID & sessionDate inputs not used with loopType %s', loopType )
			end

			sessions = AMPSCZ_EEG_findProcSessions;
			nSession = size( sessions, 1 );
			status   = zeros( nSession, 1 );		% -1 = error, 1 = keep current png, 2 = new png
			errMsg   =  cell( nSession, 1 );		% message for status==-1 sessions
			for iSession = 1:nSession

				pngDir = fullfile( AMPSCZ_EEG_procSessionDir( sessions{iSession,2}, sessions{iSession,3}, sessions{iSession,1}(1:end-2) ), 'Figures' );
				if ~isfolder( pngDir )
					mkdir( pngDir )
					fprintf( 'created %s\n', pngDir )
				end
				pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCimpedance.png' ];
				pngFile = fullfile( pngDir, pngName );
				if exist( pngFile, 'file' ) == 2 && ~replacePng
					fprintf( '%s exists\n', pngName )
					status(iSession) = 1;
					continue
				end

				close all
				try
					AMPSCZ_EEG_impedanceData( sessions{iSession,2}, sessions{iSession,3}, impedanceType );
				catch ME
					errMsg{iSession} = ME.message;
					warning( ME.message )
					status(iSession) = -1;
					continue
				end

				hFig = findobj( 'Type', 'figure', 'Tag', 'AMPSCZ_EEG_impedanceData' );
				figPos = get( hFig, 'Position' );
				img = getfield( getframe( hFig ), 'cdata' );
				% PC only thing?  where matlab ScreenSize doesn't match actual display resolution
				if size( img, 1 ) ~= figPos(4)
					img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
				end

				% save
				imwrite( img, pngFile, 'png' )
				fprintf( 'wrote %s\n', pngFile )
				status(iSession) = 2;
				
			end
			kProblem = status <= 0;
			if any( kProblem )
				fprintf( '\n\nProblem Sessions:\n' )
				kProblem = find( kProblem );
				for iProblem = 1:numel( kProblem )
					fprintf( '\t%s\t%s\t%s\n', sessions{kProblem(iProblem),2:3}, errMsg{kProblem(iProblem)} )
				end
				fprintf( '\n' )
			end

		case 'site'

			if nargin > 3
				warning( 'subjectID & sessionDate inputs not used with loopType %s', loopType )
			end

			allSessions = AMPSCZ_EEG_findProcSessions;
			siteNames   = unique( allSessions(:,1), 'stable' );
			nSite       = numel( siteNames );
			status      = zeros( nSite, 1 );		% -1 = error, 1 = keep current png, 2 = new png
			errMsg      =  cell( nSite, 1 );		% message for status==-1 sessions
			for iSite = 1:nSite

				siteName = siteNames{iSite};

				pngDir = fullfile( AMPSCZ_EEG_procSessionDir( [ siteName(end-1:end), 'avg' ], '00000000', siteName(1:end-2) ), 'Figures' );
				if ~isfolder( pngDir )
					mkdir( pngDir )
					fprintf( 'created %s\n', pngDir )
				end
				pngName = [ siteName(end-1:end), 'avg_00000000_QCimpedance.png' ];
				pngFile = fullfile( pngDir, pngName );
				if exist( pngFile, 'file' ) == 2 && ~replacePng
					fprintf( '%s exists\n', pngName )
					status(iSite) = 1;
					continue
				end

				sessions = allSessions( strcmp( allSessions(:,1), siteName ), : );
				nSession = size( sessions, 1 );
				Z      = nan( 64, nSession );
				Zrange = nan( nSession, 2 );
				try
					for iSession = 1:nSession
						[ Z(:,iSession), Zname, Zrange(iSession,:) ] = AMPSCZ_EEG_impedanceData( sessions{iSession,2}, sessions{iSession,3}, impedanceType );
					end
				catch ME
					errMsg{iSite} = ME.message;
					warning( ME.message )
					status(iSite) = -1;
					continue
				end

				locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
				chanlocs = readlocs( locsFile, 'importmode', 'eeglab', 'filetype', 'chanedit' );	% nose +X, left +Y
				[ ~, Iloc ] = ismember( Zname, { chanlocs.labels } );
				if any( Iloc == 0 )
					errMsg{iSite} = 'Can''t identify channel(s)';
					warning( errMsg{iSite} )
					status(iSite) = -1;
					continue
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
			kProblem = status <= 0;
			if any( kProblem )
				fprintf( '\n\nProblem Sites:\n' )
				kProblem = find( kProblem );
				for iProblem = 1:numel( kProblem )
					fprintf( '\t%s\t%s\n', siteNames{kProblem(iProblem)}, errMsg{kProblem(iProblem)} )
				end
				fprintf( '\n' )
			end
			
		case 'grand'

			% average all sessions all sites
			error( 'under construction' )
			

			AMPSCZdir = AMPSCZ_EEG_paths;
			sessions  = AMPSCZ_EEG_findProcSessions;
			nSession  = size( sessions, 1 );
			status    = false( nSession, 1 );
			errMsg    =  cell( nSession, 1 );

% 			pngDir = fullfile( AMPSCZ_EEG_procSessionDir( 'GRANavg', '00000000', 'Pronet' ), 'Figures' );
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

		case 'single'
			
			error( 'under construction' )		% need to save pngs
			AMPSCZ_EEG_impedanceData( subjectID, sessionDate, impedanceType );
			
% 			vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, 'all', 'all', 'all', 'all', 'all', false ); vhdr = fullfile( { vhdr.folder }, { vhdr.name } )'

	end
