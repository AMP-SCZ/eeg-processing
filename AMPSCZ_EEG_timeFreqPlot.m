function hAx = AMPSCZ_EEG_timeFreqPlot( tImg, fImg, imgTF, topoData, chanlocs, tWave, yWave,...
                                        sessionLabel, columnLabel, chanLabel, topoLabel, waveLabel, hFig )
% Plotting function for AMP SCZ ASSR EEG data
%
% usage:
% >> hAx = AMPSCZ_EEG_timeFreqPlot( tImg, fImg, imgTF, topoData, chanlocs, tWave, yWave,...
%                                   sessionLabel, columnLabel, chanLabel, topoLabel, waveLabel, hFig );
% 
% inputs:
%
% tImg         = time vector, row (ms)
% fImg         = frequency vector, column (Hz)
% imgTF        = frequency x time x #images array
% topoData     = #channels x #images matrix
% chanlocs     = 1 x #channels EEGLAB structure
% tWave        = #samples x 1 vector (ms)
% yWave        = #samples x #waveforms matrix
% sessionLabel = extra label for centermost column
% columnLabel  = cell array of char w/ #images elements, e.g. { 'POW', 'EPM', 'ITC' }
% chanLabel    = y-axis label for time-frequency row
% topoLoab     = label for topoplot row
% waveLabel    = YTickLabel for waveform axis
% [hFig]       = optional figure handle to create plots in.  default is to create a new figure
%
% output:
% [hAx]        = optional 1 x #images*2+1 vector of axis handles

	narginchk( 12, 13 )
	cmap = jet( 256 );

	if exist( 'hFig', 'var' ) == 1 && ~isempty( hFig )
		clf( hFig )
% 		set( hFig, 'Position', [ 300 75 1400 900 ] )
	else
		hFig = figure( 'Position', [ 300 75 1400 900 ] );
	end
	set( hFig, 'Colormap', cmap )

	nImg = size( imgTF, 3 );
	if size( topoData, 2 ) ~= nImg
		error( 'time-frequency topo size mismatch' )
	elseif numel( columnLabel ) ~= nImg
		error( 'label size mismatch' )
	end
	
	topoOpts = AMPSCZ_EEG_topoOptions( cmap );
% 	topoOpts{ find( strcmp( topoOpts(1:2:end), 'electrodes' ) ) * 2 } = 'ptslabels';

	nAx = nImg*2 + 1;
	hAx = gobjects( 1, nAx );
	for iImg = 1:nImg
		% time-frequency images
		hAx(iImg) = subplot( 3, nImg, iImg );
		imagesc( hAx(iImg), tImg, fImg, imgTF(:,:,iImg) )
% 		if all( imgTF(:,:,iImg) >= 0, 'all' )
% 			set( hAx(iImg), 'CLim', [ 0, max( imgTF(:,:,iImg), [], 'all' ) ] )
% 		end
		if iImg == ceil( nImg / 2 )
			title( hAx(iImg), sprintf( '%s\n%s', sessionLabel, columnLabel{iImg} ) )
		else
			title( hAx(iImg), columnLabel{iImg} )
		end
		if iImg == 1
			ylabel( hAx(iImg), sprintf( '%s\n(Hz)', chanLabel ) )
		else
			ylabel( hAx(iImg), '(Hz)' )
		end
		xlabel( hAx(iImg), '(ms)' )
		% topo plots
		iAx = nImg + iImg;
		hAx(iAx) = subplot( 3, nImg, iAx );
		topoplot( topoData(:,iImg), chanlocs, topoOpts{:} );
		set( hAx(iAx), 'CLim', [ 0, max( topoData(:,iImg), [], 1 ) ] )
	end
	set( hAx(1:nImg), 'YDir', 'normal', 'GridAlpha', 0.5, 'GridColor', 'w', 'GridLineStyle', '--', 'XGrid', 'on', 'YGrid', 'on' )
	set( hAx(nImg+1:nImg*2), 'XLim', [ -1, 1 ]*0.5, 'YLim', [ -0.4, 0.45 ] )	% x limits 0.5 if no labels, 0.55 with?
	ylabel( hAx(nImg+1), topoLabel, 'Visible', 'on' )
	for iAx = 1:nImg*2
		colorbar( hAx(iAx) )
	end

	% waveform plot
	nWave = size( yWave, 2 );
	iAx = nAx;
	hAx(iAx) = subplot( 3, nImg, nImg*2+1:nImg*3 );
	hLine = plot( hAx(iAx), tWave, yWave / ( max( abs( yWave ), [], 'all' ) * 2 ) + (1:nWave) );
% 	hLine = plot( hAx(iAx), tWave, yWave );
% 	set( hAx(iAx), 'XLim', [ -100, 1000 ] )
	set( hAx(iAx), 'YLim', [ 0.5, nWave+0.5] + [ -1, 1 ]*nWave*0.05, 'YTick', 1:nWave, 'YTickLabel', waveLabel, 'YDir', 'reverse' )
	set( hAx(iAx), 'YGrid', 'on', 'XGrid', 'on' )
	if nWave == 3
		set( hLine(1), 'Color', [ 1, 0   , 0 ] )
		set( hLine(2), 'Color', [ 0, 0.75, 0 ] )
		set( hLine(3), 'Color', [ 0, 0   , 1 ] )
	end
	xlabel( hAx(iAx), '(ms)' )
% 	legend( waveLabel, 'Location', 'NorthEastOutside' )

	fontSize = 12;
	for iAx = 1:nAx
		set( get( hAx(iAx), 'Title'  ), 'FontSize', fontSize )
		set( get( hAx(iAx), 'XLabel' ), 'FontSize', fontSize )
		set( get( hAx(iAx), 'YLabel' ), 'FontSize', fontSize )
	end
			
	figure( hFig )
	
end
				