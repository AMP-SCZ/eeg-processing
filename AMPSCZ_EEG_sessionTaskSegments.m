function [ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = AMPSCZ_EEG_sessionTaskSegments( subjectID, sessionDate )
% Lookup table of non-standard runs to use in EEG analyses
% here runs mean continuous segments of data, e.g. a paused trial could produce multiple runs
% during a single stimulus sequence
%
% [ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = AMPSCZ_EEG_sessionTaskSegments( subjectID, sessionDate )

	[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( [] );

	if ispc

		% UCSF
		switch [ subjectID, '_', sessionDate ]
			case 'GA00073_20220406'
				VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [];		% 1 run of VODMMN & AOD each split over 2 segments, + ASSR & 2 rest runs
			case 'MA00007_20211124'
				VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];	% 3 VODMMN & 2 AOD only
			case 'MT00099_20220202'
				VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'NC00002_20220408'
				VODMMNruns = [1:6]; AODruns = [1:3]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];	%incomplete [6VODMMN,3AOD], don't bother
			case 'NC00002_20220422'
				VODMMNruns = [1:4]; AODruns = [0]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 3 VODMMNN runs, last 1 split over 2 segments.  line noise test
			case 'NC00052_20220304'
				VODMMNruns = [1:2,5:7]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'NC00068_20220304'
				VODMMNruns = [1,3:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'NN00054_20220216'
				VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'PI00034_20220121'
				VODMMNruns = [1:6]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'SF11111_20220201'
				VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];	% 2 VODMMN & 2 AOD only.  noise tests
			case 'SF11111_20220308'
				VODMMNruns = [1:2]; AODruns = [1]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 2 VODMMN & 1 AOD only.  noise tests
			case 'YA00059_20220120'
				VODMMNruns = []; AODruns = [2:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case { 'YA00087_20220208', 'YA00037_20220503' }
				VODMMNruns = [2:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'BM00066_20220209'
				VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'GW00005_20220126'
				VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'LS00074_20220427'
				VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'ME00099_20220217'
				VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
		end
	else

		% DPACC
		switch [ subjectID, '_', sessionDate ]
			case 'MA00007_20211124'
				VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = [0]; RestEOruns = [0]; RestECruns = [0];		% 3 VODMMN & 2 AOD only
			case 'MT00099_20220202'
				VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'NC00052_20220304'
				VODMMNruns = [1:2,5:7]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'NC00068_20220304'
				VODMMNruns = [1,3:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'NN00054_20220216'
				VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'OR00003_20211110'
				VODMMNruns = [1:3]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'OR00019_20211217'
				VODMMNruns = [1:2]; AODruns = [1:2]; ASSRruns = []; RestEOruns = []; RestECruns = [0];
			case 'PA00000_20211014'
				VODMMNruns = [1:4]; AODruns = [1:5]; ASSRruns = []; RestEOruns = [0]; RestECruns = [0];
			case 'PI00034_20220121'
				VODMMNruns = [1:6]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'YA00059_20220120'
				VODMMNruns = []; AODruns = [2:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case { 'YA00087_20220208', 'YA00037_20220503' }
				VODMMNruns = [2:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'BM00066_20220209'
				VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'GW00005_20220126'
				VODMMNruns = []; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'LS00002_20211207'
				VODMMNruns = [1:4]; AODruns = [1:5]; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'LS00018_20220120'
				VODMMNruns = [1:7]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'LS00074_20220427'
				VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
			case 'ME00099_20220217'
				VODMMNruns = [1:6]; AODruns = []; ASSRruns = []; RestEOruns = []; RestECruns = [];
		end

	end

end
