function AMPSCZ_EEG_QCinterp( replacePng )
% AMPSCZ_EEG_QCinterp( replacePng )
% replacePng = true or false

% AMPSCZ_EEG_QCinterp( false )

	%% run loop over all processed sessions and make interpolated channel topo pngs if they don't already exist
	
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
		pngName = [ sessions{iSession,2}, '_', sessions{iSession,3}, '_QCinterp.png' ];
		pngFile = fullfile( pngDir, pngName );
		if exist( pngFile, 'file' ) == 2 && ~replacePng
			fprintf( '%s exists\n', pngName )
			status(iSession) = 1;
			continue
% 		elseif exist( pngFile, 'file' ) == 2
% 			pngDate = dir( pngFile );
% 			if pngDate.datenum > datenum( [ 2022 5 23 ] )
% 				fprintf( 'keeping %s\n', pngName )
% 				continue
% 			end
		end

		close all
		try
			AMPSCZ_EEG_interpChanMap( sessions{iSession,2}, sessions{iSession,3} )
		catch ME
			errMsg{iSession} = ME.message;
			warning( ME.message )
			status(iSession) = -1;
			continue
		end

% 		return			% for debugging: make 1 figure, don't save, exit

		% scale if getframe pixels don't match Matlab's figure size
% 		hFig   = gcf;
		hFig   = findobj( 'Type', 'figure', 'Tag', 'AMPSCZ_EEG_interpChanMap' );
		figPos = get( hFig, 'Position' );
		img = getfield( getframe( hFig ), 'cdata' );
		if size( img, 1 ) ~= figPos(4)
			img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
		end
		
		% save
		imwrite( img, pngFile, 'png' )
		fprintf( 'wrote %s\n', pngFile )

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
		% UCSF - not all [0.2,Inf]
		% 	CA00057	20220128	missing task(s)
		% 	CA00063	20220202	missing task(s)
		% 	CM00095	20220505	C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PronetCM\processed\CM00095\eeg\ses-20220505\mat is not a valid directory
		% 	GA00095	20211203	missing task(s)
		% 	NC00002	20220408	C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PronetNC\processed\NC00002\eeg\ses-20220408\mat is not a valid directory
		% 	NC00002	20220422	C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PronetNC\processed\NC00002\eeg\ses-20220422\mat is not a valid directory
		% 	NL00038	20220119	missing task(s)
		% 	OR00053	20220131	missing task(s)
		% 	PA00050	20211202	missing task(s)
		% 	PI00056	20211230	missing task(s)
		% 	PV00002	20220117	missing task(s)
		% 	PV00018	20220126	missing task(s)
		% 	SD00059	20211217	missing task(s)
		% 	SD00065	20211221	missing task(s)
		% 	SF11111	20220201	C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PronetSF\processed\SF11111\eeg\ses-20220201\mat is not a valid directory
		% 	SF11111	20220308	C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PronetSF\processed\SF11111\eeg\ses-20220308\mat is not a valid directory
		% 	SI00059	20220113	missing task(s)
		% 	TE00074	20220124	missing task(s)
		% 	WU00057	20220126	missing task(s)
		% 	YA00037	20220503	C:\Users\donqu\Box\Certification Files\Pronet\PHOENIX\PROTECTED\PronetYA\processed\YA00037\eeg\ses-20220503\mat is not a valid directory
		% 	YA00059	20220120	missing task(s)
		% 	YA00071	20220208	missing task(s)
		% 	YA00087	20220208	missing task(s)
		% 	HK00068	20220104	missing task(s)
		% 	HK00074	20220105	missing task(s)
		% 	HK00080	20220106	missing task(s)
		% 	HK00096	20220111	missing task(s)
		% 	JE00052	20220106	missing task(s)
		% 	LS00052	20220202	missing task(s)
		% 	ME00055	20211221	missing task(s)
		% 	ME00061	20220105	missing task(s)

	return

end