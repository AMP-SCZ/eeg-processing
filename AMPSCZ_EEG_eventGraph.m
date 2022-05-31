function [ nFound, nExpected, nName ] = AMPSCZ_EEG_eventGraph( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
% [ nFound, nExpected, nName ] = AMPSCZ_EEG_eventGraph( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

	narginchk( 2, 7 )
	
	if exist( 'VODMMNruns', 'var' ) ~= 1
		VODMMNruns = [];
	end
	if exist( 'AODruns', 'var' ) ~= 1
		AODruns = [];
	end
	if exist( 'ASSRruns', 'var' ) ~= 1
		ASSRruns = [];
	end
	if exist( 'RestEOruns', 'var' ) ~= 1
		RestEOruns = [];
	end
	if exist( 'RestECruns', 'var' ) ~= 1
		RestECruns = [];
	end

	sortFlag = false;
	vhdr     = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, sortFlag );
	nHdr     = numel( vhdr );
	
	codeTotals = {
		'MMNstd' ,  16, 0, 578*5		% 2890
		'MMNdev' ,  18, 0,  62*5		%  310
		'VODstd' ,  32, 0, 128*5		%  640
		'VODtrg' ,  64, 0,  16*5		%   80
		'VODnov' , 128, 0,  16*5		%   80
		'VODrsp' ,  17, 0,  16*5		%   80
		'AODstd' ,   1, 0, 160*4		%  640
		'AODtrg' ,   2, 0,  20*4		%   80
		'AODnov' ,   4, 0,  20*4		%   80
		'AODresp',   5, 0,  20*4		%   80
		'ASSR'   ,   8, 0, 200
		'RestEO' ,  20, 0, 180
		'RestEC' ,  24, 0, 180
	};
	% response code totals will be all button codes, not just those in allowable reaction time range
% 	RTrange = AMPSCZ_EEG_RTrange;
	% concatenate into a single eeg structure
% 	nSensor = 0;
	for iHdr = 1:nHdr
		eeg = pop_loadbv( vhdr(iHdr).folder, vhdr(iHdr).name );
		for iCode = 1:size( codeTotals, 1 )
			codeTotals{iCode,3} = codeTotals{iCode,3} + nnz( strcmp( { eeg.event.type }, sprintf( 'S%3d', codeTotals{iCode,2} ) ) );
		end
% 		kVis = strcmp( { eeg.chanlocs.labels }, 'VIS' );
% 		if strcmp( vhdr(iHdr).name(31:36), 'VODMMN' ) && any( kVis )
% 			if nnz( kVis ) ~= 1
% 				error( 'multiple VIS channels' )
% 			end
% 			nSensor(:) = nSensor + numel( AMPSCZ_EEG_photosensorOnset( eeg.data(kVis,:) ) );
% 		end
	end
% 	nVisStim = sum( [ codeTotals{3:5,4} ] );
	
% 	[ nSensor, nVisStim ]

% 	pe = [ codeTotals{:,3}, nSensor ] ./ [ codeTotals{:,4}, nVisStim ] * 100;
	pe = [ codeTotals{:,3} ] ./ [ codeTotals{:,4} ] * 100;
	
	if nargout ~= 0
		% note: these aren't in same order as figure.  targets & novels flipped
% 		nFound    = [ codeTotals{:,3}, nSensor  ];
% 		nExpected = [ codeTotals{:,4}, nVisStim ];
% 		nName     = [ codeTotals(:,1); { 'sensor' } ]';
		nFound    = [ codeTotals{:,3} ];
		nExpected = [ codeTotals{:,4} ];
		nName     = [ codeTotals(:,1) ]';
		return
	end

% 	xLimit = [ 0.5, 18.5 ] + [ -1, 1 ]*1;
	xLimit = [ 0.5, 17.5 ] + [ -1, 1 ]*1;
% 	yLimit = [ 0, ceil(max(pe)/10)*10+10 ];
% 	yLimit = [ max(floor(min(pe)/10)*10-10,0), ceil(max(pe)/10)*10+10 ];
	yLimit = [ max(floor((min(pe)-2)/10)*10,0), ceil((max(pe)+2)/10)*10 ];

	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
	hAx  =  axes( 'Units', 'normalized', 'Position', [ 0.2, 0.225, 0.575, 0.7 ] );

% 	hBar = bar( [ 1 4 10 15 ], pe([ 1 3 7 11 ]), 1/3 );		% standard (blue)
	hBar = bar( [ 1 4  9 14 ], pe([ 1 3 7 11 ]), 1/3 );		% standard (blue)
	hold on
	hBar = [
		hBar
% 		bar( [ 2 5 11 ], pe([ 2 5  9 ]), 1/3 )				% deviant/novel (red)
% 		bar( [   6 12 ], pe([   4  8 ]), 1/6 )				% target (orange)
% 		bar( [  17 18 ], pe([  12 13 ]), 1   )				% rest (purple)
% 		bar( [   7 13 ], pe([   6 10 ]), 1/6 )				% response (green)
% 		bar( [      8 ], pe(      14  ), 1   )				% photosensor (cyan)
		bar( [ 2 5 10 ], pe([ 2 5  9 ]), 1/3 )				% deviant/novel (red)
		bar( [   6 11 ], pe([   4  8 ]), 1/6 )				% target (orange)
		bar( [  16 17 ], pe([  12 13 ]), 1   )				% rest (purple)
		bar( [   7 12 ], pe([   6 10 ]), 1/6 )				% response (green)
	];
	set( hBar(1), 'FaceColor', [ 0   , 0.75, 1 ] )
	set( hBar(2), 'FaceColor', [ 1   , 0.625, 0 ] )
	set( hBar(3), 'FaceColor', [ 1   , 0   , 0 ] )
	set( hBar(4), 'FaceColor', [ 0   , 0   , 0 ] + 0.75 )
	set( hBar(5), 'FaceColor', [ 0   , 0.75, 0 ] )
% 	set( hBar(6), 'FaceColor', [ 0.75, 0   , 1 ] )
	hold off
% 	IAll = [ 1:2, 3 5 4 6 14, 7 9 8 10, 11, 12:13 ];
	IAll = [ 1:2, 3 5 4 6   , 7 9 8 10, 11, 12:13 ];
% 	kPerfect = pe(IAll) == 100;
% 	if any( kPerfect )
% 		xAll = [ 1:2, 4:8, 10:13, 15, 17:18 ];
% 		line( xAll(kPerfect), repmat( 105, 1, nnz(kPerfect) ), 'LineStyle', 'none', 'Color', 'k', 'Marker', 'p' )
% 	end
	kImperfect = pe(IAll) ~= 100;
	if any( kImperfect )
% 		xAll = [ 1:2, 4:8, 10:13, 15, 17:18 ];
		xAll = [ 1:2, 4:7,  9:12, 14, 16:17 ];
% 		line( xAll(kImperfect), repmat( yLimit(2)-1, 1, nnz(kImperfect) ), 'LineStyle', 'none', 'Color', 'k', 'Marker', 'x' )
		line( xAll(kImperfect), pe(IAll(kImperfect))+diff(yLimit)*0.05, 'LineStyle', 'none', 'Color', 'k', 'Marker', 'x' )
	end

% 	text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.05, 0.95, 0 ], 'FontWeight', 'bold',...
% 		'String', sprintf( '\\color[rgb]{%g,%g,%g}Std\n\\color[rgb]{%g,%g,%g}Dev/Nov\n\\color[rgb]{%g,%g,%g}Trg\n\\color[rgb]{%g,%g,%g}Resp\n\\color[rgb]{%g,%g,%g}Sens',...
% 		get( hBar(1), 'FaceColor' ), get( hBar(2), 'FaceColor' ), get( hBar(3), 'FaceColor' ), get( hBar(5), 'FaceColor' ), get( hBar(6), 'FaceColor' ) ) );
	text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.05, 0.95, 0 ], 'FontWeight', 'bold',...
		'String', sprintf( '\\color[rgb]{%g,%g,%g}Std\n\\color[rgb]{%g,%g,%g}Dev/Nov\n\\color[rgb]{%g,%g,%g}Trg\n\\color[rgb]{%g,%g,%g}Resp',...
		get( hBar(1), 'FaceColor' ), get( hBar(2), 'FaceColor' ), get( hBar(3), 'FaceColor' ), get( hBar(5), 'FaceColor' ) ) );
% 	set( hAx, 'XTick', [ 1.5, 6, 11.5, 15, 17.5 ], 'XTickLabel', { 'MMN', 'VOD', 'AOD', 'ASSR', 'Rest' },...
% 		'XLim', xLimit, 'YGrid', 'on', 'XTickLabelRotation', 45, 'FontSize', 12 )
	set( hAx, 'XTick', [ 1.5, 5.5, 10.5, 14, 16.5 ], 'XTickLabel', { 'MMN', 'VOD', 'AOD', 'ASSR', 'Rest' },...
		'XLim', xLimit, 'YGrid', 'on', 'XTickLabelRotation', 45, 'FontSize', 12 )

	set( hAx, 'YLim', yLimit )

	ylabel( 'Events (%)', 'FontSize', 14, 'FontWeight', 'normal' )
% 	title( sprintf( '%s\n%s', subjectID, sessionDate ) )
% 	legend( hBar([1:3,5:6]), { 'Std', 'Dev/Nov', 'Trg', 'Resp', 'Sensor' }, 'Location', 'NorthEastOutside' )
	
	return
	
end