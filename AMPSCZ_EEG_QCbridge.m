function AMPSCZ_EEG_QCbridge( replacePng )
% AMPSCZ_EEG_QCbridge( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_QCbridge( false )

	%% run loop over all processed sessions and make electrode bridge topo pngs if they don't already exist
	
	sessions  = AMPSCZ_EEG_findProcSessions;	
	nSession  = size( sessions, 1 );
	status    = zeros( nSession, 1 );		% -1 = error, 1 = keep current png, 2 = new png
	errMsg    =  cell( nSession, 1 );		% message for status==-1 sessions
	
	Nbridge =   nan( nSession, 1 );
	Ebridge = zeros(       63, 1);
% 	hWait   = waitbar( 0, '' );
	for iSession = 1:nSession

% 		waitbar( (iSession-1)/nSession, hWait, sessions{iSession,2} )
		pngDir = fullfile( AMPSCZ_EEG_procSessionDir( sessions{iSession,2}, sessions{iSession,3}, sessions{iSession,1}(1:end-2) ), 'Figures' );
		if ~isfolder( pngDir )
			mkdir( pngDir )
			fprintf( 'created %s\n', pngDir )
		end
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCbridge.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2 && ~replacePng
			fprintf( '%s exists\n', pngName )
			status(iSession) = 1;
			continue
		end

		close all
		try
			[ EB, ~, chanlocs ] = AMPSCZ_EEG_eBridge( sessions{iSession,2}, sessions{iSession,3} );
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			status(iSession) = -1;
			continue
		end

% 		return			% for debugging: make 1 figure, don't save, exit

		Nbridge(iSession)           = EB.Bridged.Count;
		Ebridge(EB.Bridged.Indices) = Ebridge(EB.Bridged.Indices) + 1;

		% scale if getframe pixels don't match Matlab's figure size
% 		hFig   = gcf;
		hFig   = findobj( 'Type', 'figure', 'Tag', 'AMPSCZ_EEG_eBridge' );
		figPos = get( hFig, 'Position' );
		img = getfield( getframe( hFig ), 'cdata' );
		if size( img, 1 ) ~= figPos(4)
			img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
		end
		
		% save
		imwrite( img, pngFile, 'png' )
		fprintf( 'wrote %s\n', pngFile )

		status(iSession) = 2;
% 		waitbar( iSession/nSession, hWait )
	end
% 	close( hWait )
	fprintf( 'done\n' )

	kProblem = status <= 0;		% status == 0 should be impossible
	if any( kProblem )
		fprintf( '\n\nProblem Sessions:\n' )
		kProblem = find( kProblem );
		for iProblem = 1:numel( kProblem )
			fprintf( '\t%s\t%s\t%s\n', sessions{kProblem(iProblem),2:3}, errMsg{kProblem(iProblem)} )
		end
		fprintf( '\n' )
	end

	return
	
%% average figure

	n = nnz( Nbridge >= 0 );
	topoOpts = AMPSCZ_EEG_topoOptions( AMPSCZ_EEG_GYRcmap( 256 ) );
	
	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.9, 0.9-0.18 ] );
	topoplot( Ebridge/n, chanlocs, topoOpts{:}, 'maplimits', [ 0, 1 ] );
	set( hAx, 'CLim', [ 0, 1 ], 'XLim', [ -0.55, 0.55 ], 'YLim', [ -0.45, 0.55 ] )
	xlabel( 'Average Bridged Channels', 'Visible', 'on', 'FontSize', 14 )
	title( sprintf( 'n = %d', n ), 'FontSize', 14 )
	colorbar
	figPos = get( hFig, 'Position' );
	img = getfield( getframe( hFig ), 'cdata' );
	if size( img, 1 ) ~= figPos(4)
		img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
	end
	% imwrite( img, 'C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PredictGRAN\processed\GRANavg\eeg\ses-00000000\Figures\GRANavg_00000000_QCbridge.png', 'png' )
	
%% summary distributions

	Nmax = max( Nbridge, [], 1, 'omitnan' );
	x = 0:Nmax;
	N = histcounts( categorical( Nbridge(~isnan(Nbridge)) ), categorical( x ) );
	
	clf
	subplot( 2, 1, 1 )
%		histogram( categorical( Nbridge(~isnan(Nbridge)) ), categorical( x ) )
		bar( x, N, 1, 'FaceColor', [ 0, 0.625, 1 ] )
%		xlim( [ -0.5, Nmax+0.5 + 1 ] )
		xlim( [ -0.5, 63+0.5 ] )
		xlabel( '# bridged channels' )
		ylabel( '# sessions' )
		title( sprintf( '%d sesssions total', sum( N ) ) )
	subplot( 2, 1, 2 )
		h = cdfplot( Nbridge(~isnan(Nbridge)) );
		set( h, 'Color', [ 0, 0.625, 1 ], 'LineWidth', 1.5 )
		axis( [ 0, 63, 0, 1 ] )
% 		axis( [ -0.5, 63+0.5, 0, 1 ] )
	figure( gcf )
	
end