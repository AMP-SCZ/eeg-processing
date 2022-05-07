function AMPSCZ_EEG_makeMovie( subjId, sessId, taskNames, filterStr )
% Make MP4 movies from pre-processed ERP mat files
%
% Usage:
% >> AMPSCZ_EEG_makeMovie( subjId, sessId, [taskNames], [filterStr] )
%
% Inputs:
% subjId = 7-character AMPSCZ subject identifier.  2-char site code + 5-digit number
% sessId = 8-character date string in YYYYMMDD format
% taskNames = optional cell array to run subset of tasks
%             default = { 'AOD', 'VOD', 'MMN' }
% filterStr = optional char-class input to specify filter settings in mat file name
%             default = '[0.1,Inf]'
%
% e.g.
% >> AMPSCZ_EEG_makeMovie( 'SF12345', '20220101' )
%
% Written by: Spero Nicholas, NCIRE

	narginchk( 2, 4 )
	
	if exist( 'taskNames', 'var' ) ~= 1 || isempty( taskNames )
		taskNames = { 'AOD', 'VOD', 'MMN' };
	end
	if exist( 'filterStr', 'var' ) ~= 1 || isempty( filterStr )
		filterStr = '[0.1,Inf]';
% 		filterStr = '[0.3,Inf]';
	end

	siteInfo = AMPSCZ_EEG_siteInfo;
	networkName = siteInfo{strcmp( siteInfo(:,1), subjId(1:2) ),2};
	
	nameFmt = [ subjId, '_', sessId, '_%s_', filterStr ];
	for iTask = 1:numel( taskNames )
		
% 		[ standardCode, targetCode, novelCode, respCode ] = AMPSCZ_EEG_eventCodes( taskNames{iTask} );
	
		matFile = fullfile( AMPSCZ_EEG_procSessionDir( subjId, sessId, networkName ), 'mat',...
			sprintf( [ nameFmt, '.mat' ], taskNames{iTask} ) );

		load( matFile, 'EEG', 'epochInfo' )

		% time-locked event of each trial
% 		eventType = cellfun( @(u,v)u{[v{:}]==0}, { EEG.epoch.eventtype }, { EEG.epoch.eventlatency }, 'UniformOutput', false );
% 		if numel( eventType ) ~= EEG.trials
% 			error( 'bug' )
% 		end

		switch taskNames{iTask}
			case { 'AOD', 'VOD' }
				timeRange = [ -0.100, 0.800 ];	% (s)
				stimNames = { 'Standard', 'Target', 'Novel' };
				figPos    = [ 750, 450 ];
			case 'MMN'
				timeRange = [ -0.100, 0.500 ];	% (s)
				stimNames = { 'Standard', 'Novel' };
				figPos    = [ 500, 450 ];
		end
		nStim = numel( stimNames );

		% narrower time window
		EEG = pop_select( EEG, 'time', timeRange );
	
		% non-rejected epocsh
		kEpoch = shiftdim( ~isnan( EEG.data(1,1,:) ), 1 );
	
		% concatenate epoch info across runs
		for fn = fieldnames( epochInfo )'
			epochInfo(1).(fn{1}) = [ epochInfo.(fn{1}) ];
		end
		epochInfo = epochInfo(1);
		
		% channels to inclue
		kChan = strcmp( { EEG.chanlocs.type }, 'EEG' );

		if EEG.trials ~= numel( epochInfo.latency )
			error( 'EEG.trials (%d) vs epochInfo (%d) size mismatch', EEG.trials, numel( epochInfo.latency ) )
		end

		%% initialize plot ----------------------------------------------------

% 		topoOpts = { 'style', 'map', 'electrodes', 'pts', 'nosedir', '+X', 'conv', 'on', 'shading', 'interp', 'colormap', jet(256), 'whitebk', 'on' };		% electrodes: 'pts' or 'ptslabels'?
		topoOpts = AMPSCZ_EEG_topoOptions( jet( 256 ) );
		topoOpts{find( strcmp( topoOpts(1:2:end), 'shading' ) ) * 2} = 'interp';

		set( gcf, 'Units', 'pixels', 'Position', [ 100, 100, figPos ] )
		clf
%		set( gcf, 'Color', [ 1, 1, 1 ] )		% topoplot sets figure color, see 'whitebk' option
%		colormap( parula( 256 ) )
%		colormap( jet( 256 ) )
	
		Y = nan( EEG.pnts, sum( kChan ), nStim );
		for iStim = 1:nStim
			% trials to average
			kEvent = epochInfo.(['k',stimNames{iStim}]);
			% correct responses only
			if ismember( taskNames{iTask}, { 'AOD', 'VOD' } )
				kEvent(kEvent) = epochInfo.kCorrect(kEvent);
			end
			% non-rejected epochs
			kEvent(kEvent) = kEpoch(kEvent);
			Y(:,:,iStim) = mean( EEG.data(kChan,:,kEvent), 3, 'includenan' )';
		end
		yRange = max( abs( Y ), [], 'all' ) * 1.1 * [ -1, 1 ];
		
% 		iTime0 = 1;
		iTime0 = find( EEG.times == 0 );
		hAx   = gobjects( 2, nStim );
		hTopo = gobjects( 1, nStim );
		hLine = gobjects( 1, nStim );
		axL   = 0.10;
		axR   = 0.10;
		axT   = 0.2;
		axB   = 0.15;
		axGh  = 0.04;
		axGv  = 0;
		axW   = ( 1 - axL - axR - axGh*(nStim-1) ) / nStim;
		axH   = ( 1 - axT - axB - axGv           ) / 2;

		for iStim = 1:nStim
			hAx(1,iStim) = subplot( 'Position', [ axL+(axW+axGh)*(iStim-1), 1-axT-axH, axW, axH ] );% 2, nStim, iStim );
				hTopo(iStim) = topoplot( Y(iTime0,kChan,iStim), EEG.chanlocs(kChan), topoOpts{:}, 'maplimits', yRange );	% surface class
				if strcmp( taskNames{iTask}, 'MMN' ) && strcmp( stimNames{iStim}, 'Novel' )
					titleStr = 'Deviant';
				else
					titleStr = stimNames{iStim};
				end
				title( titleStr, 'FontSize', 20, 'FontWeight', 'normal' )
			hAx(2,iStim) = subplot( 'Position', [ axL+(axW+axGh)*(iStim-1), axB, axW, axH ] );%2, nStim, nStim + iStim );
				plot( EEG.times, Y(:,:,iStim), 'Color', repmat( 0.5, 1, 3 ) )
				hLine(iStim) = line( EEG.times([iTime0,iTime0]), yRange, 'Color', [ 0, 0.75, 0 ] );
		end
		set( hAx, 'CLim', yRange )
		set( hAx(1,:),'XLim', [ -1, 1 ]*0.5, 'YLim', [ -0.4, 0.45 ] )
		set( hAx(2,:), 'XLim', timeRange * 1e3, 'YLim', yRange, 'Box', 'off', 'Color', 'none', 'XGrid', 'on', 'YGrid', 'on', 'FontSize', 10 )
		switch taskNames{iTask}
			case { 'AOD', 'VOD' }
				set( hAx(2,:), 'XTick', 0:200:timeRange(2)*1e3, 'XMinorTick', 'on', 'XMinorGrid', 'on' )		% [-100,800]
			case 'MMN'
				set( hAx(2,:), 'XTick', timeRange(1)*1e3:100:timeRange(2)*1e3 )		% [-100,500]
		end
		set( hAx(2,:), 'YTick', yTickFcn( yRange(2) ) )
		set( hAx(2,2:nStim), 'YColor', 'none' )
		hYLabel = ylabel( hAx(1,1), sprintf( '%0.0f ms', EEG.times(iTime0) ), 'Visible', 'on', 'FontSize', 20, 'FontWeight', 'normal' );
		ylabel( hAx(2,1), '\muV', 'FontSize', 14 )
		for iStim = 1:nStim
			xlabel( hAx(2,iStim), 'ms', 'FontSize', 14 )
		end
		hColorbar = subplot( 'Position', [ 1-axR*0.7, axB, axR*0.4, axH ] );
		image( hColorbar, (256:-1:1)' )
		set( hColorbar, 'YLim', [ 0.5, 256.5 ], 'XTick', [], 'YTick', [] )
		text( axes( 'Units', 'normalized', 'Position', [ 0, 0, 1, 1 ], 'Visible', 'off' ),...
			'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top',...
			'Position', [ 0.5, 0.98, 0 ], 'String', sprintf( '%s %s %s', subjId, sessId, taskNames{iTask} ),...
			'FontSize', 14 )
% 		figure( gcf )


		%% animate ------------------------------------------------------------

		outputDir = fullfile( AMPSCZ_EEG_procSessionDir( subjId, sessId, networkName ), 'Figures' );

		figure( gcf )
		
		nSkip = round( 0.005 * EEG.srate );

		V = VideoWriter( fullfile( outputDir, sprintf( [ nameFmt, '.mp4' ], taskNames{iTask} ) ), 'MPEG-4' );
		V.Quality   = 80;	% default = 75, [0,100].  call before open?
		V.FrameRate = 20;	% call after open? help say yes, but it throws error
		open( V );
		for iTime = iTime0:nSkip:EEG.pnts
			for iStim = 1:nStim
%				set( hTopo(iStim), 'CData', Y(iTime,kChan,iStim) )
				[ ~, cdata ] = topoplot( Y(iTime,kChan,iStim), EEG.chanlocs(kChan), topoOpts{:}, 'maplimits', yRange, 'noplot', 'on' );
				set( hTopo(iStim), 'CData', cdata )
				set( hLine(iStim), 'XData', EEG.times([iTime,iTime]) )
			end
			set( hYLabel, 'String', sprintf( '%0.0f ms', EEG.times(iTime) ) )
%			drawnow
			fr = getframe( gcf );
			fr.cdata = imresize( fr.cdata, figPos([2,1]) );
			writeVideo( V, fr )
		end
		close( V )
		
		fprintf( 'wrote %s\n', fullfile( V.Path, V.Filename ) )
		
	end
	fprintf( 'done\n' )
	
	return
	
	% this is replicated in AMPSCZ_EEG_ERPplot.m
	function yTick = yTickFcn( yExt )
		% gives denser but ~sensible y axis ticks than Matlab defaults
		power10scale = 10^floor( log10( yExt ) );
		switch floor( yExt / power10scale )
			case 1
				yTickInc = 0.5;
			case {2,3}
				yTickInc = 1;
			case {4,5,6,7}
				yTickInc = 2;
			case {8,9}
				yTickInc = 4;
			otherwise
				error( 'YTick bug' )
		end
		yTickInc(:) = yTickInc * power10scale;
		nYTick = floor( yExt / yTickInc );
		yTick = (-nYTick:1:nYTick) * yTickInc;
	end


end