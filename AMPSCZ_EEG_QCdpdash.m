function AMPSCZ_EEG_QCdpdash( replaceFlag )
% AMPSCZ_EEG_QCdpdash( [replaceFlag=false] )

	narginchk( 1, 1 )
	
	if exist( 'replaceFlag', 'var' ) ~= 1 || isempty( replaceFlag )
		replaceFlag = false;
	end

	n      = 0;
	dpdash = cell( n, 3 );

	replaceFlag = false;
	procSess = AMPSCZ_EEG_findProcSessions;
	for i = 1:size( procSess, 1 )
		subjectID = procSess{i,2};
		siteID    = subjectID(1:2);
		siteInfo  = AMPSCZ_EEG_siteInfo;
		kSite     = strcmp( siteInfo(:,1), siteID );
		if nnz( kSite ) ~= 1
			error( 'site id bug' )
		end
		networkName = siteInfo{kSite,2};
		rawDir  = fullfile( AMPSCZ_EEG_paths, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteID ], 'raw', subjectID, 'eeg' );
		csvFile = dir( fullfile( rawDir, sprintf( '%s.%s.Run_sheet_eeg_*.csv', subjectID, networkName ) ) );
		csvFile( cellfun( @isempty, regexp( { csvFile.name }, [ '^', subjectID, '.', networkName, '.', 'Run_sheet_eeg_\d+.csv$' ], 'start', 'once' ) ) ) = [];
		nCSV = numel( csvFile );
		if nCSV == 0
			continue
		end
		for iCSV = 1:nCSV
			csvNumber = regexp( { csvFile.name }, [ '^', subjectID, '.', networkName, '.', 'Run_sheet_eeg_(\d+).csv$' ], 'tokens', 'once' );
			csvNumber = str2double( csvNumber{1}{1} );
			n(:) = n + 1;
			dpdash{n,1} = csvFile.name;
			try
				AMPSCZ_EEG_dpdash( subjectID, csvNumber, replaceFlag )
				dpdash{n,2} = true;
			catch ME
				warning( ME.message )
				dpdash{n,2} = false;
				dpdash{n,3} = ME.message;
				continue
			end
		end
	end
	fprintf( '\n\ndpdash problems:\n' )
	for i = find( ~[ dpdash{:,2} ] )
		fprintf( '%s\t%s\n', dpdash{i,[1,3]} )
	end
	% dpdash problems:
	% IR00057.Pronet.Run_sheet_eeg_1.csv	/data/predict/kcho/flow_test/spero/Pronet/PHOENIX/PROTECTED/PronetIR/processed/IR00057/eeg/ses-20220401 is not a valid directory
	% SF11111.Pronet.Run_sheet_eeg_1.csv	/data/predict/kcho/flow_test/spero/Pronet/PHOENIX/PROTECTED/PronetSF/processed/SF11111/eeg/ses-20220201 is not a valid directory
	% SF11111.Pronet.Run_sheet_eeg_1.csv	/data/predict/kcho/flow_test/spero/Pronet/PHOENIX/PROTECTED/PronetSF/processed/SF11111/eeg/ses-20220201 is not a valid directory
	% GW00005.Prescient.Run_sheet_eeg_1.csv	/data/predict/kcho/flow_test/spero/Prescient/PHOENIX/PROTECTED/PrescientGW/processed/GW00005/eeg/ses-20220224 is not a valid directory
	% ME00077.Prescient.Run_sheet_eeg_1.csv	/data/predict/kcho/flow_test/spero/Prescient/PHOENIX/PROTECTED/PrescientME/processed/ME00077/eeg/ses-20220105 is not a valid directory
	% ME00083.Prescient.Run_sheet_eeg_1.csv	/data/predict/kcho/flow_test/spero/Prescient/PHOENIX/PROTECTED/PrescientME/processed/ME00083/eeg/ses-20220316 is not a valid directory
	

end