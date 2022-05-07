function AMPSCZ_EEG_QCimg%( loopType )


replacePng = false;

	%% run loop over all processed sessions and make raw data image pngs if they don't already exist

	sessions  = AMPSCZ_EEG_findProcSessions;	
	nSession  = size( sessions, 1 );
	status    = zeros( nSession, 1 );		% -1 = error, 1 = keep current png, 2 = new png
	errMsg    =  cell( nSession, 1 );		% message for status==-1 sessions
	for iSession = 1:nSession

		pngDir = fullfile( AMPSCZ_EEG_procSessionDir( sessions{iSession,2}, sessions{iSession,3}, sessions{iSession,1}(1:end-2) ), 'Figures' );
		if ~isfolder( pngDir )
			mkdir( pngDir )
			fprintf( 'created %s\n', pngDir )
		end
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCimg.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2 && ~replacePng
			fprintf( '%s exists\n', pngName )
			status(iSession) = 1;
			continue
		end
		

		% note: sessions w/ unexpected task sequence won't get created here!
		%       you'll need to manually supply session indices
		close all
		try
			[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = AMPSCZ_EEG_sessionTaskSegments( sessions{iSession,2}, sessions{iSession,3} );
			AMPSCZ_EEG_sessionDataImage( sessions{iSession,2}, sessions{iSession,3}, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			status(iSession) = -1;
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

		status(iSession) = 2;
	end
	fprintf( 'done\n' )

	kProblem = status <= 0;		% status == 0 should be impossible
	if any( kProblem )
		% double subject/session labels coming form AMPSCZ_EEG_vhdrFiles.m
		fprintf( '\n\nProblem Sessions:\n' )
		kProblem = find( kProblem );
		for iProblem = 1:numel( kProblem )
			fprintf( '\t%s\t%s\t%s\n', sessions{kProblem(iProblem),2:3}, errMsg{kProblem(iProblem)} )
		end
		fprintf( '\n' )
	end

end