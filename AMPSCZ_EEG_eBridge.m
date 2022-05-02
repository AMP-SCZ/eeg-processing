function [ EB, ED, chanlocs ] = AMPSCZ_EEG_eBridge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
% https://psychophysiology.cpmc.columbia.edu/software/eBridge/Index.html
% https://psychophysiology.cpmc.columbia.edu/software/eBridge/eBridge.m

	narginchk( 2, 7 )
	
	if exist( 'VODMMNruns', 'var' ) ~= 1
		VODMMNruns = 0;
	end
	if exist( 'AODruns', 'var' ) ~= 1
		AODruns = 0;
	end
	if exist( 'ASSRruns', 'var' ) ~= 1
		ASSRruns = 0;
	end
	if exist( 'RestEOruns', 'var' ) ~= 1
		RestEOruns = 0;
	end
	if exist( 'RestECruns', 'var' ) ~= 1
		RestECruns = 1;
	end

% 	currentDir = cd;
	eBridgeDir = 'C:\Users\donqu\Downloads\eBridge';
	if isempty( which( 'eBridge.m' ) )
		addpath( eBridgeDir, '-begin' )
	end
	locsFile   = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.elc' );

	eeg = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, 50 ], [ -1, 2 ] );

% 	cd( eBridgeDir )
	[ EB, ED ] = eBridge( eeg );
% 	cd( currentDir )

	% 2D channel x channel image matrix, triangular
	img  = sum( ED * EB.Info.EDscale < EB.Info.EDcutoff, 3 );
	% topography vector
	img = sum( img + img', 2 );
	% clip @ bridging threshold?
	cMax = EB.Info.BCT * EB.Info.NumEpochs;
	img = min( img, cMax );

	eeg = pop_chanedit( eeg, 'lookup', locsFile );		% do this on EEG, not chanlocs or topos won't have right orientation

	topoOpts = AMPSCZ_EEG_topoOptions( AMPSCZ_EEG_GYRcmap( 256 ) );
	
	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.9, 0.9-0.18 ] );
	topoplot( img, eeg.chanlocs, topoOpts{:}, 'maplimits', [ 0, cMax ] );
	set( hAx, 'CLim', [ 0, cMax ], 'XLim', [ -0.55, 0.55 ], 'YLim', [ -0.45, 0.55 ] )
	xlabel( sprintf( '%d Bridged Channels', EB.Bridged.Count ), 'Visible', 'on', 'FontSize', 14 )
	title( sprintf( '%s - %s', subjectID, sessionDate ), 'FontSize', 14 )
% 	colorbar

	chanlocs = eeg.chanlocs;

	return

	%% run loop over all sessions
	
	clear
	
	sessions  = AMPSCZ_EEG_findProcSessions;
	
		% restrict to single site
		sessions( ~strcmp( sessions(:,1), 'PrescientME' ), : ) = [];
	
	nSession  = size( sessions, 1 );
	AMPSCZdir = AMPSCZ_EEG_paths;

	Nbridge =   nan( nSession, 1 );
	Ebridge = zeros(       63, 1);
	errMsg  =  cell( nSession, 1 );
	hWait   = waitbar( 0, '' );
	for iSession = 1:nSession

		waitbar( (iSession-1)/nSession, hWait, sessions{iSession,2} )
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
			Nbridge(iSession) = -1;
% 			continue
		end
		close all

		try
			[ EB, ~, chanlocs ] = AMPSCZ_EEG_eBridge( sessions{iSession,2}, sessions{iSession,3} );
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			continue
		end
	
		pause( 1 )		% doesn't pause nearly as long as advertised?
		close all

		Nbridge(iSession) = EB.Bridged.Count;
		Ebridge(EB.Bridged.Indices) = Ebridge(EB.Bridged.Indices) + 1;
		continue

		% scale if getframe pixels don't match Matlab's figure size
		hFig   = gcf;
		figPos = get( hFig, 'Position' );
		img = getfield( getframe( hFig ), 'cdata' );
		if size( img, 1 ) ~= figPos(4)
			img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
		end
		
		% save
		imwrite( img, pngFile, 'png' )
		fprintf( 'wrote %s\n', pngFile )

		waitbar( iSession/nSession, hWait )
	end
	close( hWait )
	fprintf( 'done\n' )

	kCrash = isnan( Nbridge );
	if any( kCrash )
		tmp = [ sessions(kCrash,2:3), errMsg(kCrash) ]';
		fprintf( '%s\t%s\t%s\n', tmp{:} )
		% NC00002	20220408	NC00002 20220408: requested run(s) don't exist
		% NC00002	20220422	NC00002 20220422: requested run(s) don't exist
		% SF11111	20220201	SF11111 20220201: requested run(s) don't exist
		% SF11111	20220308	SF11111 20220308: requested run(s) don't exist
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

