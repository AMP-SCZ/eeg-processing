function AMPSCZ_EEG_ERPloop( replacePng )
% AMPSCZ_EEG_ERPloop( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_ERPloop( false )

	%% run loop over all processed sessions and make interpolated channel topo pngs if they don't already exist
	
	sessions  = AMPSCZ_EEG_findProcSessions;	
	nSession  = size( sessions, 1 );
	status    = zeros( nSession, 1 );		% -1 = error, 2 = old or new png
	errMsg    =  cell( nSession, 1 );		% message for status==-1 sessions
	
	filterStr = '[0.2,Inf]';
	taskNames = { 'VOD', 'AOD' };

	for iSession = 1:nSession


		close all
		try
			for iTask = 1:numel( taskNames )
				AMPSCZ_EEG_ERPplot( fullfile( AMPSCZ_EEG_procSessionDir( sessions{iSession,2}, sessions{iSession,3} ), 'mat',...
					[ sessions{iSession,2}, '_', sessions{iSession,3}, '_', taskNames{iTask}, '_', filterStr, '.mat' ] ), [], '', replacePng )
			end
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			status(iSession) = -1;
			continue
		end

		status(iSession) = 2;
	end
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