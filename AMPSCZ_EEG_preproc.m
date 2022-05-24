function AMPSCZ_EEG_preproc( subjectID, sessionDate, epochName, passBand, writeFlag, IRun )
% Pre-process segmented AMP SCZ Brain Vision files for MMN, VOD, or AOD ERP analysis.
% Saves output in mat-file format
%
% Usage:
% >> AMPSCZ_EEG_preproc( subjectID, sessionDate, epochName, [passBand], [writeFlag], [IRun] )
%
% Where:
%   subjectID   = 7-character subject identifier, 2-char site code + 5-digit subject #
%   sessionDate = 8-character date 'YYYYMMDD'
%   epochName   = 'MMN', 'VOD', 'AOD', or 'ASSR'
%   passBand    = option input [ lowFreq, highFreq ] (Hz), default = [ 0.1, Inf ]
%   writeFlag   = how to handle mat-files that already exist, default = []
%                 true = overwrite, false = don't overwrite, [] = prompt if needed
%   IRun        = run number vector, only used for skipping bad runs
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

	narginchk( 3, 6 )
	
	% EEGLAB (pop_eegfiltnew.m) recommends HPF > 1, no LPF?
	% if doing bandpass, do it in 2 parts? to avoid low-pass having steeper slope than highpass? not relevant for ERPLAB pop_basicfilter.m
	% https://eeglab.org/tutorials/05_Preprocess/Filtering.html
	if exist( 'passBand', 'var' ) ~= 1 || isempty( passBand )
% 		passBand = [ 0.1, Inf ];
		passBand = [ 0.2, Inf ];
% 		passBand = [ 0.3, Inf ];
	end
	if exist( 'writeFlag', 'var' ) ~= 1
% 		writeFlag = false;
		writeFlag = [];
	elseif ~isempty( writeFlag ) && ~( islogical( writeFlag ) && isscalar( writeFlag ) )
		error( 'writeFlag must be empty or logical scalar' )
	end
	if exist( 'IRun', 'var' ) ~= 1
		IRun = [];
	end
	if iscell( epochName )
		if ~isempty( IRun )
			error( 'don''t use IRun input w/ cell epochName' )
		end
		% they get checked later, but might as well know about errors up front
		if ~all( cellfun( @ischar, epochName ) ) || ~all( ismember( epochName, { 'MMN', 'VOD', 'AOD', 'ASSR' } ) )
			error( 'Invalid epochName input' )
		end
		for iEpoch = 1:numel( epochName )
			AMPSCZ_EEG_preproc( subjectID, sessionDate, epochName{iEpoch}, passBand, writeFlag )%, IRun )
		end
		return
	end

	% Machine-dependent paths
	[ AMPSCZdir, eegLabDir, ~, adjustDir ] = AMPSCZ_EEG_paths;
	AMPSCZtools = fileparts( mfilename( 'fullpath' ) );
	locsFile    = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.elc' );		% does .elc or .ced make any difference?

	sessionList = AMPSCZ_EEG_findProcSessions;
	
% 	iSession = find( ismember( sessionList(:,2:3), { subjectID, sessionDate }, 'rows' ) );		% 'rows' doesn't work on cell arrays!
	iSession = find( strcmp( sessionList(:,2), subjectID ) & strcmp( sessionList(:,3), sessionDate ) );	
	if numel( iSession ) ~= 1
		error( 'Can''t identify session' )
	end

	taskList = { 'VODMMN', 5; 'AOD', 4; 'ASSR', 1 };

	% need to make this whole thing a function and loop epochNames if not sessions too
	if ~ischar( epochName ) || ~ismember( epochName, { 'MMN', 'VOD', 'AOD', 'ASSR' } )
		error( 'invalid epochName' )
	end
	iTask = contains( taskList(:,1), epochName );
	if sum( iTask ) ~= 1
		error( 'invalid epochName %s', epochName )
	end
	iTask = find( iTask );
	
	
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
		case 'ASSR'
			% 200 standard
			% Half a second of ~1 ms (44 samples @ 44100 Hz) pulses every ~25 ms (1102 audio samples).  ~40 Hz
			% repeated every 1101 (occasionally 1102) 1000 Hz EEG samples.
			
			% @ 250 Hz, [ -96, 1000 ] or [ -100, 996 ] ms yields 275 samples
			% & frequency resolution of 250/275 Hz
			% putting 40 Hz @ 45th point in spectrum
			
			% pick 250 samples for 1 Hz resolution?
			
% 			epochWin     = [ -0.100, 1.000 ];
% 			epochWin     = [ -0.096, 1.000 ];		% baseline starts from -0.100 leading to error
% 			epochWin     = [ -0.100, 0.996 ];
% 			epochWin     = [ -0.100, 0.900 ];		% 900 not included in output of pop_epoch, this gives 250 points
			epochWin     = [ -0.248, 0.752 ] + [ -1, 1 ]*1;		% center around on portion, [0,500]ms, pad to avoid NaNs in ft_freqanalysis
% 			icaWin       = epochWin;
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
		if ~AMPSCZ_EEG_matlabPaths
			restoredefaultpath
		end
	end	
	% -- EEGLAB + plugins
	if isempty( which( 'eeglab' ) )
		if ~AMPSCZ_EEG_matlabPaths
			error( 'Problem setting Matlab path.  Missing mat-file?' )
		end
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

% 	siteTag = sessionList{iSession,2}(1:2);
	subjTag = [ 'sub-',  sessionList{iSession,2} ];
	sessTag = [ 'ses-',  sessionList{iSession,3} ];
	taskTag = [ 'task-', taskList{iTask,1} ];

	filterFcn = 'pop_eegfiltnew';
	refType   = 'robustinterp';
	
	zThreshInterp = [ 3.5, 10, 3.5 ];		% [ correlation, variance, hurst exponent ]
% 	zThreshInterp = [ norminv( (1+0.999)/2 ), 8, 3.5 ];		% [ correlation, variance, hurst exponent ], 3.2905, unused w/ 'robustinterp'
	compMethod    = 'ICLABEL';
	Iocular       = [];				% faster ica cleaning only

	sessDir = fullfile( AMPSCZ_EEG_procSessionDir( sessionList{iSession,2}, sessionList{iSession,3}, sessionList{iSession,1}(1:end-2) ) );
	bvDir   = fullfile( sessDir, 'BIDS' );
	matDir  = fullfile( sessDir, 'mat'  );
	if ~isfolder( matDir )
		mkdir( matDir )		% you can run mkdir all at once, don't need to do it one layer at a time
	end
	outName = sprintf( '%s_%s_%s_[%g,%g]', subjTag(5:end), sessTag(5:end), epochName, passBand(1), passBand(2) );
	logFile  = fullfile( matDir, [ outName, '.log' ] );
	matFile  = fullfile( matDir, [ outName, '.mat' ] );
	writeMat = exist( matFile, 'file' ) ~= 2;
	if isempty( writeFlag )
		if ~writeMat
			writeMat(:) = strcmp( questdlg( [ 'Replace ', outName, '.mat?' ], 'mat-file', 'No', 'Yes', 'No' ), 'Yes' );
			if ~writeMat
				return
			end
		end
	elseif writeFlag
		if ~writeMat
			warning( '%s will be overwritten', matFile )		% logFile too
			writeMat = true;
		end
	elseif ~writeMat
		fprintf( '%s exists\n', matFile )
% 		writeMat(:) = false;
		return
	end

	if isempty( IRun )
		nRun = taskList{iTask,2};
		IRun = 1:nRun;
	else
		nRun = numel( IRun );
	end

	EEG       = repmat( eeg_checkset( eeg_emptyset ), [ 1, nRun ] );
% 	epochInfo = struct( 'latency', cell( 1, nRun ), 'kStandard', [], 'kTarget', [], 'kNovel', [], 'kCorrect', [], 'Nstandard', [], 'respLat', [] );		% latency is event latency, respLat is response latency
	epochInfo = struct( 'latency', cell( 1, nRun ), 'kStandard', [], 'kTarget', [], 'kNovel', [], 'kCorrect', [], 'respLat', [] );		% latency is event latency, respLat is response latency
	nExtra    = zeros( 1, nRun );
	for iRun = 1:nRun

		% Load BrainVision data ------------------------------------------------
		% pop_loadbv requires bva-io
		% note:	EEG(iRun).ref = 'common';
		%       EEG(iRun).chaninfo.nosedir = '+X'
		runTag = sprintf( 'run-%02d', IRun(iRun) );
		bvFile = sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, taskTag, runTag );
		EEG(iRun) = pop_loadbv( bvDir, bvFile );
		
		% Check for lost samples
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

		% Drop photosensor channel
		if ismember( 'VIS', { EEG(iRun).chanlocs.labels } )
			EEG(iRun) = pop_select( EEG(iRun), 'nochannel', { 'VIS' } );
		end
	
		% handle AOD stimulus bug, replace any repsonse code 17s w/ 5s ---------
		% get rid of this at some point.  new stim boxes won't produce this error
		if strcmp( taskList{iTask,1}, 'AOD' )
			k17 = strcmp( { EEG(iRun).event.type }, 'S 17' );
			if any( k17 )
				[ EEG(iRun).event(k17).type ] = deal( 'S  5' );
			end
			clear k17
		end
		
		% set EEG.ref field ----------------------------------------------------
		% and add all-zero reference channel FCz
% 		refChanName = 'FCz';
		hdr  = bieegl_readBVtxt( fullfile( bvDir, bvFile ) );
		kRef = ~cellfun( @isempty, regexp( hdr.Comment, '^Reference Channel Name = .+$', 'once', 'start' ) );
		if sum( kRef ) ~= 1
			error( 'can''t identify ref channel name from .vhdr' )
		end
		refChanName = regexp( hdr.Comment{kRef}, '^Reference Channel Name = (.+)$', 'once', 'tokens' );
		refChanName = refChanName{1};
		clear hdr kRef
		% put reference channel name from .vhdr file in EEG.ref
		% i'm pretty sure this isn't important at all
		% it loads as 'common'
		EEG(iRun).ref = refChanName;
		if ~ismember( refChanName, { EEG(iRun).chanlocs.labels } )
			% add in reference channel full of zeros
			EEG(iRun).nbchan(:) = EEG(iRun).nbchan + 1;
			EEG(iRun).data(EEG(iRun).nbchan,:) = 0;
			EEG(iRun).chanlocs(EEG(iRun).nbchan).labels = refChanName;
			% convert [] to ''
			EEG(iRun).chanlocs(EEG(iRun).nbchan).ref  = '';		% this is not EEG.ref!  they're all empty
			EEG(iRun).chanlocs(EEG(iRun).nbchan).type = '';	%' EEG';		% they're not 'EEG' type anymore
		end

		% Get channel locations ------------------------------------------------
		EEG(iRun) = pop_chanedit( EEG(iRun), 'lookup', locsFile );
		
		if iRun ~= 1
			if EEG(iRun).nbchan ~= EEG(1).nbchan || ~all( strcmp( { EEG(iRun).chanlocs.labels }, { EEG(1).chanlocs.labels } ) )
				error( 'inconsistent channels across runs' )
			end
		end
		% DONE messing with EEG structure, now extract behavioral data
		
		
		% Can I make use of this in place of code below
		% [ pVOD, pAOD ] = AMPSCZ_EEG_performance( subjectID, sessionDate, VODMMNruns, AODruns )
		% pVOD, pAOD: 1st column is code for stimulus type, 0=standard, 1=target, 2=novel
		%             2nd column in reaction time (s), NaN if no response
		% epochInfo(iRun) = struct( 'latency', [ EEG(iRun).event(Istim).latency ],...
		% 	'kStandard', pVOD(:,1)'==1, 'kTarget', pVOD(:,1)'==2, 'kNovel', pVOD(:,1)'==2, 'kCorrect', kCorrect,...
		% 	'respLat', pVOD(:,2)' );
		
		% Stimulus indices & type sequence -------------------------------------
		Istim     = find( ismember( { EEG(iRun).event.type }, epochEventCodes ) );
			% get rid of stimuli that are too close to bounds to epoch
			Istim( [ EEG(iRun).event(Istim).latency ] <                  -epochWin(1) * EEG(iRun).srate ) = [];
			Istim( [ EEG(iRun).event(Istim).latency ] >  EEG(iRun).pnts - epochWin(2) * EEG(iRun).srate ) = [];

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
		if isempty( respCode )			% ASSR, RestEO, RestEC
			Iresp = [];
		else
			Iresp = find( strcmp( { EEG(iRun).event.type }, respCode ) );
		end
		
		if ~isempty( Iresp )

			% store extra button presses? logic could be simplified if not tracking this
			nExtra(iRun)  = sum( Iresp <= Istim(1) );
			for iStim = 1:nStim-1
				% button presses between current stimulus (standard/target/novel) and next one
				% button and stim trigger can't be simultaneous can they?
%				kResp = Iresp > Istim(iStim) & Iresp <= Istim(iStim+1);		% this is almost certainly fine here, but not when adding dIRange below
				kResp = [ EEG(iRun).event(Iresp).latency ] > EEG(iRun).event(Istim(iStim)).latency & [ EEG(iRun).event(Iresp).latency ] <= EEG(iRun).event(Istim(iStim+1)).latency;
				if any( kResp )
					% start by adding all responses in an inter-stimulus interval
					nExtra(iRun) = nExtra(iRun) + sum( kResp );
					% then check if any reaction times are in bounds
%					kResp(kResp) = Iresp(kResp) >= ( Istim(iStim) + dIRange(1) ) & Iresp(kResp) <= ( Istim(iStim) + dIRange(2) );
					kResp(kResp) = [ EEG(iRun).event(Iresp(kResp)).latency ] >= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(1) ) &...
					               [ EEG(iRun).event(Iresp(kResp)).latency ] <= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(2) );
				end
				if any( kResp )
					% the good response wasn't extra, subtract it
					nExtra(:) = nExtra(iRun) - 1;
					% take the 1st of multiple viable button presses
%					respLat(iStim) = Iresp(find(kResp,1,'first')) - Istim(iStim);
					respLat(iStim) = EEG(iRun).event(Iresp(find(kResp,1,'first'))).latency - EEG(iRun).event(Istim(iStim)).latency;
				end
			end
			iStim = nStim;
				% button presses after final stimulus
%				kResp = Iresp > Istim(iStim);
				kResp = [ EEG(iRun).event(Iresp).latency ] > EEG(iRun).event(Istim(iStim)).latency;
				if any( kResp )
					nExtra(iRun) = nExtra(iRun) + sum( kResp );
%					kResp(kResp) = Iresp(kResp) >= ( Istim(iStim) + dIRange(1) ) & Iresp(kResp) <= ( Istim(iStim) + dIRange(2) );
					kResp(kResp) = [ EEG(iRun).event(Iresp(kResp)).latency ] >= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(1) ) &...
						           [ EEG(iRun).event(Iresp(kResp)).latency ] <= ( EEG(iRun).event(Istim(iStim)).latency + dIRange(2) );
				end
				if any( kResp )
					nExtra(iRun) = nExtra(iRun) - 1;
%					respLat(iStim) = Iresp(find(kResp,1,'first')) - Istim(iStim);
					respLat(iStim) = EEG(iRun).event(Iresp(find(kResp,1,'first'))).latency - EEG(iRun).event(Istim(iStim)).latency;
				end

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

% 	iRun = 1;
	% this will be all channels now that 'VIS' is remmoved
%	Ieeg            = find( strcmp( { EEG(iRun).chanlocs.type }, 'EEG' ) );			% type came from custom locs file
	Ieeg            = find( ~ismember( { EEG(iRun).chanlocs.labels }, 'VIS' ) );	% now type is ''
	Ifilter         = Ieeg;
	[ ~, Ifrontal ] = ismember( { 'Fp1', 'Fp2' } , { EEG(iRun).chanlocs.labels } );		%  1, 33
	[ ~, Imastoid ] = ismember( { 'TP9', 'TP10' }, { EEG(iRun).chanlocs.labels } );		% 23, 50
	IcomputeRef     = setdiff( Ieeg, union( Imastoid, Ifrontal ) );
	IremoveRef      = Ieeg;
	IcomputeInterp  = Ieeg;
	IexcludeInterp  = [];

	% Ensure EEG channels are first
	% some EEGLAB FASTER plugin functions may choke if not?
	if ~all( Ieeg == 1:numel( Ieeg ) )
		error( 'Re-ordering channels w/ EEG first\n' )
	end
	
	if isempty( writeFlag )
		replaceLog = false;		% append
	else
		replaceLog = writeFlag;
	end
	[ EEG, chanProp, ccaStats, icaData ] = bieegl_FASTER( EEG, epochEventCodes, epochWin, baselineWin, icaWin,...
											    Ieeg, filterFcn, passBand, Ifilter, refType, IcomputeRef, IremoveRef, IcomputeInterp, IexcludeInterp, zThreshInterp, compMethod, Iocular,...
											    logFile, '', replaceLog );

	fprintf( 'Finished analyzing %s %s. \n', subjTag(5:end), epochName )
	if writeMat		% there's no reason to run bieegl_FASTER & not save anything other than debugging.  writeMat=false already forces return above, so this if is moot
		fprintf( 'writing %s\n', matFile )
		save( matFile, 'EEG', 'epochName', 'epochInfo', 'chanProp', 'ccaStats', 'icaData', 'epochWin', 'baselineWin', 'icaWin',...
			'filterFcn', 'passBand', 'Ifilter', 'refType', 'IcomputeRef', 'IremoveRef', 'IcomputeInterp', 'IexcludeInterp', 'zThreshInterp', 'compMethod', 'Iocular',...
			'standardCode', 'targetCode', 'novelCode', 'logFile', 'RTrange', 'nExtra' )
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



