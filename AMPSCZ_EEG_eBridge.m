	%% https://psychophysiology.cpmc.columbia.edu/software/eBridge/Index.html

	clear
	sessions  = AMPSCZ_EEG_findProcSessions;
	nSession  = size( sessions, 1 );
	AMPSCZdir = AMPSCZ_EEG_paths;

	VODMMNruns = 0;
	AODruns    = 0;
	ASSRruns   = 0;
	RestEOruns = 0;
	RestECruns = 1;

	currentDir = cd;
	eBridgeDir = 'C:\Users\donqu\Downloads\eBridge';

	Nbridge = nan( nSession, 2 );
	for iSession = 1:nSession

		pngDir = fullfile( AMPSCZdir, sessions{iSession,1}(1:end-2), 'PHOENIX', 'PROTECTED', sessions{iSession,1},...
	                        'processed', sessions{iSession,2}, 'eeg', [ 'ses-', sessions{iSession,3} ], 'Figures' );
		if ~isfolder( pngDir )
			warning( '%s does not exist', pngDir )
			continue
		end
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCbridge.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2
			fprintf( '%s exists\n', pngName )
			continue
		end
		close all

		try
			eeg = AMPSCZ_EEG_eegMerge( sessions{iSession,2}, sessions{iSession,3}, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, 50 ], [ -1, 2 ] );
		catch ME
			warning( ME.message )
			continue
		end
	
		pause( 1 )		% doesn't pause nearly as long as advertised?
		close all

		cd( eBridgeDir )
		[ EB, ED ] = eBridge( eeg );
		cd( currentDir )

		Nbridge(iSession,:) = [ size( EB.Bridged.Pairs, 2 ), EB.Bridged.Count ];
% 		continue
		
		if EB.Bridged.Count == 0
			nPair = 0;
			xPair = [];
			yPair = [];
		else
			nPair = size( EB.Bridged.Pairs, 2 );
			[ ~, I ] = ismember( EB.Bridged.Pairs(1,:), EB.Bridged.Labels );
			yPair = EB.Bridged.Indices( I );
			[ ~, I ] = ismember( EB.Bridged.Pairs(2,:), EB.Bridged.Labels );
			xPair = EB.Bridged.Indices( I );
		end
		img = median( 1./ED, 3 );

		% scale if getframe pixels don't match Matlab's figure size
		hFig   = figure( 'Colormap', flip( pink( 256 ), 1 ), 'Position',[ 600 150 900 800 ] );		% flip(gray)?, 1-hot?
		
		imagesc( img, [ 0, max( img, [], 'all' ) ] )
		set( gca, 'YDir', 'normal', 'DataAspectRatio', [ 1 1 1 ] )
		set( gca, 'XTick', 1:eeg.nbchan, 'YTick', 1:eeg.nbchan, 'XTickLabel', '', 'YTickLabel', '', 'XGrid', 'on', 'YGrid', 'on' )
		set( gca, 'XTickLabel', { eeg.chanlocs.labels }, 'YTickLabel', { eeg.chanlocs.labels }, 'XTickLabelRotation', 90 )

		line( xPair, yPair, 'LineStyle', 'none', 'Marker', 'o', 'Color', [ 1, 0.25, 0 ], 'MarkerSize', 12 )
		xlabel( 'channel' )
		ylabel( 'channel' )
		title( sprintf( '%s\n%s\ndetected bridges: %d pairs, %d channels', sessions{iSession,2}, sessions{iSession,3}, nPair, EB.Bridged.Count ) )
		colorbar

		figPos = get( hFig, 'Position' );
		img = getfield( getframe( hFig ), 'cdata' );
		if size( img, 1 ) ~= figPos(4)
			img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
		end
		
		% save
		imwrite( img, pngFile, 'png' )
		fprintf( 'wrote %s\n', pngFile )

	end
	fprintf( 'done\n' )


	return
	
%% summary distributions

	i = 2;		% column: 1 = #brige pairs, 2 = #channels
	varName = { 'pairs', 'channels' };
	
	Nmax = max( Nbridge, [], 1, 'omitnan' );
	x = 0:Nmax(i);
	N = histcounts( categorical( Nbridge(~isnan(Nbridge(:,i)),i) ), categorical( x ) )
	
	clf
	subplot( 2, 1, 1 )
%		histogram( categorical( Nbridge(~isnan(Nbridge(:,i)),i) ), categorical( x ) )
		bar( x, N, 1, 'FaceColor', [ 0, 0.625, 1 ] )
%		xlim( [ -0.5, Nmax(i)+0.5 + 1 ] )
		xlim( [ -0.5, 63+0.5 ] )
		xlabel( [ '# bridged ', varName{i} ] )
		ylabel( '# sessions' )
		title( sprintf( '%d sesssions total', sum( N ) ) )
	subplot( 2, 1, 2 )
		h = cdfplot( Nbridge(~isnan(Nbridge(:,i)),i) );
		set( h, 'Color', [ 0, 0.625, 1 ], 'LineWidth', 1.5 )
		axis( [ 0, 63, 0, 1 ] )
% 		axis( [ -0.5, 63+0.5, 0, 1 ] )
	figure( gcf )
	




