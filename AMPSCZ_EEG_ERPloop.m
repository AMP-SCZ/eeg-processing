function AMPSCZ_EEG_ERPloop( replacePng )
% AMPSCZ_EEG_ERPloop( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_ERPloop( false )

	%% run loop over all processed sessions and make interpolated channel topo pngs if they don't already exist
	
	sessions  = AMPSCZ_EEG_findProcSessions;	
	nSession  = size( sessions, 1 );
	
	filterStr = '[0.2,Inf]';
	taskNames = { 'MMN', 'VOD', 'AOD' };

	nTask     = numel( taskNames );
	status    = zeros( nSession, nTask );		% -1 = error, 2 = old or new png
	errMsg    =  cell( nSession, nTask );		% message for status==-1 sessions
	
	for iSession = 1:nSession

		for iTask = 1:nTask
			try
				% do existence check (single panel pngs) here, where you have taskName & it won't require loading mat-file!
				close all
				fprintf( '%s %s %s\n', sessions{iSession,2}, sessions{iSession,3}, taskNames{iTask} )
				AMPSCZ_EEG_ERPplot( fullfile( AMPSCZ_EEG_procSessionDir( sessions{iSession,2}, sessions{iSession,3} ), 'mat',...
					[ sessions{iSession,2}, '_', sessions{iSession,3}, '_', taskNames{iTask}, '_', filterStr, '.mat' ] ), [], '', replacePng )
				status(iSession,iTask) = 2;
				drawnow
			catch ME
				errMsg{iSession,iTask} = ME.message;
				warning( ME.message )
				status(iSession,iTask) = -1;
				continue
			end
		end

	end
	fprintf( 'done\n' )

	kProblem = status <= 0;		% status == 0 should be impossible
	if any( kProblem(:) )
		fprintf( '\n\nProblem Sessions:\n' )
		kProblem = find( kProblem );
		for iProblem = 1:numel( kProblem )
			[ iSession, iTask ] = ind2sub( [ nSession, nTask ], kProblem(iProblem) );
			fprintf( '\t%s\t%s\t%s\n', sessions{iSession,2:3}, errMsg{iSession,iTask} )
		end
		fprintf( '\n' )
	end

	return

end