function AMPSCZ_EEG_QCperformance( replacePng )
% AMPSCZ_EEG_QCperformance( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_QCperformance( false )

	narginchk( 1, 1 )

	%% run loop over all processed sessions and make response rate & reaction time pngs if they don't already exist

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
		pngName = {
			[ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCresponseAccuracy.png' ]
			[ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCresponseTime.png' ]
		};
		pngFile  = fullfile( pngDir, pngName );
		pngWrite = cellfun( @(u)exist(u,'file')~=2, pngFile ) | replacePng;
		if ~any( pngWrite )
			fprintf( '%s exists\n', pngName{:} )
			status(iSession) = 1;
			continue
		end

		close all
		try
			AMPSCZ_EEG_performance( sessions{iSession,2}, sessions{iSession,3} );
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			status(iSession) = -1;
			continue
		end

% 		return			% for debugging: make 1 figure, don't save, exit

		figTag = { '-rate', '-RT' };
		for i = find( [ pngWrite(:) ]' )
			% scale if getframe pixels don't match Matlab's figure size
			hFig   = findobj( 'Type', 'figure', 'Tag', [ 'AMPSCZ_EEG_performance', figTag{i} ] );
			figPos = get( hFig, 'Position' );
			img = getfield( getframe( hFig ), 'cdata' );
			if size( img, 1 ) ~= figPos(4)
				img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
			end
			% save
			imwrite( img, pngFile{i}, 'png' )
			fprintf( 'wrote %s\n', pngFile{i} )
		end

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

	return

end