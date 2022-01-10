function AMPSCZ_EEG_preproc( subjectID, sessionDate, epochName, passBand, forceWrite )
% Pre-process segmented AMP SCZ Brain Vision files for MMN, VOD, or AOD ERP analysis.
% Saves output in mat-file format
%
% Usage:
% >> AMPSCZ_EEG_preproc( subjectID, sessionDate, epochName, [passBand], [forceWrite] )
%
% Where:
%   subjectID   = 7-character subject identifier, 2-char site code + 5-digit subject #
%   sessionDate = 8-character date 'YYYYMMDD'
%   epochName   = 'AOD', 'MMN', or 'VOD'
%   passBand    = option input [ lowFreq, highFreq ] (Hz), default = [ 0.1, 50 ]
%   forceWrite  = how to handle mat-files that already exist, default = []
%                 true = overwrite, false = don't overwrite, [] = prompt if needed
%
% Dependencies: EEGLAB

% using BJR's faster_batch_AOD.m as a guide

% EEGLAB extensions:
% bva-io v1.7
% ERPLAB v8.10
% FASTER v1.2.3b

% for debugging only
% Extension Biosig version 3.7.9 now installed

% To do:

% check offsets in ProNET - done.  move the offset test into bieegl_FASTER so it can get logged?
% check ref channels before rereferencing - in progress
% read impedances out of .vhdr - ok, then what?
% make this sweep directory tree for available bids files that haven't been analyzed yet
% make figures of removed components, or tool for viewing them after the fact

% VIS has ~squarish ~520ms pulse ~every 2sec

% EEGLAB plugins: Biosig, bva-io, ERPLAB, FASTER, [ clean_rawdata, dipfit, firfilt, ICLabel ]

% is this perfectly repeatable? or is there random component besides bootstrap?

% ??? channel_properties.m can't handle discontinuous channel indices ???  FASTER's a disaster

% this function could use a new name, bieegl_FASTER is really more of the pre-processing program
% this mainly gets set up to run it, and does some minor checks & input reconfigurng/gathering to run it
% it also only does VODMMN & AOD runs!

	narginchk( 3, 5 )
	
	% EEGLAB (pop_eegfiltnew.m) recommends HPF > 1, no LPF?
	% if doing bandpass, do it in 2 parts? to avoid low-pass having steeper slope than highpass? not relevant for ERPLAB pop_basicfilter.m
	% https://eeglab.org/tutorials/05_Preprocess/Filtering.html
	if exist( 'passBand', 'var' ) ~= 1 || isempty( passBand )
		passBand = [ 0.1, 50 ];
	end
	if exist( 'forceWrite', 'var' ) ~= 1 %|| isempty( forceWrite )
% 		forceWrite = false;
		forceWrite = [];
	end
	if iscell( epochName )
		% they get checked later, but might as well know about errors up front
		if ~all( cellfun( @ischar, epochName ) ) || ~all( ismember( epochName, { 'MMN', 'VOD', 'AOD' } ) )
			error( 'Invalid epochName input' )
		end
		for iEpoch = 1:numel( epochName )
			AMPSCZ_EEG_preproc( subjectID, sessionDate, epochName{iEpoch}, passBand, forceWrite )
		end
		return
	end

	% Machine-dependent paths
	if isunix
% 		AMPSCZdir = '/data/predict/kcho/flow_test';					% don't work here, outputs will get deleted.  aws rsync to NDA s2
		AMPSCZdir = '/data/predict/kcho/flow_test/spero';			% kevin got rid of group folder & only gave me pronet?	
		eegLabDir = '/PHShome/sn1005/Downloads/eeglab/eeglab2021.1';
		adjustDir = '';
		error( 'needs ADJUST1.1.1' )
	else %if ispc
		AMPSCZdir = 'C:\Users\donqu\Documents\NCIRE\AMPSCZ';
		eegLabDir = 'C:\Users\donqu\Downloads\eeglab\eeglab2021.1';
		adjustDir = 'C:\Users\donqu\Downloads\adjust\ADJUST1.1.1';
	end
	if ~isfolder( AMPSCZdir )
		error( 'Invalid project directory' )
	end
	AMPSCZtools = fileparts( mfilename( 'fullpath' ) );
	locsFile    = fullfile( AMPSCZtools, 'AMPSCZ_EEG_actiCHamp65ref.ced' );

	sessionList = AMPSCZ_EEG_findProcSessions;
	
% 	iSession = find( ismember( sessionList(:,2:3), { subjectID, sessionDate }, 'rows' ) );		% 'rows' doesn't work on cell arrays!
	iSession = find( strcmp( sessionList(:,2), subjectID ) & strcmp( sessionList(:,3), sessionDate ) );	
	if numel( iSession ) ~= 1
		error( 'Can''t identify session' )
	end

	taskList = { 'VODMMN', 5; 'AOD', 4 };

	% need to make this whole thing a function and loop epochNames if not sessions too
	if ~ischar( epochName ) || ~ismember( epochName, { 'MMN', 'VOD', 'AOD' } )
		error( 'invalid epochName' )
	end
	iTask = contains( taskList(:,1), epochName );
	if sum( iTask ) ~= 1
		error( 'invalid epochName %s', epochName )
	end
	iTask = find( iTask );
	
	Ieog = [];
	
	baselineWin = [ -0.100, 0 ];
	
	% Event trigger codes for form epochs around ---------------------------
	% I'm calling them codes here, but they're a match for eeg.event.type, not eeg.event.code!
	[ standardCode, targetCode, novelCode, respCode ] = AMPSCZ_EEG_eventCodes( epochName );			% MMN deviants in novelCode
	switch epochName
		case 'VOD'
			epochWin     = [ -1   , 2    ];	% relative to event (sec)
			icaWin       = [ -0.25, 0.75 ];
		case 'MMN'
			epochWin     = [ -0.5 , 0.5  ];
			icaWin       = [ -0.25, 0.25 ];			% In BJR code [-0.245,0.245] for VODMMN & [-0.25,0.75] for AOD
		case 'AOD'
			epochWin     = [ -1   , 2    ];
			icaWin       = [ -0.25, 0.75 ];
	end
	RTrange = AMPSCZ_EEG_RTrange;

	epochEventCodes = { standardCode, targetCode, novelCode };
	% remove empties
	epochEventCodes( cellfun( @isempty, epochEventCodes ) ) = [];

	% Check for dependencies
	% get rid of fieldtrip, nuclear option of restoring default path
	if ~contains( which( 'hann.m' ), matlabroot )		% There's a hann.m in fieldrip, that's pretty useless, it just calls hanning.m
% 		error( 'fix path so hann.m is native MATLAB' )
		restoredefaultpath
	end	
	% -- EEGLAB + plugins
	if isempty( which( 'eeglab' ) )
		addpath( eegLabDir, '-begin' )
		% nogui doesn't actually put every thing on path???  FASTER yes, ERPLAB subfolders no
% 		eeglab( 'nogui' )
		eeglab
		% GUI: File > Quit
		% MenuSelectedFcn: 'close(gcf); disp('To save the EEGLAB command history  >> pop_saveh(ALLCOM);');clear global EEG ALLEEG LASTCOM CURRENTSET;'
		drawnow
		close( gcf )
		% ALLCOM                       CURRENTERP                   ERP                          STUDY
		% ALLEEG                       CURRENTSET                   LASTCOM                      eegLabDir
		% ALLERP                       CURRENTSTUDY                 PLUGINLIST                   globalvars
		% ALLERPCOM                    EEG                          RESTOREDEFAULTPATH_EXECUTED  plotset
		clear global EEG ALLEEG LASTCOM CURRENTSET		% there's still a bunch of variables, some global.

	% paths added by both eeglab & eeglab('noqui')
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\adminfunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\guifunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\miscfunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\popfunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\sigprocfunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\statistics
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\studyfunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\supportfiles
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\functions\timefreqfunc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\Biosig3.7.9\biosig\doc
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\Biosig3.7.9\biosig\t200_FileAccess
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\Biosig3.7.9\biosig\t250_ArtifactPreProcessingQualityControl
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\FASTER1.2.3b
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ICLabel
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\bva-io1.7
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\clean_rawdata
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\dipfit4.3
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\firfilt
	% paths added by eeglab but not eeglab('noqui')
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\.github
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\GUIs
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\deprecated_functions
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\erplab_Box
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\functions
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\functions\csd
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\images
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\images\colormap_lic
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ERPLAB8.10\pop_functions
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ICLabel\matconvnet\examples
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ICLabel\matconvnet\matlab
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ICLabel\matconvnet\matlab\mex
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ICLabel\matconvnet\matlab\simplenn
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\ICLabel\matconvnet\matlab\xtest
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\clean_rawdata\manopt
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\clean_rawdata\manopt\manopt\core
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\clean_rawdata\manopt\manopt\manifolds\grassmann
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\clean_rawdata\manopt\manopt\solvers\trustregions
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\clean_rawdata\manopt\manopt\tools
	% paths added by eeglab('noqui') but not eeglab
	% 	C:\Users\VHASFCNichoS\Downloads\EEGLAB\eeglab_current\eeglab2021.1\plugins\Biosig3.7.9

	end
	if ~contains( which( 'pop_select.m' ), 'modifications' )
		addpath( fullfile( AMPSCZtools, 'modifications', 'eeglab' ), '-begin' )
	end
	if ~contains( which( 'channel_properties.m.m' ), 'modifications' )
		addpath( fullfile( AMPSCZtools, 'modifications', 'faster' ), '-begin' )
	end
	
	% -- ADJUST
	if isempty( which( 'ADJUST.m' ) )
		addpath( adjustDir, '-begin' )
	end

	siteTag = sessionList{iSession,2}(1:2);
	subjTag = [ 'sub-',  sessionList{iSession,2} ];
	sessTag = [ 'ses-',  sessionList{iSession,3} ];
	taskTag = [ 'task-', taskList{iTask,1} ];


	% Read channel locations file ------------------------------------------
	% standard locations saved in file
	% e.g. pop_chanedit( struct( 'labels', { eeg.chanlocs.labels } ) )...		w/ or w/o FCz ref?
	% readlocs vs pop_readlocs?
	chanLocs = readlocs( locsFile );
	nLoc     = numel( chanLocs );
	Ieeg     = find( strcmp( { chanLocs.type }, 'EEG' ) );
	InotEEG  = setdiff( 1:nLoc, Ieeg );
	nEEG     = numel( Ieeg );
	if all( Ieeg == (1:nEEG) )
		Ireorder = [];
	else
		Ireorder   = [ Ieeg, InotEEG ];
		Ieeg(:)    = 1:nEEG;
		InotEEG(:) = nEEG+1:nLoc;
	end

	sessDir = fullfile( AMPSCZdir, sessionList{iSession,1}(1:end-2), 'PHOENIX', 'PROTECTED', sessionList{iSession,1}, 'processed', sessionList{iSession,2}, 'eeg', sessTag );
	bvDir   = fullfile( sessDir, 'BIDS' );
	matDir  = fullfile( sessDir, 'mat'  );
	if ~isfolder( matDir )
		mkdir( matDir )		% you can run mkdir all at once, don't need to do it one layer at a time
	end
	logFile = fullfile( matDir, sprintf( '%s_%s_%s.log', subjTag(5:end), sessTag(5:end), epochName ) );
	matFile = fullfile( matDir, sprintf( '%s_%s_%s_[%g,%g].mat', subjTag(5:end), sessTag(5:end), epochName, passBand(1), passBand(2) ) );
	writeFlag = exist( matFile, 'file' ) ~= 2;
	if ~writeFlag
		if isempty( forceWrite )
			writeFlag(:) = strcmp( questdlg( 'Replace?', 'mat-file', 'No', 'Yes', 'No' ), 'Yes' );
			if ~writeFlag
				return
			end
		elseif forceWrite
			warning( '%s will be overwritten', matFile )		% logFile too
			writeFlag(:) = true;
		else
			fprintf( '%s exists\n', matFile )
			return
		end
	end

	nRun      = taskList{iTask,2};
	EEG       = repmat( eeg_checkset( eeg_emptyset ), [ 1, nRun ] );
% 	epochInfo = struct( 'latency', cell( 1, nRun ), 'kStandard', [], 'kTarget', [], 'kNovel', [], 'kCorrect', [], 'Nstandard', [], 'respLat', [] );		% latency is event latency, respLat is response latency
	epochInfo = struct( 'latency', cell( 1, nRun ), 'kStandard', [], 'kTarget', [], 'kNovel', [], 'kCorrect', [], 'respLat', [] );		% latency is event latency, respLat is response latency
	nExtra    = zeros( 1, nRun );
	for iRun = 1:nRun

		% Load BrainVision data ------------------------------------------------
		% pop_loadbv requires bva-io
		% note:	EEG(iRun).ref = 'common';
		%       EEG(iRun).chaninfo.nosedir = '+X' even though there's no coords in eeg.chanlocs!

		runTag = sprintf( 'run-%02d', iRun );
		bvFile = sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, taskTag, runTag );
		EEG(iRun) = pop_loadbv( bvDir, bvFile );
		% lost samples markers end up as 'New Segment' code, 'boundary' type, just like regular new segment markers!
		% if there's more than 1, I can probably assume it's a lost segment, but it sure would be nice if EEGLAB
		% didn't strip this info.
		mrk = bieegl_readBVtxt( fullfile( bvDir, [ bvFile(1:end-3), 'mrk' ] ) );
		kLostSamples = strncmp( { mrk.Marker.Mk.description }, 'LostSamples:', 12 );
		if any( kLostSamples )
			nLost = regexp( { mrk.Marker.Mk(kLostSamples).description }, '^LostSamples: (\d+)$', 'tokens', 'once' );
			nLost = str2double( [ nLost{:} ] );
			error( '%d Lost epochs, %d samples total in %s', numel( nLost ), sum( nLost ), bvFile )
		end

		if iRun == 1
			% impedance will be the same for all runs & all tasks, since it is replicated when segmented
			% the exception will be if there are multiple zip files, it may only be in the 1st
			Z = AMPSCZ_EEG_readBVimpedance( fullfile( bvDir, bvFile ) );		% 65x2 { name, impedance }
		end
		% handle AOD stimulus bug, replace any repsonse code 17s w/ 5s ---------
		if strcmp( taskList{iTask,1}, 'AOD' )
			k17 = strcmp( { EEG(iRun).event.type }, 'S 17' );
			if any( k17 )
				[ EEG(iRun).event(k17).type ] = deal( 'S  5' );
			end
			clear k17
		end
		
		% set EEG.ref field ----------------------------------------------------
		% and add all-zero reference channel FCz if it's in locations file
% 		EEG(iRun).chanlocs = chanLocs;
		addRefChan = nLoc == EEG(iRun).nbchan + 1;			% add extra all-zero reference channel?
		if addRefChan
			% check channel locations file to make sure last channel is expected reference
			if ~strcmp( chanLocs(nLoc).labels, 'FCz' )
				error( 'expecting channel #%d = FCz', nLoc )
			end
			% check data file to make sure expected reference isn't already present
			if any( strcmp( { EEG(iRun).chanlocs.labels }, chanLocs(nLoc).labels ) )
				error( 'channel %s already exists in data', chanLocs(nLoc).labels )
			end
			% set reference in EEG structure, loads as 'common'
			EEG(iRun).ref = chanLocs(nLoc).labels;
			% add in reference channel full of zeros
			EEG(iRun).nbchan(:) = nLoc;
			EEG(iRun).data(EEG(iRun).nbchan,:) = 0;
			EEG(iRun).chanlocs(EEG(iRun).nbchan).labels = EEG(iRun).ref;
			EEG(iRun).chanlocs(EEG(iRun).nbchan).ref    = '';		% this is not EEG.ref!  they're all empty, make it char?
			EEG(iRun).chanlocs(EEG(iRun).nbchan).type   = '';
		else
			% don't add any channels, just get reference channel name from .vhdr file and put in in EEG.ref
			hdr  = bieegl_readBVtxt( fullfile( bvDir, bvFile ) );
			kRef = ~cellfun( @isempty, regexp( hdr.Comment, '^Reference Channel Name = .+$', 'once', 'start' ) );
			if sum( kRef ) ~= 1
				error( 'can''t identify ref channel name from .vhdr' )
			end
			refName = regexp( hdr.Comment{kRef}, '^Reference Channel Name = (.+)$', 'once', 'tokens' );
			EEG(iRun).ref = refName{1};
			clear hdr kRef refName
		end
		

		% Get channel locations ------------------------------------------------
		% verify that your locations file labels match the data file
		% then copy fields from chanLocs to EEG
		if numel( chanLocs ) ~= EEG(iRun).nbchan || ~all( strcmp( { EEG(iRun).chanlocs.labels }, { chanLocs.labels } ) )
			error( '%s labels don''t match data' )
		end
		replaceChanField = ~false;	% replace existing fields of EEG(iRun).chanlocs?
		addChanField     = ~false; 	%     add      new fields to EEG(iRun).chanlocs?
		fn1 = setdiff( fieldnames( EEG(iRun).chanlocs ), 'labels' );
		fn2 = setdiff( fieldnames(           chanLocs ), 'labels' );
		for iChan = 1:EEG(iRun).nbchan
			for fn = fn2'
				if ~isempty( chanLocs(iChan).(fn{1}) )
					if ismember( fn{1}, fn1 )
						if isempty( EEG(iRun).chanlocs(iChan).(fn{1}) )
							EEG(iRun).chanlocs(iChan).(fn{1}) = chanLocs(iChan).(fn{1});	% replace empty with new
						elseif replaceChanField
							EEG(iRun).chanlocs(iChan).(fn{1}) = chanLocs(iChan).(fn{1});	% replace old with new
						end
					elseif addChanField
						EEG(iRun).chanlocs(iChan).(fn{1}) = chanLocs(iChan).(fn{1});		% replace missing with new
					end
				else		% empty field in locs file, do nothing?
				end
			end
		end
		clear fn1 fn2 iChan fn % replaceChanField addChanField
		
		% Ensure EEG channels are first
		% some EEGLAB FASTER plugin functions may choke if not?
		% don't reorder until you're done with chanLocs struct
		if ~isempty( Ireorder )
			fprintf( 'Re-ordering channels to move reference\n' )
			EEG(iRun).chanlocs(:) = EEG(iRun).chanlocs(Ireorder);
			EEG(iRun).data(:)     = EEG(iRun).data(Ireorder,:);
		end


		% Replace EEG(iRun).event.type with numeric value ----------------------
		% *** this was a bad idea ***
		% note: segment  markers have type='boundary', code='New Segment'
		%       stimulus markers have type='S###'    , code='Stimulus'
		%       in .vmrk file 'New Segment' and 'Stimulus' are both type
		%       epochs get created based on type, so identifying codes must go there
% 		nEvent = numel( EEG(iRun).event );
% 		for iEvent = 1:nEvent
% 			switch EEG(iRun).event(iEvent).code
% 				case 'New Segment'
% 					% change 'boundary' type events to numeric code 0
% 					EEG(iRun).event(iEvent).type = 0;
% 				case 'Stimulus'
% 					% change 'stimulus' type events to numeric 
% 					eventTok  = regexp( EEG(iRun).event(iEvent).type, '^S\s*(\d+)$', 'once', 'tokens' );
% 					if isempty( eventTok )
% 						error( 'Unknown event type' )
% 					end
% 					EEG(iRun).event(iEvent).type = eval( eventTok{1} );		% numeric code
% 				otherwise
% 					error( 'Unknown event oode(s)' )
% 			end
% 		end
% 		clear iEvent

		% Stimulus indices & type sequence -------------------------------------
		Istim     = find( ismember( { EEG(iRun).event.type }, epochEventCodes ) );
		stimSeq   = { EEG(iRun).event(Istim).type };
		nStim     = numel( Istim );
		kStandard = strcmp( stimSeq, standardCode );
		if isempty( targetCode )
			kTarget = false( 1, nStim );
		else
			kTarget = strcmp( stimSeq, targetCode );
		end
		if isempty( novelCode )
			kNovel  = false( 1, nStim );
		else
			kNovel  = strcmp( stimSeq, novelCode );
		end
		clear stimSeq

		% Response latencies & correct button flags for target & novel ---------
		respLat = nan( 1, nStim );		% response latency (samples)
		dIRange = RTrange * EEG(iRun).srate;
% 		if isempty( respCode )			% MMN
% 			Iresp = find( strcmp( { EEG(iRun).event.type }, 'S 17' ) );		% use VOD response code
% 		else
			Iresp = find( strcmp( { EEG(iRun).event.type }, respCode ) );
% 		end

		% store extra button presses? logic could be simplified if not tracking this
		nExtra(iRun)  = sum( Iresp <= Istim(1) );
		for iStim = 1:nStim-1
			% button presses between current stimulus (standard/target/novel) and next one
			% button and stim trigger can't be simultaneous can they?
% 			kResp = Iresp > Istim(iStim) & Iresp <= Istim(iStim+1);		% this is almost certainly fine here, but not when adding dIRange below
			kResp = [ EEG(iRun).event(Iresp).latency ] > EEG(iRun).event(Istim(iStim)).latency & [ EEG(iRun).event(Iresp).latency ] <= EEG(iRun).event(Istim(iStim+1)).latency;
			if any( kResp )
				% start by adding all responses in an inter-stimulus interval
				nExtra(iRun) = nExtra(iRun) + sum( kResp );
				% then check if any reaction times are in bounds
% 				kResp(kResp) = Iresp(kResp) >= ( Istim(iStim) + dIRange(1) ) & Iresp(kResp) <= ( Istim(iStim) + dIRange(2) );
				kResp(kResp) = [ EEG(iRun).event(Iresp(kResp)).latency ] >= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(1) ) &...
				               [ EEG(iRun).event(Iresp(kResp)).latency ] <= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(2) );
			end
			if any( kResp )
				% the good response wasn't extra, subtract it
				nExtra(:) = nExtra(iRun) - 1;
				% take the 1st of multiple viable button presses
% 				respLat(iStim) = Iresp(find(kResp,1,'first')) - Istim(iStim);
				respLat(iStim) = EEG(iRun).event(Iresp(find(kResp,1,'first'))).latency - EEG(iRun).event(Istim(iStim)).latency;
			end
		end
		iStim = nStim;
			% button presses after final stimulus
% 			kResp = Iresp > Istim(iStim);
			kResp = [ EEG(iRun).event(Iresp).latency ] > EEG(iRun).event(Istim(iStim)).latency;
			if any( kResp )
				nExtra(iRun) = nExtra(iRun) + sum( kResp );
% 				kResp(kResp) = Iresp(kResp) >= ( Istim(iStim) + dIRange(1) ) & Iresp(kResp) <= ( Istim(iStim) + dIRange(2) );
				kResp(kResp) = [ EEG(iRun).event(Iresp(kResp)).latency ] >= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(1) ) &...
				               [ EEG(iRun).event(Iresp(kResp)).latency ] <= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(2) );
			end
			if any( kResp )
				nExtra(iRun) = nExtra(iRun) - 1;
% 				respLat(iStim) = Iresp(find(kResp,1,'first')) - Istim(iStim);
				respLat(iStim) = EEG(iRun).event(Iresp(find(kResp,1,'first'))).latency - EEG(iRun).event(Istim(iStim)).latency;
			end

		kCorrect = false( 1, nStim );
		kCorrect(kStandard) =  isnan( respLat(kStandard) );
		kCorrect(kTarget)   = ~isnan( respLat(kTarget)   );
		kCorrect( kNovel)   =  isnan( respLat( kNovel)   );

		% Count standards preceding deviants
		% now that I'm saving standards in epochInfo, don't need this any more
% 		Nstandard = nan( 1, nStim );
% 		Ideviant  = Istim( kTarget | kNovel );
% 		nDeviant  = numel( Ideviant );
% 		iDeviant  = 1;
% 			iStim = Ideviant(iDeviant);
% 			Nstandard(iStim) = sum( strcmp( { EEG(iRun).event(                     1:Ideviant(iDeviant)-1).type }, standardCode ) );
% 		for iDeviant = 2:nDeviant
% 			iStim = Ideviant(iDeviant);
% 			Nstandard(iStim) = sum( strcmp( { EEG(iRun).event(Ideviant(iDeviant-1)+1:Ideviant(iDeviant)-1).type }, standardCode ) );
% 		end
% 		clear iStim

% 		epochInfo(iRun) = struct( 'latency', [ EEG(iRun).event(Istim).latency ],...
% 			'kStandard', kStandard, 'kTarget', kTarget, 'kNovel', kNovel, 'kCorrect', kCorrect,...
% 			'Nstandard', Nstandard, 'respLat', respLat );
		epochInfo(iRun) = struct( 'latency', [ EEG(iRun).event(Istim).latency ],...
			'kStandard', kStandard, 'kTarget', kTarget, 'kNovel', kNovel, 'kCorrect', kCorrect,...
			'respLat', respLat );

	end

% keyboard, return

	%% test ref channels on raw data for FASTER channel property outliers? mean corrcoef, var, hurst exponent
	% filter 1st? makes a big difference
	% what will we do when we get an outlier ref channel? e.g. TP10 in HA00018 20211021 AOD unfiltered
	% these channel property distributions can be highly non-normal, z-scoring perhaps not the best outlier detector?
	%{
			% use min_z()
			iRun      = 1;
			chanTest  = { 'TP9', 'TP10' };
			IchanTest = eeg_chaninds( EEG(iRun), chanTest );
			IchanInit = 1:nEEG-addRefChan;		% don't include all-zero ref channel
			nProp     = 3;
			nTest     = numel( IchanTest );
			nInit     = numel( IchanInit );
			chanPropInit = zeros( nInit, nProp, nRun );
			for iRun = 1:nRun
% 				chanPropInit(:,:,iRun) = channel_properties( EEG(iRun), IchanInit, [] );
				chanPropInit(:,:,iRun) = channel_properties( pop_basicfilter( EEG(iRun), Ieeg, 'RemoveDC', 'on', 'Design', 'butter', 'Filter', 'bandpass', 'Cutoff', passBand ), IchanInit, [] );
			end
			chanPropInit(:) = zscore( chanPropInit, 0, 1 );
			clf
			figure(gcf)
					subplot( 1+nProp, nRun, 1 )
					Zinit = zscore( [ Z{IchanInit,2} ], 0 );
					[ ~, Isort ] = sort( Zinit, 'ascend' );
					plot( Zinit(Isort), (1:nInit)/nInit, '.-' )
					for ii = 1:nTest
						yy = find( Isort == IchanTest(ii) ) / nInit;
						line( Zinit(IchanTest(ii)), yy, 'Marker', 'o', 'Color', 'r' )
						text( Zinit(IchanTest(ii)), yy, chanTest{ii}, 'Color', 'r', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top' )
					end
					line( repmat( [ -1, 1 ]*3, [ 2, 1 ] ), [ 0; 1 ], 'Color', 'c' )
% 					xlim( [ 0, ceil( max( Zinit ) ) ] )
					xlim( [ -1, 1 ] * ceil( max( abs( Zinit ) ) ) )
					grid
					ylabel( 'Impedance' )
			for iProp = 1:nProp
				for iRun = 1:nRun
					[ ~, Isort ] = sort( chanPropInit(:,iProp,iRun), 'ascend' );
% 					clf
					subplot( 1+nProp, nRun, nRun + sub2ind( [ nRun, nProp ], iRun, iProp ) )
					plot( chanPropInit(Isort,iProp,iRun), (1:nInit)/nInit, '.-' )
					for ii = 1:nTest
						yy = find( Isort == IchanTest(ii) ) / nInit;
						line( chanPropInit(IchanTest(ii),iProp,iRun), yy, 'Marker', 'o', 'Color', 'r' )
						text( chanPropInit(IchanTest(ii),iProp,iRun), yy, chanTest{ii}, 'Color', 'r', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top' )
					end
					line( repmat( [ -1, 1 ]*3, [ 2, 1 ] ), [ 0; 1 ], 'Color', 'c' )
% 					if min( chanPropInit(:,iProp,iRun) ) < 0
						xlim( [ -1, 1 ] * ceil( max( abs( chanPropInit(:,iProp,iRun) ) ) ) )
% 					else
% 						xlim( [ 0, ceil( max( chanPropInit(:,iProp,iRun) ) ) ] )
% 					end
					grid
					if iRun == 1
						ylabel( sprintf( 'property %d', iProp ) )
					end
					if iProp == nProp
						xlabel( sprintf( 'run %d', iRun ) )
					end
% 					title( sprintf( 'property %d, run %d', iProp, iRun ) )
% 					pause
				end
			end
			return
	%}
	%%
	
	
	
	[ EEG, chanProp, ccaStats, icaData ] = bieegl_FASTER( EEG, epochEventCodes, passBand, epochWin, baselineWin, icaWin,...
											    Ieeg, { 'TP9', 'TP10' }, InotEEG, [], Ieog,...
											    logFile, '' );
											
	fprintf( 'Finished analyzing %s %s. \n', subjTag(5:end), epochName )
	if writeFlag		% there's no reason to run bieegl_FASTER & not save anything other than debugging.  writeFlag=false already forces return above, so this if is moot
		fprintf( 'writing %s\n', matFile )
		save( matFile, 'EEG', 'epochInfo', 'chanProp', 'ccaStats', 'icaData', 'passBand', 'epochWin', 'baselineWin', 'icaWin', 'Ieog',...
		               'epochName', 'standardCode', 'targetCode', 'novelCode', 'logFile', 'RTrange', 'nExtra' )
	end
	fprintf( 'done\n' )




	return

%%
%{
		% e.g.
		% need to weed out incomplete sessions, findProcSessions not good enough for ERPs
		proc = AMPSCZ_EEG_findProcSessions;
		for iSession = [ 3, 9, 11 ]%1:size( proc, 1 )
			AMPSCZ_EEG_preproc( proc(iSession,2), proc(iSession,3), { 'MMN', 'VOD', 'AOD' }, [], false )
		end
%}
%%


%{

		% High-offset flag -----------------------------------------------------
		% BJR says this HighOffset check should only be needed for BioSemi system
		% 1st stimuli coming in around 5s, do we want to use pre-stim region here?
		% what are units here? same as in NAPLS? offsets are pretty high
				% BJR comments:
                % 2014 update:  Prior to re-referencing, check the offsets to
                % identify any channel(s) that may not have been plugged in
                % using the offset code developed for NAPLS QA.  And by that I
                % mean check to see if the max absolute value of the data in the
                % first few seconds is greater than 60k (did you know that the
                % offsets tab in actiView simply displays the raw voltage value
                % of the unreferenced data?)
				%
                % if high offset = 64 then check in longer time window (more
                % than 3 sec) for bad caps
				%
				% HighOffset = max( abs( EEG(iRun).data(eeg_chans,1024:3072)' ) ) > 60000;
%		highThresh  = 60000;
		highThresh  = nan;
		ItimeOffset = ceil( EEG(iRun).srate * 1 ):floor( EEG(iRun).srate * 3 );
		offset      = max( abs( EEG(iRun).data(Ieeg,ItimeOffset) ), [], 2 );
		HighOffset  = false( nEEG, 1 );
		if ~isnan( highThresh )
			HighOffset(:) = max( abs( EEG(iRun).data(Ieeg,ItimeOffset) ), [], 2 ) > highThresh;
		end
		IpropExclude = Ieeg(HighOffset);	

%}	


% 	clear ALLCOM ALLERP ALLERPCOM CURRENTERP CURRENTSTUDY ERP STUDY % PLUGINLIST



