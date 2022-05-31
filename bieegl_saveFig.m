function bieegl_saveFig( hFig, pngFile, dpi, fResize, resizeMethod )
% Save figure at same pixel dimensions as Matlab figure position
%
% bieegl_saveFig( hFig, pngFile, [dpi=100], [fResize=1], [resizeMethod='bicubic'] )
%
% note: resizeMethod only comes into play if fResize ~= 1.

	narginchk( 2, 5 )
	
	if ~ischar( pngFile )
		error( 'non-char pngFile input' )
	elseif numel( pngFile ) < 5 || ~strcmpi( pngFile(end-3:end), '.png' )
		error( 'only .png extension is currently supported' )
	end

	if exist( 'dpi', 'var' ) ~= 1 || isempty( dpi )
		dpi = 100;
	end
	if exist( 'fResize', 'var' ) ~= 1 || isempty( fResize )
		fResize = 1;
	end
	if exist( 'resizeMethod', 'var' ) ~= 1 || isempty( resizeMethod )
		resizeMethod = 'bicubic';		% nearest, bilinear, bicubic
	end

	figPos = get( hFig, 'Position' );
	if fResize == 1
		set( hFig, 'PaperUnits', 'inches', 'PaperPosition', [ 0, 0, figPos(3:4)/dpi ] )
		print( hFig, pngFile, '-dpng', [ '-r', int2str( dpi ) ] )
	else
		set( hFig, 'PaperUnits', 'inches', 'PaperPosition', [ 0, 0, figPos(3:4)/dpi*fResize ] )
		img = print( hFig, '-RGBImage', [ '-r', int2str( dpi ) ] );
		img = imresize( img, 1/fResize, resizeMethod );
		imwrite( img, pngFile,  'png' )
	end
	fprintf( 'wrote %s\n', pngFile )
	
	return
	
% 	img1 = print( hFig, '-RGBImage', [ '-r', int2str( dpi ) ] );
% 	img2 = getframe( hFig );
% 	img2 = img2.cdata;
% 	% all of these sizes match
% 	disp( figPos(3:4) )
% 	disp( size( img1 ) )
% 	disp( size( img2 ) )
% 	% img1 & img2 are identical on NoMachine, but not on ErisTwo
% 	all( img1 == img2, 'all' )
	
	% i was getting crazy pixel splatter on some topo plots via ErisTwo bsub...
	% getframe is the problem
% 	saveas(  hFig, 'bridgeFig-saveas.png',   'png' )								% ends up 525x375, no splatter
% 	print(   hFig, 'bridgeFig-print.png',  '-dpng', [ '-r', int2str( dpi ) ] )		%         350x250, no splatter     
% 	imwrite( img1, 'bridgeFig-imwrite.png',  'png' )								%         350x250, no splatter
% 	imwrite( img2, 'bridgeFig-getframe.png', 'png' )								%         350x250,    splatter
	
end
