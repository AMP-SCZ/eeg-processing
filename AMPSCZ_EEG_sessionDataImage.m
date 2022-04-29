function img = AMPSCZ_EEG_sessionDataImage( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

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

	eeg = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, Inf ], [ -1, 2 ] );

	% mean reference, nothing fancy, don't want interpolations here
	eeg.data(:) = bsxfun( @minus, eeg.data, mean( eeg.data, 1 ) );
	
	if nargout
		img = eeg.data;
		return
	end

	tSegment = eeg.times( ceil( [ eeg.event( strcmp( { eeg.event.type }, 'boundary' ) ).latency ] ) ) - 0.5/eeg.srate;

	% DPACC images
	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w', 'Colormap', jet( 256 ) );
	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0.15, 0.2, 0.8, 0.75 ] );
	imagesc( eeg.times/60e3, 1:eeg.nbchan, eeg.data, [ -1, 1 ]*75 )
	% continuous segment lines
	if numel( tSegment ) > 1
		line( repmat( tSegment(2:end)/60e3, 2, 1 ), [ 0.5; eeg.nbchan+0.5 ], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1 )
	end
	set( hAx, 'YDir', 'reverse' )
	xlabel( 'Time (min)' )
	ylabel( 'Channel' )
	ylabel( colorbar( 'YTick', -70:10:70 ), '(\muV)' )
	return

	% UCSF images
	figure( 'Position', [ 500, 50, 1200, 900 ], 'Colormap', jet( 256 ) )
	imagesc( eeg.times/60e3, 1:eeg.nbchan, eeg.data, [ -1, 1 ]*75 )
	% continuous segment lines
	if numel( tSegment ) > 1
		line( repmat( tSegment(2:end)/60e3, 2, 1 ), [ 0.5; eeg.nbchan+0.5 ], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 2 )
	end
	set( gca, 'YDir', 'reverse' )
	% channel labels
	set( gca, 'YTick', 1:eeg.nbchan, 'YTickLabel', { eeg.chanlocs.labels } )
	xlabel( 'Time (min)' )
	ylabel( 'Channel' )
	title( sprintf( '%s\n%s', subjectID, sessionDate ) )
	ylabel( colorbar( 'YTick', -70:10:70 ), '(\muV)' )

	return

	%% run loop over all processed sessions and make raw data image pngs if they don't already exist

	clear

	sessions  = AMPSCZ_EEG_findProcSessions;
	[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( [] );

			% manually enter run indices for these sessions (UCSF Box data set)
			% extra runs
% 			sessions = {    'PronetMT', 'MT00099', '20220202' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNC', 'NC00002', '20220408' }; VODMMNruns = []; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];		incomplete [6VODMMN,3AOD], don't bother
% 			sessions = {    'PronetNC', 'NC00052', '20220304' }; VODMMNruns = [1:2,5:7]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNC', 'NC00068', '20220304' }; VODMMNruns = [1,3:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNN', 'NN00054', '20220216' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetPI', 'PI00034', '20220121' }; VODMMNruns = [1:6]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetYA', 'YA00059', '20220120' }; VODMMNruns = []; AODruns = [2:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetYA', 'YA00087', '20220208' }; VODMMNruns = [2:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientBM', 'BM00066', '20220209' }; VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientGW', 'GW00005', '20220126' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientME', 'ME00099', '20220217' }; VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			% missing runs
% 			sessions = {    'PronetGA', 'GA00073', '20220406' }; VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [];		% 1 run of VODMMN & AOD each split over 2 segments, + ASSR & 2 rest runs
% 			sessions = {    'PronetMA', 'MA00007', '20211124' }; VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 3 VODMMN & 2 AOD only
% 			sessions = {    'PronetNC', 'NC00002', '20220408' }; VODMMNruns = [1:6]; AODruns = [1:3]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];			% see above
% 			sessions = {    'PronetNC', 'NC00002', '20220422' }; VODMMNruns = [1:4]; AODruns = [0]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];			% 3 VODMMNN runs, last 1 split over 2 segments.  line noise test
% 			sessions = {    'PronetSF', 'SF11111', '20220201' }; VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 2 VODMMN & 2 AOD only.  noise tests
% 			sessions = {    'PronetSF', 'SF11111', '20220308' }; VODMMNruns = [1:2]; AODruns = [1]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];			% 2 VODMMN & 1 AOD only.  noise tests

			% @ DPACC
% 			sessions = {    'PronetMA', 'MA00007', '20211124' }; VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 3 VODMMN & 2 AOD only
% 			sessions = {    'PronetMT', 'MT00099', '20220202' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNC', 'NC00052', '20220304' }; VODMMNruns = [1:2,5:7]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNC', 'NC00068', '20220304' }; VODMMNruns = [1,3:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetNN', 'NN00054', '20220216' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetOR', 'OR00003', '20211110' }; VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetOR', 'OR00019', '20211217' }; VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [0];
% 			sessions = {    'PronetPA', 'PA00000', '20211014' }; VODMMNruns = [1:4]; AODruns = [1:5]; ASSRruns = []; RestEOruns = [0]; RestECruns = [0];
% 			sessions = {    'PronetPI', 'PI00034', '20220121' }; VODMMNruns = [1:6]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetYA', 'YA00059', '20220120' }; VODMMNruns = []; AODruns = [2:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = {    'PronetYA', 'YA00087', '20220208' }; VODMMNruns = [2:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientBM', 'BM00066', '20220209' }; VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientGW', 'GW00005', '20220126' }; VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientLS', 'LS00002', '20211207' }; VODMMNruns = [1:4]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientLS', 'LS00018', '20220120' }; VODMMNruns = [1:7]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
% 			sessions = { 'PrescientME', 'ME00099', '20220217' }; VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];

	AMPSCZdir = AMPSCZ_EEG_paths;
	nSession  = size( sessions, 1 );
	status    = zeros( nSession, 1 );
	errMsg    =  cell( nSession, 1 );
	for iSession = 1:nSession

		pngDir = fullfile( AMPSCZdir, sessions{iSession,1}(1:end-2), 'PHOENIX', 'PROTECTED', sessions{iSession,1},...
	                        'processed', sessions{iSession,2}, 'eeg', [ 'ses-', sessions{iSession,3} ], 'Figures' );
		if ~isfolder( pngDir )
			warning( '%s does not exist', pngDir )
			status(iSession) = -2;
			continue
		end
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCimg.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2
			fprintf( '%s exists\n', pngName )
			continue		% status remains 0
		end
		close all

		% note: sessions w/ unexpected task sequence won't get created here!
		%       you'll need to manually supply session indices
		%       create lookup table here?
		try
			AMPSCZ_EEG_sessionDataImage( sessions{iSession,2}, sessions{iSession,3}, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
		catch ME
			status(iSession) = -1;
			errMsg{iSession} = ME.message;
			warning( ME.message )
			continue
% 			vhdr = AMPSCZ_EEG_vhdrFiles( sessions{iSession,2}, sessions{iSession,3}, 'all', 'all', 'all', 'all', 'all', false );
% 			vhdr = { vhdr.name };
% 			runFcn = @(u) str2double( u(end-10:end-9) );
% 			Ivodmmn = cellfun( runFcn, vhdr(~cellfun( @isempty, regexp( vhdr, [ '_task-VODMMN_' ], 'start', 'once' ) )) );
% 			Iaod    = cellfun( runFcn, vhdr(~cellfun( @isempty, regexp( vhdr, [ '_task-AOD_'    ], 'start', 'once' ) )) );
% 			Iassr   = cellfun( runFcn, vhdr(~cellfun( @isempty, regexp( vhdr, [ '_task-ASSR_'   ], 'start', 'once' ) )) );
% 			IrestEO = cellfun( runFcn, vhdr(~cellfun( @isempty, regexp( vhdr, [ '_task-RestEO_' ], 'start', 'once' ) )) );
% 			IrestEC = cellfun( runFcn, vhdr(~cellfun( @isempty, regexp( vhdr, [ '_task-RestEC_' ], 'start', 'once' ) )) );
% 			AMPSCZ_EEG_sessionDataImage( sessions{iSession,2}, sessions{iSession,3}, Ivodmmn, Iaod, Iassr, IrestEO, IrestEC )
		end

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

		status(iSession) = 1;
	end
	fprintf( 'done\n' )

	kCrash = status == -1;
	if any( kCrash )
		tmp = [ sessions(kCrash,2:3), errMsg(kCrash) ]';
		fprintf( '%s\t%s\t%s\n', tmp{:} )
	end

end
