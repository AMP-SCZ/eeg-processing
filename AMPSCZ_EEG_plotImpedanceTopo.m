function AMPSCZ_EEG_plotImpedanceTopo( hAx, Zname, Zdata, chanlocs, zRange, zThresh, zLimit )

	narginchk( 5, 7 )

	% locsFile = 'AMPSCZ_EEG_actiCHamp65ref_noseX.ced';
	% chanlocs = readlocs( locsFile, 'importmode', 'native', 'filetype', 'chanedit' );		% [ 63 EEG, 'VIS', FCz ref ]

	[ nImp, nRec, nSubj ] = size( Zdata );
	if nSubj == 1
		iRec  = find( ~all( isnan( Zdata ), 1 ), 1, 'last' );		% first or last?
% 		NSubj = 1;
	elseif nRec == 1
		iRec  = 1;
		NSubj = max( sum( ~isnan( Zdata ), 3 ) );
		Zdata = median( Zdata, 3, 'omitnan' );
	else
% 		error( 'multiple impedance recordings not supported w/ multiple subjects' )
		iRec  = 1;
		Zdata = max( Zdata, [], 2, 'omitnan' );
		NSubj = max( sum( ~isnan( Zdata ), 3 ) );
		Zdata = median( Zdata, 3, 'omitnan' );
	end
	[ kZ, ILocs ] = ismember( Zname, { chanlocs.labels } );
	if ~all( isnan( Zdata(kZ,iRec) ) )

		if exist( 'zThresh', 'var' ) ~= 1 || isempty( zThresh )
			zThresh = 25;
		end
		if exist( 'zLimit', 'var' ) ~= 1 || isempty( zLimit )
			zLimit = zThresh * 2;
		end

		[ cmap, badChanColor ] = AMPSCZ_EEG_GYRcmap( 256 );

		topoOpts = AMPSCZ_EEG_topoOptions( cmap, [ 0, zLimit ] );

		axes( hAx )
		topoplot( min( Zdata(kZ,iRec), zLimit*2 ), chanlocs(ILocs(kZ)), topoOpts{:} );		% Infs don't get interpolated

		[ topoX, topoY ] = bieegl_topoCoords( chanlocs(ILocs(kZ)) );
		kThresh    = Zdata(kZ,iRec) > zThresh;
		line( topoY(kThresh), topoX(kThresh), repmat( 10.5, 1, nnz(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )

		colorbar%( 'southoutside' );

	end

	if nSubj == 1
		if nRec == 1
			zStr = sprintf( '%d Recording\n' , nRec );
		else
			zStr = sprintf( 'Recording %d / %d\n', iRec, nRec );
		end
	else
		zStr = sprintf( 'Median %d Subjects\n', NSubj );
	end
	% use kZ or all impedance channels? i.e. include "Gnd"?
	zStr = sprintf( [ '%s',...
					'Min. = %g'           , repmat( ', %g'   , 1, nRec-1 ), '\n',...
					'Max. = %g'           , repmat( ', %g'   , 1, nRec-1 ), '\n',...
					'Med. = %0.1f'        , repmat( ', %0.1f', 1, nRec-1 ), '\n',...
					'# > %g k\\Omega = %d', repmat( ', %d'   , 1, nRec-1 ), ' / %d' ],...
		zStr, min(Zdata,[],1), max(Zdata,[],1), median(Zdata,1), zThresh, sum(Zdata>zThresh,1), nImp );
	
	if ~isempty( zRange )
		goodColor = '\color[rgb]{0,0.75,0}';
%		okColor   = '\color[rgb]{0.75,0.75,0}';
		badColor  = '\color{red}';
		zStr = sprintf( '%s\nRange:\n', zStr );
		for i = 1:size( zRange, 1 )
			if all( zRange(i,:) == [ 25, 75 ] )
				zStr = [ zStr, goodColor ];
			else
				zStr = [ zStr, badColor ];
			end
			zStr = [ zStr, sprintf( '%g, %g\n', zRange(i,:) ) ];
		end
	end

	text( hAx, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.35, 0.95, 0 ],...
		'FontSize', 12, 'String', zStr )

	fontSize   = 14;
	fontWeight = 'normal';
% 	title(  hAx, sprintf( '%s\n\\fontsize{12}%s', subjId, sessDate ), 'Visible', 'on' )
	xlabel( hAx, 'Impedance (k\Omega)', 'Visible', 'on', 'FontSize', fontSize, 'FontWeight', fontWeight )
	set( hAx, 'CLim', [ 0, zLimit ] )
% 	set( hAx, 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] )

	return


end