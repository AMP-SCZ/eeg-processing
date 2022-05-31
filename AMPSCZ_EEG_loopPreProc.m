function AMPSCZ_EEG_loopPreProc( writeFlag )
% AMPSCZ_EEG_loopPreProc( writeFlag )

	narginchk( 1, 1 )

	passBand  = [ 0.2, Inf ];
% 	writeFlag = [];

	sessions  = AMPSCZ_EEG_findProcSessions;	
	nSession  = size( sessions, 1 );
	status    = zeros( nSession, 1 );		% 0 = nothing, 1 = MMN, 2 = MMN+VOD, 3 = MMN+VOD+AOD, 4 = MMN+VOD+AOD+ASSR i.e. everything
	errMsg    =  cell( nSession, 1 );		% message for status==-1 sessions

	for iSession = 1:nSession
		
		subjectID   = sessions{iSession,2};
		sessionDate = sessions{iSession,3};
	
		[ Ivodmmn, Iaod, Iassr, IrestEO, IrestEC ] = AMPSCZ_EEG_sessionTaskSegments( subjectID, sessionDate );
		if all( cellfun( @isempty, { Ivodmmn, Iaod, Iassr, IrestEO, IrestEC } ) )
			try
				% If all are index variables are empty, then subject might not have been checked
				% run AMPSCZ_EEG_vhdrFiles w/ all defaults to see
				AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, [], [], [], [], [], false );				
			catch ME
				errMsg{iSession} = ME.message;
				continue
			end
		end
		try
			timeStamp = clock;	
			AMPSCZ_EEG_preproc( subjectID, sessionDate, 'MMN' , passBand, writeFlag, Ivodmmn )
			status(iSession) = 1;
			AMPSCZ_EEG_preproc( subjectID, sessionDate, 'VOD' , passBand, writeFlag, Ivodmmn )
			status(iSession) = 2;
			AMPSCZ_EEG_preproc( subjectID, sessionDate, 'AOD' , passBand, writeFlag, Iaod )
			status(iSession) = 3;
			AMPSCZ_EEG_preproc( subjectID, sessionDate, 'ASSR', passBand, writeFlag, Iassr )
			status(iSession) = 4;
			hms = zeros( 1, 3 );
			hms(3) = etime( clock, timeStamp );
			hms(1) = floor( hms(3) / 3600 );
			hms(3) = hms(3) - hms(1) * 3600;
			hms(2) = floor( hms(3) / 60 );
			hms(3) = hms(3) - hms(2) * 60;
			fprintf( 'elapsed time = %02d:%02d:%06.3f\n', hms )
		catch ME
			errMsg{iSession} = ME.message;
		end
	end
	
	kProblem = status < 4;
	if any( kProblem )
		fprintf( '\n\nProblem Sessions:\n' )
		kProblem = find( kProblem );
		for iProblem = 1:numel( kProblem )
			fprintf( '\t%s\t%s\t%s\n', sessions{kProblem(iProblem),2:3}, errMsg{kProblem(iProblem)} )
		end
		fprintf( '\n' )
	end

end