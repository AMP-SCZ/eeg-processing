function [ nFound, nExpected, nName ] = AMPSCZ_EEG_eventGraph( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

% separate out redundant code in AMPSCZ_EEG_eegMerge.m, AMPSCZ_EEG_checkRuns.m, AMPSCZ_EEG_eventGraph.m

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
	nSensor = 0;
	for iHdr = 1:nHdr
		eeg = pop_loadbv( vhdr(iHdr).folder, vhdr(iHdr).name );
		for iCode = 1:size( codeTotals, 1 )
			codeTotals{iCode,3} = codeTotals{iCode,3} + nnz( strcmp( { eeg.event.type }, sprintf( 'S%3d', codeTotals{iCode,2} ) ) );
		end
		if strcmp( vhdr(iHdr).name(31:36), 'VODMMN' )
			vis       = double( sort( eeg.data(64,:), 2, 'ascend' ) );		% eeg is single
			visLo     = vis( round( 0.7 * eeg.pnts ) );		% 70% cdf
			visHi     = vis( round( 0.8 * eeg.pnts ) );		% 80% cdf
			if visHi - visLo > 200000*0.0488		% 0.0488 in conversion to muV.  same for all sites?
				nEnd      = 10;
				nGap      = 40;
				vis(:)    = ( eeg.data(64,:) > ( ( visLo + visHi ) / 2 ) ) * 2 - 1;		% -1 or 1
				visOn     = filter( [ ones(1,nEnd), zeros(1,nGap), -ones(1,nEnd) ], 1, vis ) == 2*nEnd;
				visOn(:)  = [ false, visOn(2:eeg.pnts) & ~visOn(1:eeg.pnts-1) ];
				visOn     = find( visOn ) - nEnd;
				nSensor(:)  = nSensor + numel( visOn );
			end
		end
	end
	nVisStim = sum( [ codeTotals{3:5,4} ] );
	
% 	[ nSensor, nVisStim ]

	pe = [ codeTotals{:,3}, nSensor ] ./ [ codeTotals{:,4}, nVisStim ] * 100;
	
	if nargout ~= 0
		% note: these aren't in same order as figure.  targets & novels flipped
		nFound    = [ codeTotals{:,3}, nSensor  ];
		nExpected = [ codeTotals{:,4}, nVisStim ];
		nName     = [ codeTotals(:,1); { 'sensor' } ]';
	end

% 	clf
	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
	hAx  =  axes( 'Units', 'normalized', 'Position', [ 0.2, 0.225, 0.575, 0.7 ] );

	hBar = bar( [ 1 4 10 15 ], pe([ 1 3 7 11 ]), 1/3 );		% standard (blue)
	hold on
	hBar = [
		hBar
		bar( [ 2 5 11 ], pe([ 2 5  9 ]), 1/3 )				% deviant/novel (red)
		bar( [   6 12 ], pe([   4  8 ]), 1/6 )				% target (orange)
		bar( [  17 18 ], pe([  12 13 ]), 1   )				% rest (purple)
		bar( [   7 13 ], pe([   6 10 ]), 1/6 )				% response (green)
		bar( [      8 ], pe(      14  ), 1   )				% photosensor (cyan)
	];
	set( hBar(1), 'FaceColor', [ 0   , 0.75, 1 ] )
	set( hBar(2), 'FaceColor', [ 1   , 0.625, 0 ] )
	set( hBar(3), 'FaceColor', [ 1   , 0   , 0 ] )
	set( hBar(4), 'FaceColor', [ 0   , 0   , 0 ] + 0.75 )
	set( hBar(5), 'FaceColor', [ 0   , 0.75, 0 ] )
	set( hBar(6), 'FaceColor', [ 0.75, 0   , 1 ] )
	hold off
	IAll = [ 1:2, 3 5 4 6 14, 7 9 8 10, 11, 12:13 ];
	kPerfect = pe(IAll) == 100;
	if any( kPerfect )
		xAll = [ 1:2, 4:8, 10:13, 15, 17:18 ];
		line( xAll(kPerfect), repmat( 105, 1, nnz(kPerfect) ), 'LineStyle', 'none', 'Color', 'k', 'Marker', 'p' )
	end
	text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.05, 0.95, 0 ], 'FontWeight', 'bold',...
		'String', sprintf( '\\color[rgb]{%g,%g,%g}Std\n\\color[rgb]{%g,%g,%g}Dev/Nov\n\\color[rgb]{%g,%g,%g}Trg\n\\color[rgb]{%g,%g,%g}Resp\n\\color[rgb]{%g,%g,%g}Sens',...
		get( hBar(1), 'FaceColor' ), get( hBar(2), 'FaceColor' ), get( hBar(3), 'FaceColor' ), get( hBar(5), 'FaceColor' ), get( hBar(6), 'FaceColor' ) ) );
	set( hAx, 'XTick', [ 1.5, 6, 11.5, 15, 17.5 ], 'XTickLabel', { 'MMN', 'VOD', 'AOD', 'ASSR', 'Rest' },...
		'XLim', [ 0.5, 18.5 ] + [ -1, 1 ]*1, 'YGrid', 'on', 'XTickLabelRotation', 45, 'FontSize', 12 )
% 	set( hAx, 'YLim', [ 0, ceil(max(pe)/10)*10+10 ] )
	set( hAx, 'YLim', [ max(floor(min(pe)/10)*10-10,0), ceil(max(pe)/10)*10+10 ] )
	ylabel( 'Events (%)', 'FontSize', 14, 'FontWeight', 'normal' )
% 	title( sprintf( '%s\n%s', subjectID, sessionDate ) )
% 	legend( hBar([1:3,5:6]), { 'Std', 'Dev/Nov', 'Trg', 'Resp', 'Sensor' }, 'Location', 'NorthEastOutside' )
	
	return
	
	%% generate these on full set
	
	clear

	sessions  = AMPSCZ_EEG_findProcSessions;
	[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( [] );

			% @ DPACC
% 			sessions = {    'PronetMA', 'MA00007', '20211124' }; VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 3 VODMMN & 2 AOD only
% 			sessions = {    'PronetMT', 'MT00099', '20220202' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNC', 'NC00052', '20220304' }; VODMMNruns = [1:2,5:7]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNC', 'NC00068', '20220304' }; VODMMNruns = [1,3:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNN', 'NN00054', '20220216' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetPI', 'PI00034', '20220121' }; VODMMNruns = [1:6]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetYA', 'YA00087', '20220208' }; VODMMNruns = [2:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientBM', 'BM00066', '20220209' }; VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientGW', 'GW00005', '20220126' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientME', 'ME00099', '20220217' }; VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetOR', 'OR00003', '20211110' }; VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetOR', 'OR00019', '20211217' }; VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [0];
% 			sessions = {    'PronetPA', 'PA00000', '20211014' }; VODMMNruns = [1:4]; AODruns = [1:5]; ASSRruns = []; RestEOruns = [0]; RestECruns = [0];
% 			sessions = { 'PrescientLS', 'LS00002', '20211207' }; VODMMNruns = [1:4]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientLS', 'LS00018', '20220120' }; VODMMNruns = [1:7]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetYA', 'YA00059', '20220120' }; VODMMNruns = []; AODruns = [2:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];

	nSession  = size( sessions, 1 );
	AMPSCZdir = AMPSCZ_EEG_paths;
	kFinished = false( nSession, 1 );
	errMsg    =  cell( nSession, 1 );
	for iSession = 1:nSession

		pngDir = fullfile( AMPSCZdir, sessions{iSession,1}(1:end-2), 'PHOENIX', 'PROTECTED', sessions{iSession,1},...
	                        'processed', sessions{iSession,2}, 'eeg', [ 'ses-', sessions{iSession,3} ], 'Figures' );
		if ~isfolder( pngDir )
			warning( '%s does not exist', pngDir )
			continue
		end
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCcounts.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2
			fprintf( '%s exists\n', pngName )
			kFinished(iSession) = true;
			continue
		end
		close all

		% note: sessions w/ unexpected task sequence won't get created here!
		%       you'll need to manually supply session indices
		%       create lookup table here?
		try
			AMPSCZ_EEG_eventGraph( sessions{iSession,2}, sessions{iSession,3}, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			continue
		end

		% scale if getframe pixels don't match Matlab's figure size
		hFig = gcf;
		figPos = get( hFig, 'Position' );
		img = getfield( getframe( hFig ), 'cdata' );
		if size( img, 1 ) ~= figPos(4)
			img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
		end

		% save
		imwrite( img, pngFile, 'png' )
		fprintf( 'wrote %s\n', pngFile )

		kFinished(iSession) = true;

	end
	fprintf( 'done\n' )
	
	if ~all( kFinished )
		tmp = [ sessions(~kFinished,2:3), errMsg(~kFinished) ]';
		fprintf( '%s\t%s\t%s\n', tmp{:} )
	end
	
	
	%%
	subjectID   = 'YA00059';
	sessionDate = '20220120';
	siteId      = subjectID(1:2);
	siteInfo    = AMPSCZ_EEG_siteInfo;
	iSite       = ismember( siteInfo(:,1), siteId );
	AMPSCZdir   = AMPSCZ_EEG_paths;
	networkName = siteInfo{iSite,2};
	bidsDir     = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ],...
	                        'processed', subjectID, 'eeg', [ 'ses-', sessionDate ], 'BIDS' );
	dir( fullfile( bidsDir, '*.vhdr' ) )
	%%
	VODMMNruns = [];
	AODruns    = [2:5];
	ASSRruns   = [];
	RestEOruns = [];
	RestECruns = [];
	[ nFound, nExpected, nName ] = AMPSCZ_EEG_eventGraph( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
	disp( [ nName(:), num2cell( [ nExpected(:), nFound(:) ] ) ] )
	
end