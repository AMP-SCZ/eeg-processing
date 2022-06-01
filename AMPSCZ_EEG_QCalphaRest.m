function AMPSCZ_EEG_QCalphaRest( replacePng )
% AMPSCZ_EEG_QCalphaRest( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_QCalphaRest( false )

	%% run loop over all processed sessions and make resting spectra pngs if they don't already exist

	sessions  = AMPSCZ_EEG_findProcSessions;	
	nSession  = size( sessions, 1 );
	status    = zeros( nSession, 1 );		% -1 = error, 1 = keep current png, 2 = new png
	errMsg    =  cell( nSession, 1 );		% message for status==-1 sessions

% 	hWait   = waitbar( 0, '' );
	for iSession = 1:nSession

% 		waitbar( (iSession-1)/nSession, hWait, sessions{iSession,2} )
		pngDir = fullfile( AMPSCZ_EEG_procSessionDir( sessions{iSession,2}, sessions{iSession,3}, sessions{iSession,1}(1:end-2) ), 'Figures' );
		if ~isfolder( pngDir )
			mkdir( pngDir )
			fprintf( 'created %s\n', pngDir )
		end
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCrestAlpha.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2 && ~replacePng
			fprintf( '%s exists\n', pngName )
			status(iSession) = 1;
			continue
		end

		close all
		try
			AMPSCZ_EEG_alphaRest( sessions{iSession,2}, sessions{iSession,3} )
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			status(iSession) = -1;
			continue
		end

% 		return			% for debugging: make 1 figure, don't save, exit

		% scale if getframe pixels don't match Matlab's figure size
% 		hFig   = gcf;
		hFig   = findobj( 'Type', 'figure', 'Tag', 'AMPSCZ_EEG_alphaRest' );
		bieegl_saveFig( hFig, pngFile )

		status(iSession) = 2;
% 		waitbar( iSession/nSession, hWait )
	end
% 	close( hWait )
	fprintf( 'done\n' )

	kProblem = status <= 0;		% status == 0 should be impossible
	if any( kProblem )
		fprintf( '\n\nProblem Sessions:\n' )
		kProblem = find( kProblem );
		for iProblem = 1:numel( kProblem )
			fprintf( '\t%s\t%s\t%s\n', sessions{kProblem(iProblem),2:3}, errMsg{kProblem(iProblem)} )
		end
		fprintf( '\n' )
	end

	return
	
end