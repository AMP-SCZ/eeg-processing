function AMPSCZ_EEG_QCcounts( replacePng )
% AMPSCZ_EEG_QCcounts( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_QCcounts( false )

	narginchk( 1, 1 )

	%% run loop over all processed sessions and make event count pngs if they don't already exist

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
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCcounts.png' ];
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
			AMPSCZ_EEG_eventGraph( sessions{iSession,2}, sessions{iSession,3}, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
% 			disp( ME )
			status(iSession) = -1;
			continue
		end

% 		return			% for debugging: make 1 figure, don't save, exit

		% scale if getframe pixels don't match Matlab's figure size
% 		hFig   = gcf;
		hFig   = findobj( 'Type', 'figure', 'Tag', 'AMPSCZ_EEG_eventGraph' );
		bieegl_saveFig( hFig, pngFile )

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
	
		% UCSF:
		% 	CM00051	20220426	bad threshold
		% 	CM00095	20220505	CM00095 20220505: requested run(s) don't exist
		% 	YA00037	20220503	YA00037 20220503: Non-standard run sequence, run indices must be supplied for this session

	return

end