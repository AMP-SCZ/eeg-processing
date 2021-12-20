function AMPSCZ_EEG_QA( sessionName, writeFlag )
% Usage:
% >> AMPSCZ_EEG_QA( [sessionName], [writeFlag] )
%
% Optional Inputs:
% sessionName = 16-character [ subjId, '_', date ] vector, e.g. 'BI00001_20220101'
%               or cell array of char
%               or empty to choose with dialog
%               default = []
% writeFlag   = flag for writing out png file
%               logical scalar true = force write, false = don't write
%               or empty to write if it doesn't exist, and prompt if it does
%               default = []
%
% Written by: Spero Nicholas, NCIRE

% to do:
% add some verbosity flag for warnings?
% re-ref by epoch in preprocessing

% is there a prayer of running this on Xanadu? - i don't want to dumb it down if eventually going to BWH
% no narginchk in R2009b


% 	no header comments HK00002_20211021 sub-HK00002_ses-20211021_task-AOD_run-01_eeg.vhdr				empty Z
% 	no header files PA00000_20211007																	error
% 	no impedance section PA00000_20211014 sub-PA00000_ses-20211014_task-AOD_run-01_eeg.vhdr				empty Z
% 	no impedance section SL00005_20211118 sub-SL00005_ses-20211118_task-AOD_run-01_eeg.vhdr				empty Z
% 	multiple impedance sections PA00000_20211026 sub-PA00000_ses-20211026_task-AOD_run-01_eeg.vhdr
% 	multiple impedance sections WU00013_20211111 sub-WU00013_ses-20211111_task-AOD_run-01_eeg.vhdr


% make sure hann is Matlab function not Fieldtrip!

% error( 'Under Construction' )		% fix paths for PHOENIX

	narginchk( 0, 2 )

	if isunix
		AMPSCZdir = '/data/predict/kcho/flow_test';					% don't work here, outputs will get deleted.  aws rsync to NDA s2
		AMPSCZdir = '/data/predict/kcho/flow_test/spero';			% kevin got rid of group folder & only gave me pronet?	
		eegLabDir = '/PHShome/sn1005/Downloads/eeglab/eeglab2021.1';
	else %if ispc
		AMPSCZdir = 'C:\Users\donqu\Documents\NCIRE\AMPSCZ';
		eegLabDir = 'C:\Users\donqu\Downloads\eeglab\eeglab2021.1';
	end

	if exist( 'writeFlag', 'var' ) == 1
		if ~isempty( writeFlag ) && ( ~isscalar( writeFlag ) || ~islogical( writeFlag ) )
			error( 'Invalid writeFlag input' )
		end
	else
		writeFlag = [];
	end
	if exist( 'sessionName', 'var' ) == 1 && ~isempty( sessionName )
		if iscell( sessionName )
			noPng = ~isempty( writeFlag ) && ~writeFlag;
			nSession = numel( sessionName );
			if noPng && nSession > 1
				warning( 'You''re running multiple sessions and not saving anything' )	% current figure get cleared & replaced, not accumulating figure windows
			end
			for iSession = 1:nSession
				try
					AMPSCZ_EEG_QA( sessionName{iSession}, writeFlag )
				catch ME
					fprintf( '\n\n%s\n%s\n%s\n\n', repmat( '*', [ 1, 80 ] ), ME.message, repmat( '*', [ 1, 80 ] ) )
					continue
				end
				if noPng && iSession < nSession
					pause
				end
			end
			return
		elseif ~ischar( sessionName ) || isempty( regexp( sessionName, '^[A-Z]{2}\d{5}_\d{8}$', 'start', 'once' ) )
			error( 'Invalid sessionName input' )
		end
		sessionList = ProNET_availableSessions( AMPSCZdir );
		iSession = strcmp( strcat( sessionList(:,1), '_', sessionList(:,2) ), sessionName );
		if ~any( iSession )
			error( 'Session %s not available', sessionName )
		end
% 		iSession = find( iSession, 1, 'first' );		% there can't be duplicates in sessionList!
	else
		[ sessionList, iSession ] = ProNET_availableSessions( AMPSCZdir, 'multiple' );
		if isempty( iSession )
			return
		end
		noPng = ~isempty( writeFlag ) && ~writeFlag;
		nSession = numel( iSession );
		if noPng && nSession > 1
			warning( 'You''re running multiple sessions and not saving anything' )	% current figure get cleared & replaced, not accumulating figure windows
		end
		for iMulti = 1:nSession
			try
				AMPSCZ_EEG_QA( sprintf( '%s_%s', sessionList{iSession(iMulti),:} ), writeFlag )
			catch ME
% 				disp( ME )
% 				for ii = numel( ME.stack ):-1:1
% 					disp( ME.stack(ii) )
% 				end
				fprintf( '\n\n%s\n%s\n%s\n\n', repmat( '*', [ 1, 80 ] ), ME.message, repmat( '*', [ 1, 80 ] ) )
				continue
			end
			if noPng && iMulti < nSession
				pause
% 				drawnow
			end
		end
		return
	end

	AMPSCZtools = fileparts( mfilename( 'fullpath' ) );
	locsFile    = fullfile( AMPSCZtools, 'ProNET_actiCHamp65ref.ced' );
	
	% minimum & maximum reaction times (s), button presses out of this range not counted as responses
	RTrange = AMPSCZ_EEG_RTrange;
	
	hannPath = which( 'hann.m' );		% There's a hann.m in fieldrip, that's pretty useless, it just calls hanning.m
	if ~contains( hannPath, matlabroot )
		error( 'fix path so hann.m is native MATLAB' )
	end
	
	if isempty( which( 'eeglab.m' ) )
		addpath( eegLabDir, '-begin' )
		eeglab
		drawnow
		close( gcf )
	end
	if ~contains( which( 'topoplot.m' ), 'modifications' )
		addpath( fullfile( AMPSCZtools, 'modifications', 'eeglab' ), '-begin' )
	end

% 	nSession = size( sessionList, 1 );
% 	for iSession = 1:nSession
% % 		fprintf( '\t\t''%s'', ''%s''\n', sessionList{iSession,:} )
% 		vhdr = dir( fullfile( AMPSCZdir, sessionList{iSession,1}(1:2), 'BIDS', [ 'sub-', sessionList{iSession,1} ], [ 'ses-', sessionList{iSession,2} ], 'eeg', '*.vhdr' ) );
% 		if isempty( vhdr )
% 			fprintf( '\tno header files %s_%s\n', sessionList{iSession,:} )
% 		else
% 			for i = 1:numel( vhdr )
% % 				hdr = bieegl_readBVtxt( fullfile( vhdr(i).folder, vhdr(i).name ) );
% 				mrk = bieegl_readBVtxt( fullfile( vhdr(i).folder, [ vhdr(i).name(1:end-3), 'mrk' ] ) );
% 				switch 2
% 					case 1
% 						if isempty( hdr.Comment )
% 							fprintf( '\tno header comments %s_%s %s\n', sessionList{iSession,:}, vhdr(i).name )
% 						else
% 							iImp = find( ~cellfun( @isempty, regexp( hdr.Comment, '^Impedance \[kOhm\] at \d{2}:\d{2|:\d{2} :$', 'once', 'start' ) ) );
% 							switch numel( iImp )
% 								case 0
% 									fprintf( '\tno impedance section %s_%s %s\n', sessionList{iSession,:}, vhdr(i).name )
% 								case 1
% 									disp( hdr.Comment(iImp:end) )
% 								otherwise
% 									fprintf( '\tmultiple impedance sections %s_%s %s\n', sessionList{iSession,:}, vhdr(i).name )
% 							end
% 						end
% 					case 2
% 						kLostSamples = strncmp( { mrk.Marker.Mk.description }, 'LostSamples:', 12 );
% 						if any( kLostSamples )
% 							nLost = regexp( { mrk.Marker.Mk(kLostSamples).description }, '^LostSamples: (\d+)$', 'tokens', 'once' );
% 							nLost = str2double( [ nLost{:} ] );
% 							fprintf( '\tlost %d epochs, %d samples in %s_%s %s\n', numel( nLost ), sum( nLost ), sessionList{iSession,:}, vhdr(i).name )
% 						end
% 				end
% 			end
% 		end
% 	end
% 	return
	
	siteInfo = AMPSCZ_EEG_siteInfo;
	[ taskInfo, taskSeq ] = AMPSCZ_EEG_taskSeq;
	nTask = size( taskInfo, 1 );		% i.e. 5
	nSeq  = numel( taskSeq );
	cTask = [
		0   , 0.75, 0.75
		1   , 0.75, 0
		0   , 0.75, 0
		0.75, 0.75, 0
		0.75, 0.75, 0.75
	];

	% Replace some names w/ Standard to get event counts in a meaningful column
	for iTask = find( ismember( taskInfo(:,1), { 'ASSR', 'RestEO', 'RestEC' } ) )'
		[ taskInfo{iTask,2}{:,2} ] = deal( 'Standard' );
	end

% 	siteTag = sessionList{iSession,1}(1:2);
% 	subjTag = [ 'sub-',  sessionList{iSession,1} ];
% 	sessTag = [ 'ses-',  sessionList{iSession,2} ];
	subjId   = sessionName(1:7);
	sessDate = sessionName(9:16);
	siteTag  = sessionName(1:2);
	subjTag  = [ 'sub-', subjId   ];
	sessTag  = [ 'ses-', sessDate ];
	bvDir    = fullfile( AMPSCZdir, siteTag, 'BIDS', subjTag, sessTag, 'eeg' );

	iSite = find( strcmp( siteInfo(:,1), siteTag ) );
	if numel( iSite ) ~= 1
		error( 'site identification error' )
	end
	
	% e.g. pop_chanedit( struct( 'labels', Z(:,1) ) )...
	chanLocs = readlocs( locsFile );

	% impedance will be the same for all runs & all tasks, since it is replicated when segmented
	% the exception will be if there are multiple zip files, it may only be in the 1st
% 	iTask = 1;
% 	iRep  = 1;
% 	bvFile = sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, sprintf( 'task-%s', taskInfo{iTask,1} ), sprintf( 'run-%02d', iRep ) );
	bvFile = dir( fullfile( bvDir, [ subjTag, '_', sessTag, '_task-*', '_run-*_eeg.vhdr' ] ) );
	if isempty( bvFile )
		error( 'no .vhdr files in %s', bvDir )
	end
	bvFile = bvFile(1).name;
	H      = bieegl_readBVtxt( fullfile( bvDir, bvFile ) );
	if isempty( H.Comment )
		Z      = cell( 0, 2 );		%[ { chanLocs(1:63).labels }', num2cell( nan(63,1) ) ];
		zRange = [];
		kZ     = [];
		zMsg   = 'No Header Comments';
		iZ     = 1;
		nZ     = 0;
	else
		Z = AMPSCZ_EEG_readBVimpedance( H );		% 65x2x# { name, impedance }
		if isempty( Z )
			Z    = cell( 0, 2 );		%[ { chanLocs(1:63).labels }', num2cell( nan(63,1) ) ];
			kZ   = [];
			zMsg = 'No Impedance Runs';
			iZ   = 1;
			nZ   = 0;
		else
			nZ = size( Z, 3 );
% 			iZ = 1;
			iZ = nZ;
			[ kZ, ILocs ] = ismember( Z(:,1,iZ), { chanLocs.labels } );
% 			Zdata = cell2mat( squeeze( Z(kZ,2,:) ) );
			Zdata = cell2mat( squeeze( Z(:,2,:)  ) );		% include Ground too
			if all( isnan( Zdata(kZ,iZ) ) )
				zMsg = 'Not Connected';
			end
		end
		zRange = regexp( H.Comment, '^Data/Gnd Electrodes Selected Impedance Measurement Range: (\S+) - (\S+) kOhm$', 'tokens', 'once' );
		zRange = zRange( ~cellfun( @isempty, zRange ) );
		switch numel( zRange )
			case 0
				zRange = [];
			case 1
% 				zRange = cellfun( @str2double, zRange{1}, 'UniformOutput', true );
				zRange = str2double( zRange{1} );		% str2double handles this, don't need cellfun
				iZr    = 1;
			otherwise
				if size( zRange, 1 ) == nZ
					iZr = iZ;
				else
					warning( 'impedance range vs data size mismatch' )		% is this possible?
% 					iZr = 1;
					iZr = size( zRange, 1 );
				end
				zRange = str2double( cat( 1, zRange{:} ) );
		end
	end

	
	% Task sequence and cumulative run #s
	% first check what's actually there
	vmrkFiles = dir( fullfile( bvDir, '*.vmrk' ) );
	nSeqFound = numel( vmrkFiles );
	dateint   = nan( 1, nSeqFound );
	for iSeq = 1:nSeqFound
		M = bieegl_readBVtxt( fullfile( bvDir, vmrkFiles(iSeq).name ) );
		dateint(iSeq) = eval( M.Marker.Mk(1).date );
	end
	[ ~, Isort ] = sort( dateint, 'ascend' );
	vmrkFiles(:) = vmrkFiles(Isort);
	nRunFound    = regexp( { vmrkFiles.name }, '^sub-[A-Z]{2}\d{5}_ses-\d{8}_task-[A-Za-z\d]+_run-(\d{2})_eeg.vmrk$', 'tokens' );
	taskSeqFound = regexp( { vmrkFiles.name }, '^sub-[A-Z]{2}\d{5}_ses-\d{8}_task-([A-Za-z\d]+)_run-\d{2}_eeg.vmrk$', 'tokens' );
	nRunFound    = cellfun( @(u)str2double(u{1}{:}), nRunFound );
	taskSeqFound = cellfun( @(u)u{1}{:}, taskSeqFound, 'UniformOutput', false );
	[ ~, taskSeqFound ] = ismember( taskSeqFound, taskInfo(:,1) );
	clear vmrkFiles dateint M Isort
% 	if nSeqFound ~= nSeq || ~all( taskSeqFound == taskSeq )
% 		error( 'unexpected task sequence' )		% don't throw error, put in report!
% 	end

	% now assume hardwired task sequence
	nRun    = zeros( 1, nSeq );
	for iTask = 1:nTask
		kSeq = taskSeq == iTask;
		nRun(kSeq) = 1:sum(kSeq);
	end
	
	kInvalidRun = ~ismember( [ taskSeqFound(:), nRunFound(:) ], [ taskSeq(:), nRun(:) ] , 'rows' );

	fileExist = false( 1, nSeq );
% 	codeFound =  cell( 1, nSeq );
	fLine = siteInfo{iSite,4};
	wf    = 0.25;					% half width of freqency bands around line frequency harmonics
	pLine = nan( 63, nSeq );
	errTol = 2;						% error tolerance for hits, FA (yellow color)
% 	QAvars   = { 'Run', 'Standard', 'Target', 'Novel', 'Tone1', 'Tone2', 'VIS', 'Hit', 'FA', 'Extra', 'Misc' };
% 	QAvars   = { 'Run', taskInfo{1,2}{[ 1:3, 5:6 ],2}, 'VIS', 'TrgHit', 'NovelFA', 'OtherFA', 'Misc' };
	QAvars   = { 'Run', taskInfo{1,2}{[ 1:3, 5:6 ],2}, 'VIS', 'TrgHit', 'NovelFA', 'StndFA', 'Misc' };
	nVar     = numel( QAvars );
	kVar     = false(    1, nVar );
	QAtable  =  cell( nSeq, nVar );
	QAstatus = zeros( nSeq, nVar ); 

	goodColor = '\color[rgb]{0,0.75,0}';
	okColor   = '\color[rgb]{0.75,0.75,0}';
	badColor  = '\color{red}';
	respData  = [];
	for iSeq = 1:nSeq

		taskName = taskInfo{taskSeq(iSeq),1};
		codeInfo = taskInfo{taskSeq(iSeq),2};

		kVar(:) = strcmp( QAvars, 'Run' );
		[ ~, iRunOrder ] = ismember( [ taskSeq(iSeq), nRun(iSeq) ], [ taskSeqFound(:), nRunFound(:) ], 'rows' );
		QAtable{iSeq,kVar}  = sprintf( '(%02d) %s-%02d', iRunOrder, taskName, nRun(iSeq) );

		bvFile = fullfile( bvDir, sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, sprintf( 'task-%s', taskName ), sprintf( 'run-%02d', nRun(iSeq) ) ) );
		fileExist(iSeq) = exist( bvFile, 'file' ) == 2;
		if ~fileExist(iSeq)
			warning( '%s missing', bvFile )
			continue
		end
		if iRunOrder == iSeq
			QAstatus(iSeq,kVar) = 2;
		else
			QAstatus(iSeq,kVar) = 1;
		end

		H      = bieegl_readBVtxt( bvFile );
		fs     = 1 / ( H.Common.SamplingInterval * 1e-6 );					% sampling interval is in microseconds, get sampling rate in Hz
		M      = bieegl_readBVtxt( [ bvFile(1:end-3), 'mrk' ] );

		kLostSamples = strncmp( { M.Marker.Mk.description }, 'LostSamples:', 12 );
		kVar(:) = strcmp( QAvars, 'Misc' );
		if any( kLostSamples )
			nSampleLost = regexp( { M.Marker.Mk(kLostSamples).description }, '^LostSamples: (\d+)$', 'tokens', 'once' );
			nSampleLost = str2double( [ nSampleLost{:} ] );
			QAtable{iSeq,kVar} = sprintf( 'Lost %d epochs, %d samples', numel( nSampleLost ), sum( nSampleLost ) );
		else
			QAstatus(iSeq,kVar) = 2;
		end

		
		% check that # non-response event codes found matches expected value
		% ??? build this check into unzip program ??? or keep in QA
% 		Istim = find( ~cellfun( @isempty, codeInfo(:,3) ) );
		Istim = find( ~cellfun( @(u)strcmp(u,'Response'), codeInfo(:,2) ) );
% 		nStim = numel( Istim );
% 		codeFound{iSeq} = [ codeInfo(Istim,:), cell( nStim, 1 ) ];
		for iCode = Istim(:)'
			nExpected = codeInfo{iCode,3};
			nFound    = sum( strcmp( { M.Marker.Mk.description }, sprintf( 'S%3d', codeInfo{iCode,1} ) ) );
			kVar(:) = strcmp( QAvars, codeInfo{iCode,2} );
			QAtable{iSeq,kVar} = sprintf( '%d/%d', nFound, nExpected );
			if nFound == nExpected
				QAstatus(iSeq,kVar) = 2;
			else
				warning( '%s experiment, %s events: %d expected %d found', taskName, codeInfo{iCode,2}, nExpected, nFound )
% 				continue
			end
		end

		eeg    = bieegl_readBVdata( bieegl_readBVtxt( bvFile ), bvDir );
		kStim  = strcmp( { M.Marker.Mk.type }, 'Stimulus' );
		i1     = M.Marker.Mk(find(kStim,1,'first')).position;
		i2     = M.Marker.Mk(find(kStim,1,'last' )).position;
		i2(:)  = i2 + ceil( 2 * fs );
		i2(:)  = min( i2, size( eeg, 2 ) );
		eeg    = eeg(:,i1:i2);
		nfft   = size( eeg, 2 );
		
% 		Iblink = find( ismember( { chanLocs(1:64).labels }, { 'Fp1', 'Fp2', 'AFz' } ) );		% channel(s) to use for blink detection
% 		yBlink = mean( eeg(Iblink,:), 1 );
		
		% Check for photosensor pulses - just counting them
		% check for lack of photosensor signal in other tasks?
		if strcmp( taskName, 'VODMMN' )
			% pulse duration = 31-32 60Hz refreshes
			% there should be 160 of them
			% interval is ~normally distributed w/ 2000ms mean & 300/2.3 std
			nEnd      = 10;
			nGap      = 40;
			vis       = double( sort( eeg(64,:), 2, 'ascend' ) );		% eeg is single
			visLo     = vis( round( 0.7 * nfft ) );
			visHi     = vis( round( 0.8 * nfft ) );
				% if nRun(iSeq)==1, figure, plot( vis(1:100:end) ), title( [ visLo, visHi ] ), pause, close( gcf ), end
			if visHi - visLo > 200000
				vis(:)    = ( eeg(64,:) > ( ( visLo + visHi ) / 2 ) ) * 2 - 1;
				visOn     = filter( [ ones(1,nEnd), zeros(1,nGap), -ones(1,nEnd) ], 1, vis ) == 2*nEnd;
				visOn(:)  = [ false, visOn(2:nfft) & ~visOn(1:nfft-1) ];
				visOn     = find( visOn ) - nEnd;
%				visOff    = filter( [ -ones(1,nEnd), zeros(1,nGap), ones(1,nEnd) ], 1, vis ) == 2*nEnd;
%				visOff(:) = [ false, visOff(2:nfft) & ~visOff(1:nfft-1) ];
%				visOff    = find( visOff ) - nEnd;

%				visOn(:)  = visOn + ( i1 - 1 );			% these end up 20-21 samples after event markers
%				mrkOn     = [ M.Marker.Mk(ismember({M.Marker.Mk.description},{'S 32','S 64','S128'})).position ];
				nVis = numel( visOn );
			else
				nVis = 0;
			end
			nMrk = sum( ismember( { M.Marker.Mk.description }, { 'S 32', 'S 64', 'S128' } ) );
			kVar(:) = strcmp( QAvars, 'VIS' );
			QAtable{iSeq,kVar} = sprintf( '%d/%d', nVis, nMrk );
			if nVis == nMrk
				QAstatus(iSeq,kVar) = 1 + ( nMrk == 160 );
			else
				% write out message instead of error
				warning( 'expecting %d photosensor onsets, found %d', nMrk, nVis )
			end
		end
		
		if ismember( taskName, { 'VODMMN', 'AOD' } )
			% convert descriptions to numeric codes for easier comparison w/ taskInfo
			kStim = strcmp( { M.Marker.Mk.type }, 'Stimulus' );
			markerCode = zeros( size( kStim ) );
			markerCode(kStim) = cellfun( @(u)str2double(u(2:end)), { M.Marker.Mk(kStim).description } );
			Istnd = find(           markerCode == codeInfo{strcmp( codeInfo(:,2), 'Standard' ),1}   );
			Itarg = find(           markerCode == codeInfo{strcmp( codeInfo(:,2), 'Target'   ),1}   );
			Inovl = find(           markerCode == codeInfo{strcmp( codeInfo(:,2), 'Novel'    ),1}   );
			Iresp = find( ismember( markerCode,   codeInfo{strcmp( codeInfo(:,2), 'Response' ),1} ) );		% 2 possible response codes for AOD
			Istnd(:) = [ M.Marker.Mk(Istnd).position ];		% there shouldn't be any way these can be unsorted
			Itarg(:) = [ M.Marker.Mk(Itarg).position ];
			Inovl(:) = [ M.Marker.Mk(Inovl).position ];
			Iresp(:) = [ M.Marker.Mk(Iresp).position ];
% 			Istim    = union( Itarg, Inovl, 'sorted' );
			Istim    = sort( [ Istnd, Itarg, Inovl ] );
			nStim    = numel( Istim );
			% stimResp
			% 1st column: 0=standard, 1=target, 2=novel
			% 2nd column: latency (samples), 0 = no response
			% 3rd column: 1=VODMMN, 2=AOD
			stimResp = zeros( nStim, 3 );
			stimResp( ismember( Istim, Itarg ), 1 ) = 1;
			stimResp( ismember( Istim, Inovl ), 1 ) = 2;
			switch taskName
				case 'VODMMN'
					stimResp(:,3) = 1;
				case 'AOD'
					stimResp(:,3) = 2;
			end
			nExtra   = sum( Iresp <= Istim(1) );
			dImin = RTrange(1) * fs;
			dImax = RTrange(2) * fs;
			for iStim = 1:nStim-1
				% button presses between current target or novel and next one, button and stim trigger can't be simultaneous can they?
				kResp = Iresp > Istim(iStim) & Iresp <= Istim(iStim+1);
				if any( kResp )
					nExtra(:) = nExtra + sum( kResp );
					% plausible reaction times (physiological at the low end)
					kResp(kResp) = Iresp(kResp) >= ( Istim(iStim) + dImin ) & Iresp(kResp) <= ( Istim(iStim) + dImax );
				end
				if any( kResp )
					nExtra(:) = nExtra - 1;
					stimResp(iStim,2) = Iresp(find(kResp,1,'first')) - Istim(iStim);		% latency (samples)
				end
			end
			iStim = nStim;
				kResp = Iresp > Istim(iStim);		% buttonpresses after current target or novel
				if any( kResp )
					nExtra(:) = nExtra + sum( kResp );
					kResp(kResp) = Iresp(kResp) >= ( Istim(iStim) + dImin ) & Iresp(kResp) <= ( Istim(iStim) + dImax );
				end
				if any( kResp )
					nExtra(:) = nExtra - 1;
					stimResp(iStim,2) = Iresp(find(kResp,1,'first')) - Istim(iStim);		% latency (samples)
				end

			nStnd = numel( Istnd );
			nTarg = numel( Itarg );
			nNovl = numel( Inovl );
			nHit  = sum(  stimResp(stimResp(:,1)==1,2) ~= 0 );
			nFA   = sum(  stimResp(stimResp(:,1)==2,2) ~= 0 );		% Novel
			nFA0  = sum(  stimResp(stimResp(:,1)==0,2) ~= 0 );		% Standard
			kVar(:) = strcmp( QAvars, 'TrgHit' );
			QAtable{iSeq,kVar} = sprintf( '%d/%d', nHit, nTarg );
			if nHit == nTarg
				QAstatus(iSeq,kVar) = 2;
			elseif nTarg - nHit <= errTol
				QAstatus(iSeq,kVar) = 1;
			end
			kVar(:) = strcmp( QAvars, 'NovelFA' );
			QAtable{iSeq,kVar} = sprintf( '%d/%d', nFA, nNovl );
			if nFA == 0
				QAstatus(iSeq,kVar) = 2;
			elseif nFA <= errTol
				QAstatus(iSeq,kVar) = 1;
			end
			%{
			if nExtra ~= 0
				kVar(:) = strcmp( QAvars, 'OtherFA' );
				QAtable{iSeq,kVar} = sprintf( '%d', nExtra );
				if nExtra <= errTol
					QAstatus(iSeq,kVar) = 1;
				end
% 			else
% 				QAstatus(iSeq,kVar) = 2;
			end
			%}
			kVar(:) = strcmp( QAvars, 'StndFA' );
			QAtable{iSeq,kVar} = sprintf( '%d/%d', nFA0, nStnd );
			if nFA0 == 0
				QAstatus(iSeq,kVar) = 2;
			elseif nFA0 <= errTol
				QAstatus(iSeq,kVar) = 1;
			end
			% convert response latency from samples to seconds
			kResp = stimResp(:,2) ~= 0;
			stimResp(kResp,2) = stimResp(kResp,2) / fs;
			respData = [ respData; stimResp ];
		end
% 		if ismember( taskName, { 'ASSR', 'RestEO', 'RestEC' } )
% 		end
		
		% percentage of [1,80]Hz power @ line frequency
		nu     = floor(   nfft       / 2 ) + 1;		% # unique points in spectrum
		n2     = floor( ( nfft + 1 ) / 2 );			% index of last non-unique point in spectrum
		f      = (0:nu-1) * (fs/nfft);
% 		EEG    = fft( bsxfun( @minus, eeg(1:63,:), mean( eeg(1:63,:), 1 ) ), nfft, 2 );		% exclude VIS channel, re-reference
		EEG    = fft( bsxfun( @times, bsxfun( @minus, eeg(1:63,:), mean( eeg(1:63,:), 1 ) ), shiftdim( hann( nfft, 'periodic' ), -1 ) ), nfft, 2 );		% exclude VIS channel, re-reference
		EEG    = abs( EEG(:,1:nu) ) / nfft;			% amplitude
		EEG(:,2:n2) = EEG(:,2:n2) * 2;				% double non-unique freqencies
		EEG(:) = EEG.^2;							% power?
		kDen   = f >= 1 & f <= 80;
		kNum   = kDen;
		kNum(kNum) = abs( f(kNum) - fLine ) <= wf;
		pLine(:,iSeq) = sum( EEG(:,kNum), 2 ) ./ sum( EEG(:,kDen), 2 ) * 100;

	end
	pLineMax = max( pLine, [], 2 );
	
	
	%% Resting state data
	doRestSpectra = all( QAstatus(11:12,[1,2,11]) == 2, 1:2 );
	if doRestSpectra

		iSeq = 11;
		taskName = taskInfo{taskSeq(iSeq),1};
		codeInfo = taskInfo{taskSeq(iSeq),2};
		bvFile = fullfile( bvDir, sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, sprintf( 'task-%s', taskName ), sprintf( 'run-%02d', nRun(iSeq) ) ) );
		H      = bieegl_readBVtxt( bvFile );
		M      = bieegl_readBVtxt( [ bvFile(1:end-3), 'mrk' ] );
		eegEO  = bieegl_readBVdata( bieegl_readBVtxt( bvFile ), bvDir );
		kStim  = strcmp( { M.Marker.Mk.type }, 'Stimulus' );
		i1     = M.Marker.Mk(find(kStim,1,'first')).position;
		i2     = M.Marker.Mk(find(kStim,1,'last' )).position;
		i2(:)  = i2 + median( diff( [ M.Marker.Mk(kStim).position ] ) );
		i2(:)  = min( i2, size( eegEO, 2 ) );
		eegEO  = eegEO(1:63,i1:i2);
		fs     = 1 / ( H.Common.SamplingInterval * 1e-6 );					% sampling interval is in microseconds, get sampling rate in Hz

		iSeq = 12;
		taskName = taskInfo{taskSeq(iSeq),1};
		codeInfo = taskInfo{taskSeq(iSeq),2};
		bvFile = fullfile( bvDir, sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, sprintf( 'task-%s', taskName ), sprintf( 'run-%02d', nRun(iSeq) ) ) );
		H      = bieegl_readBVtxt( bvFile );
		if 1 / ( H.Common.SamplingInterval * 1e-6 ) ~= fs
			error( 'sampling rate varies between EO & EC Rest' )
		end
		M      = bieegl_readBVtxt( [ bvFile(1:end-3), 'mrk' ] );
		eegEC  = bieegl_readBVdata( bieegl_readBVtxt( bvFile ), bvDir );
		kStim  = strcmp( { M.Marker.Mk.type }, 'Stimulus' );
		i1     = M.Marker.Mk(find(kStim,1,'first')).position;
		i2     = M.Marker.Mk(find(kStim,1,'last' )).position;
		i2(:)  = i2 + median( diff( [ M.Marker.Mk(kStim).position ] ) );
		i2(:)  = min( i2, size( eegEC, 2 ) );
		eegEC  = eegEC(1:63,i1:i2);
		
		i1(:) = size( eegEO, 2 );
		i2(:) = size( eegEC, 2 );
		if i1 < i2
			eegEC(:,i1+1:i2) = [];
		elseif i1 > i2
			eegEO(:,i2+1:i1) = [];
		end
		
		% re-reference?
		eegEO(:) = bsxfun( @minus, eegEO, mean( eegEO, 1 ) );
		eegEC(:) = bsxfun( @minus, eegEC, mean( eegEC, 1 ) );

		% downsample data to double highest frequency you want to look at
		if fs == 1000 && size( eegEO, 2 ) >= 180000
			% 200 Hz
			eegEO = eegEO(:,1:5:180000);
			eegEC = eegEC(:,1:5:180000);
			fs(:) = fs / 5;
		end

		nfft     = size( eegEO, 2 );
		nu       = floor(   nfft       / 2 ) + 1;		% # unique points in spectrum
		n2       = floor( ( nfft + 1 ) / 2 );			% index of last non-unique point in spectrum
		f        = (0:nu-1) * (fs/nfft);
		fftWin   = shiftdim( hann( nfft, 'periodic' ), -1 );
		eegEO(:) = fft( bsxfun( @times, eegEO, fftWin ), nfft, 2 );
		eegEC(:) = fft( bsxfun( @times, eegEC, fftWin ), nfft, 2 );
		eegEO    = abs( eegEO(:,1:nu) ) / nfft;			% amplitude
		eegEC    = abs( eegEC(:,1:nu) ) / nfft;
		eegEO(:,2:n2) = eegEO(:,2:n2) * 2;				% double non-unique freqencies
		eegEC(:,2:n2) = eegEC(:,2:n2) * 2;
		
		
		% do something to smooth out spectrum
		switch 2
			case 0
			case 1		% reduce resolution so plot isn't no noisy looking
				freqRes = 0.1;				% desired resolution
				if freqRes > fs/nfft
					nSkip = round( freqRes / ( fs / nfft ) );
					f     =     f(1:nSkip:nu);
					eegEO = eegEO(:,1:nSkip:nu);
					eegEC = eegEC(:,1:nSkip:nu);
				else
					freqRes(:) = fs / nfft;
				end
			case 2		% filter in spectral domain to smooth spectra
% 				nFilt = 11;		% simple moving average
% 				bFilt = repmat( 1/nFilt, 1, nFilt );
% 				aFilt = 1;
% 				class( eegEO )
% 				eegEO(:) = filtfilt( bFilt, aFilt, double( eegEO' ) )';		% filtfilt doesn't have dim input
% 				eegEC(:) = filtfilt( bFilt, aFilt, double( eegEC' ) )';
				nFilt = 5;		% median filter works well, but gets rid of line noise spike if too high
				if nFilt ~= 1
					eegEO(:) = medfilt1( eegEO, nFilt, [], 2 );		% , 'includenan', 'zeropad' );
					eegEC(:) = medfilt1( eegEC, nFilt, [], 2 );
				end
		end
		
	end
	
	%%
	
	
% 	nmap = 256;
% % 	cmap = parula( nmap );
% 	g = 0.75;
% 	cmap = [ linspace(0,g,nmap/2), linspace(g,1,nmap/2); repmat(g,1,nmap/2), linspace(g,0,nmap/2); zeros(1,nmap) ]';
	
	% [ R, G, B, transition value ]
	mapSpec = [
		0    , 0.625, 0, nan	% green (starts from zero)
		1    , 1    , 0, 3/6	% yellow
		1    , 0.5  , 0, 4/6	% orange
		1    , 0    , 0, 5/6	% bright red
		0.625, 0    , 0, nan	% dark red (ends at one)
	];
	nmap = 256;
	F    = linspace( 0, 1, nmap )';
	cmap = zeros( nmap, 1 );
	iRow = 1;
		kF = F < mapSpec(iRow+1,4);
		nF = sum( kF );
		for iCol = 1:3
			cmap(kF,iCol) = linspace( mapSpec(iRow,iCol), mapSpec(iRow+1,iCol), nF );
		end
	for iRow = 2:size( mapSpec, 1 )-2
		kF(:) = F >= mapSpec(iRow,4) & F < mapSpec(iRow+1,4);
		nF(:) = sum( kF );
		for iCol = 1:3
			cmap(kF,iCol) = linspace( mapSpec(iRow,iCol), mapSpec(iRow+1,iCol), nF );
		end
	end
	iRow(:) = iRow + 1;
		kF(:) = F >= mapSpec(iRow,4);
		nF(:) = sum( kF );
		for iCol = 1:3
			cmap(kF,iCol) = linspace( mapSpec(iRow,iCol), mapSpec(iRow+1,iCol), nF );
		end


	% add it d' or A'
	% d' = norminv(hitRate) - norminv(faRate)
	% A' = strange polygonal thing.  see https://sites.google.com/a/mtu.edu/whynotaprime/
	kStandard = respData(:,1) == 0;
	kTarget   = respData(:,1) == 1;
	kNovel    = respData(:,1) == 2;
	kResp     = respData(:,2) ~= 0;
	kVis      = respData(:,3) == 1;
	kAud      = respData(:,3) == 2;
	hitRate = [
		sum( kVis & kTarget & kResp ) / sum( kVis & kTarget )		% visual
		sum( kAud & kTarget & kResp ) / sum( kAud & kTarget )		% auditory
		sum(        kTarget & kResp ) / sum(        kTarget )		% combined
	];
	FARate = [
		sum( kVis & kNovel & kResp ) / sum( kVis & kNovel )
		sum( kAud & kNovel & kResp ) / sum( kAud & kNovel )
		sum(        kNovel & kResp ) / sum(        kNovel )
	];
	FARate0 = [
		sum( kVis & kStandard & kResp ) / sum( kVis & kStandard )
		sum( kAud & kStandard & kResp ) / sum( kAud & kStandard )
		sum(        kStandard & kResp ) / sum(        kStandard )
	];
	dPrime = norminv( hitRate ) - norminv( FARate );
	APrime = nan( 3, 1 );
	k = FARate <= hitRate;
	APrime(k) = 0.75 + ( hitRate - FARate ) / 4;
	k = FARate <= 0.5 & 0.5 <= hitRate;
	APrime(k) = APrime(k) - FARate(k) .* ( 1 - hitRate(k) );
	k = FARate <= hitRate & hitRate < 0.5;
	APrime(k) = APrime(k) - FARate(k) ./ hitRate(k) / 4;
	k = 0.5 < FARate & FARate <= hitRate;
	APrime(k) = APrime(k) - ( 1 - hitRate(k) ) ./ ( 1 - FARate(k) ) / 4;

	%% some topoplot options
	%   electrodes [on], off, labels, numbers, ptslabels, ptsnumbers
	%   style: map, contour, [both], fill, blank
	%   shading: [flat] interp
	zThresh = 25;
	zLimit  = zThresh * 2;
	topoOpts = { 'nosedir', '+Y', 'style', 'map', 'colormap', cmap, 'shading', 'flat', 'maplimits', [ 0, zLimit ], 'conv', 'on',...
		'headrad', 0.5, 'electrodes', 'on', 'emarker', { '.', 'k', 8, 0.5 }, 'hcolor', repmat( 0.333, 1, 3 ),...
		'gridscale', 200, 'circgrid', 360 };
% 	'intrad', max( [ chanLocs(ILocs(kZ)).radius ] )
% 	'plotrad', max( [ chanLocs(ILocs(kZ)).radius ] )*1.1

	cOrder = get( 0, 'defaultaxescolororder' );
	fontSize   = 14;
	fontWeight = 'normal';

	badChanColor = [ 0.875, 1, 1 ];
	
	hAx = gobjects( 1, 6 );
	hFig = findobj( 'Type', 'figure', 'Tag', mfilename );
	if isempty( hFig )
		hFig = figure( 'Tag', mfilename );
	elseif numel( hFig ) > 1
		hFig = hFig(1);
	end
% 	set( hFig, 'Position', [ -2500, -300, 1800, 1000 ] )		% SCN laptop w/ VA disiplay attached
	set( hFig, 'Position', [    50,   50, 1400, 1000 ], 'MenuBar', 'none' )		% SCN laptop native display @ 200%, i've since switched to 225% it still saves OK figure even if they're partially off screen
	clf
	
	% 1. Impedance
	hAx(1) = subplot( 3, 2, 1 );
		if isempty( Z ) || all( isnan( [ Z{kZ,2,iZ} ] ) )
			text( 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Position', [ 0.5, 0.5, 0 ],...
				'String', [ badColor, zMsg ], 'FontSize', fontSize, 'FontWeight', fontWeight )
			set( hAx(1), 'Visible', 'off' )		% why can I title invisible topo axis, but this hides title!!!
		else
			% [ hTopo, cdata ] = topoplot...
			topoplot( min( [ Z{kZ,2,iZ} ], zLimit*2 ), chanLocs(ILocs(kZ)), topoOpts{:} );		% Infs don't get interpolated

			topoRadius = [ chanLocs(ILocs(kZ)).radius ];
			topoTheta  = [ chanLocs(ILocs(kZ)).theta  ];
			fXY        = 0.5 / max( min( 1, max( topoRadius ) * 1.02 ), 0.5 );		% topoplot.m squeeze factor
			topoX      =  topoRadius .* cosd( topoTheta ) * fXY;
			topoY      = -topoRadius .* sind( topoTheta ) * fXY;
			kThresh    = [ Z{kZ,2,iZ} ] > zThresh;
			line( topoX(kThresh), topoY(kThresh), repmat( 10.5, 1, sum(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )

			colorbar%( 'southoutside' );
		end
		if ~isempty( Z )
			zStr = '';
			for i = 1:size( zRange, 1 )
				if all( zRange(iZr,:) == [ 25, 75 ] )
					zStr = [ zStr, goodColor ];
				else
					zStr = [ zStr, badColor ];
				end
				zStr = [ zStr, sprintf( '%g, %g\n', zRange(i,:) ) ];
			end

			% use kZ or all impedance channels? i.e. include ground?
			text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.35, 0.95, 0 ],...
				'FontSize', 12, 'String', sprintf( [	'%d Impedance Recording(s)\n',...
														'Min. = %g'     , repmat( ', %g'   , 1, nZ-1 ), '\n',...
														'Max. = %g'     , repmat( ', %g'   , 1, nZ-1 ), '\n',...
														'Median = %0.1f', repmat( ', %0.1f', 1, nZ-1 ), '\n',...
														'# > %g k\\Omega = %d', repmat( ', %d', 1, nZ-1 ), ' / %d\n',...
														'Range:\n%s' ],...
				nZ, min(Zdata,[],1), max(Zdata,[],1), median(Zdata,1), zThresh, sum(Zdata>zThresh,1), size(Zdata,1), zStr ) )
		end
		
	% 2. Line noise
	pLimit = 10;
	topoOpts{10} = [ 0, pLimit ];
	hAx(2) = subplot( 3, 2, 2 );
		topoplot( pLineMax, chanLocs(1:63), topoOpts{:} );
	
		topoRadius = [ chanLocs(1:63).radius ];
		topoTheta  = [ chanLocs(1:63).theta  ];
		fXY        = 0.5 / max( min( 1, max( topoRadius ) * 1.02 ), 0.5 );		% topoplot.m squeeze factor
		topoX      =  topoRadius .* cosd( topoTheta ) * fXY;
		topoY      = -topoRadius .* sind( topoTheta ) * fXY;
		kThresh    = pLineMax > pLimit;
		line( topoX(kThresh), topoY(kThresh), repmat( 10.5, 1, sum(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )
	
		colorbar%( 'southoutside' );
			text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.35, 0.95, 0 ],...
				'FontSize', 12, 'String', sprintf( [	'Min. = %0.1f\n',...
														'Max. = %0.1f\n',...
														'Median = %0.1f\n',...
														'# > %g %% = %d / %d' ],...
				min(pLineMax), max(pLineMax), median(pLineMax), pLimit, sum(pLineMax>pLimit), numel(pLineMax) ) )
	
	% 3. Response rates
	hAx(3) = subplot( 3, 3, 4 );
		bar( 1:3, [ hitRate(1:2), FARate(1:2), FARate0(1:2) ]' * 1e2, 1 )
		set( hAx(3), 'XLim', [ 0.5, 3.5 ], 'XTick', 1:3, 'XTickLabel', { 'Target Hit', 'Novel FA', 'Stnd FA' }, 'YLim', [ 0, 100 ] )
		set( [
% 			text( 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Position', [ 0.95, 0.95 ],...
% 				'String', sprintf( 'd^{\\prime} = {\\color[rgb]{%g,%g,%g}%0.3f}, \\color[rgb]{%g,%g,%g}%0.3f', cOrder(1,:), dPrime(1), cOrder(2,:), dPrime(2) ) )
			text( 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Position', [ 0.95, 0.95 ],...
				'String', sprintf( '\\color[rgb]{%g,%g,%g}Visual\n\\color[rgb]{%g,%g,%g}Auditory', cOrder(1,:), cOrder(2,:) ) )
			], 'FontSize', fontSize+2, 'FontWeight', fontWeight )
		set( hAx(3), 'YLim', [ -10, 110 ] )

	% 4. Reaction Time
	hAx(4) = subplot( 3, 3, 5 );
		RT   = respData(kResp,2) * 1e3;
		kVis = kVis(kResp);
		kAud = kAud(kResp);
		kHit = respData(kResp,1) == 1;
% 		kFA  = respData(kResp,1) == 2;
% 		kFA0 = respData(kResp,1) == 0;
		switch 2
			case 1
				RTlimit = 0;
				opts = { 'Marker', 'o', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'LineWidth', 1 };
				hold on
				kPlot = kHit & kVis;
				if any( kPlot )
					RTdot = median( RT(kPlot) );
					RTerr  = std( RT(kPlot) );% / sqrt( sum( kPlot ) );
					errorbar( 1, RTdot, RTerr, 'Color', cOrder(1,:), opts{:} )
					RTlimit = RTdot + RTerr;
				end
				kPlot = kHit & kAud;
				if any( kPlot )
					RTdot = median( RT(kPlot) );
					RTerr  = std( RT(kPlot) );% / sqrt( sum( kPlot ) );
					errorbar( 2, RTdot, RTerr, 'Color', cOrder(2,:), opts{:} )
					RTlimit = max( RTlimit, RTdot + RTerr );
				end
				hold off
				set( hAx(4), 'XLim', [ 0.5, 2.5 ], 'XTick', 1:2, 'XTickLabel', { 'Visual', 'Auditory' }, 'YLim', [ 0, RTlimit*1.1 ], 'Box', 'on' )
			case 2
				% exclude FAs
				kVis(~kHit) = false;
				kAud(~kHit) = false;
				boxplot( [ RT(kVis); RT(kAud) ], [ repmat({'Visual'},sum(kVis),1); repmat({'Auditory'},sum(kAud),1) ],...
					'BoxStyle', 'outline', 'MedianStyle', 'line', 'Notch', 'on', 'PlotStyle', 'traditional',...
					'Symbol', 'o', 'OutlierSize', 6, 'Widths', 0.5, 'ExtremeMode', 'compress', 'Jitter', 0.1, 'Whisker', 1.5,...
					'LabelOrientation', 'horizontal', 'LabelVerbosity', 'all', 'Orientation', 'horizontal',...
					'Positions', [ ones(1,any(kVis)), repmat(2,1,any(kAud)) ] )
 				set( hAx(4), 'PositionConstraint', 'innerposition' )
				set( hAx(4), 'YDir', 'reverse', 'XLim', [ 0, max( RT( kVis | kAud ) )*1.1 ] )
		end

	% Resting State relative amplitude EC/EO looking for gamma bump
	hAx(5) = subplot( 3, 3, 6 );
	restChan = 'Mean';
% 	restChan = 'Oz';
% 	restChan = 'POz';
% 	restChan = 'Pz';
	if doRestSpectra
		% [0,30]Hz linear, [1,100]Hz log?
		switch 1	% 1 = EO & EC spectra, 2 = ratio, 3 = both
			case 1
%				kf = f > 0;
				kf = f >= 1 & f <= 100;
				if strcmp( restChan, 'Mean' )
					hLine = loglog( f(kf), mean( eegEC(:,kf), 1 ), f(kf), mean( eegEO(:,kf), 1 ) );
				else
					iRest = find( strcmp( {chanLocs.labels}, restChan ) );
					hLine = loglog( f(kf), eegEC(iRest,kf), f(kf), eegEO(iRest,kf) );
				end
				set( hLine(1), 'Color', cOrder(4,:) )
				set( hLine(2), 'Color', cOrder(5,:) )
				set( [
					text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Position', [ 0.05, 0.05 ],...
						'String', sprintf( '\\color[rgb]{%g,%g,%g}Eyes Closed\n\\color[rgb]{%g,%g,%g}Eyes Open', cOrder(4,:), cOrder(5,:) ) )
					], 'FontSize', fontSize, 'FontWeight', fontWeight )
			case 2
				kf = f > 0 & f <= 30;
				if strcmp( restChan, 'Mean' )
					plot( f(kf), mean( eegEC(:,kf), 1 ) ./ mean( eegEO(:,kf), 1 ), 'Color', repmat( 0.625, 1, 3 ) )%cOrder(5,:) )
				else
					iRest = find( strcmp( {chanLocs.labels}, restChan ) );
					plot( f(kf), eegEC(iRest,kf) ./ eegEO(iRest,kf), 'Color', repmat( 0.625, 1, 3 ) )
				end
			case 3
				kf = f >= 1 & f <= 100;
				if strcmp( restChan, 'Mean' )
					hLine = loglog( f(kf), mean( eegEC(:,kf), 1 ), f(kf), mean( eegEO(:,kf), 1 ), f(kf), mean( eegEC(:,kf), 1 ) ./ mean( eegEO(:,kf), 1 ) );
				else
					iRest = find( strcmp( {chanLocs.labels}, restChan ) );
					hLine = loglog( f(kf), eegEC(iRest,kf), f(kf), eegEO(iRest,kf), f(kf), eegEC(iRest,kf) ./ eegEO(iRest,kf) );
				end
				set( hLine(1), 'Color', cOrder(4,:) )
				set( hLine(2), 'Color', cOrder(5,:) )
				set( hLine(3), 'Color', repmat( 0.625, 1, 3 ) )
				set( [
					text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Position', [ 0.05, 0.05 ],...
						'String', sprintf( '\\color[rgb]{%g,%g,%g}Eyes Closed\n\\color[rgb]{%g,%g,%g}Eyes Open\n\\color[rgb]{%g,%g,%g}Ratio', cOrder(4,:), cOrder(5,:), 0.625, 0.625, 0.625 ) )
					], 'FontSize', fontSize, 'FontWeight', fontWeight )
		end
	else
		set( hAx(5), 'Box', 'on', 'Visible', 'off' )
	end

	% Text table
	hAx(6) = subplot( 3, 1, 3 );
		% Brain Products "Photo Sensor" is a photo diode
		% QAvars = { 'Run', taskInfo{1,2}{[ 1:3, 5:6 ],2}, 'VIS', 'TrgHit', 'NovelFA', 'OtherFA', 'Misc' };
% 		QAline1 = QAvars;
% 		QAline1 = { 'Run',  'Oddball',       '',      '',      'MMN',        '', 'Display',    'Hit',    'FA',         '', 'Misc' };
		QAline1 = {    'Run',       'OD',     'OD',    'OD',      'MMN',     'MMN', 'Display',    'Hit',    'FA',       'FA',    'Misc.' };
		QAline2 = { '(seq#)', 'Standard', 'Target', 'Novel', 'Standard', 'Deviant',   '(160)', 'Target', 'Novel', 'Standard', 'commnens' };
		xTxt = [ 1.6, 1, 0.8, 0.8, 1, 0.8, 1, 0.8, 0.8, 1, 1.2 ];
		horizAlign = 'left';
% 		horizAlign = 'right';
		switch horizAlign
			case 'left'
				xTxt(:) = [ 0, cumsum( xTxt(1:nVar-1) ) / sum( xTxt ) ];	
			case 'right'
				xTxt(:) = cumsum( xTxt ) / sum( xTxt );
				xTxt(1) = 0;		
		end
		for iVar = 1:nVar
			if iVar == 1
				hAlign = 'left';
			else
				hAlign = horizAlign;
			end
			text( 'Units', 'normalized', 'HorizontalAlignment', hAlign, 'VerticalAlignment', 'top',...
				'Position', [ xTxt(iVar), 1+1/nSeq, 0 ], 'String', QAline1{iVar},...
				'FontSize', 12, 'FontWeight', 'normal', 'FontName', 'Courier' )			
			text( 'Units', 'normalized', 'HorizontalAlignment', hAlign, 'VerticalAlignment', 'top',...
				'Position', [ xTxt(iVar), 1+0/nSeq, 0 ], 'String', QAline2{iVar},...
				'FontSize', 12, 'FontWeight', 'normal', 'FontName', 'Courier' )			
			for iSeq = 1:nSeq
				switch QAstatus(iSeq,iVar)
					case 2
						colorStr = goodColor;
					case 1
						colorStr =   okColor;
					otherwise
						colorStr =  badColor;
				end
				text( 'Units', 'normalized', 'HorizontalAlignment', hAlign, 'VerticalAlignment', 'top',...
					'Position', [ xTxt(iVar), 1-iSeq/nSeq, 0 ], 'String', [ colorStr, QAtable{iSeq,iVar} ],...
					'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Courier' )
			end
		end
		if any( kInvalidRun )
			kInvalidRun = find( kInvalidRun );
			iExtra      = 1;
			extraStr    = sprintf( 'EXTRA: %s-%02d', taskInfo{taskSeqFound(kInvalidRun(iExtra)),1}, nRunFound(kInvalidRun(iExtra)) );
			for iExtra = 2:numel( kInvalidRun )
				extraStr = sprintf( '%s, %s-%02d', extraStr, taskInfo{taskSeqFound(kInvalidRun(iExtra)),1}, nRunFound(kInvalidRun(iExtra)) );		% note: tabs won't show up!
			end
			text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top',...
				'Position', [ xTxt(1), 1-(nSeq+1)/nSeq, 0 ], 'String', [ okColor, extraStr ],...
				'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Courier' )
		end
		set( hAx(6), 'Visible', 'off' )

	set([
			title(  hAx(1), sprintf( '%s\n\\fontsize{12}%s', subjId, sessDate ), 'Visible', 'on' )
			ylabel( hAx(1), sprintf( 'Recording %d / %d', iZ, nZ ), 'Visible', 'on' )
			xlabel( hAx(1), 'Impedance (k\Omega)', 'Visible', 'on' )

			xlabel( hAx(2), sprintf( 'Power @ %g Hz (%%)', fLine ), 'Visible', 'on' )

			ylabel( hAx(3), 'Response Rate (%)' )
			
			xlabel( hAx(4), 'Target Reaction Time (ms)' )
	
			ylabel( hAx(5), [ restChan, ' Amplitude (\muV)' ] )
% 			ylabel( hAx(5), { 'EC / EO'; [ restChan, ' Amplitude' ] } )
			xlabel( hAx(5), 'Frequency (Hz)' )
		], 'FontSize', fontSize, 'FontWeight', fontWeight )
	
	if isempty( Z )
		set( get( hAx(1), 'XLabel' ), 'Visible', 'off' )
	end
	if isempty( Z ) || nZ == 1
		set( get( hAx(1), 'YLabel' ), 'Visible', 'off' )
	end
	set( hAx(1), 'CLim', [ 0, zLimit ] )
	set( hAx(2), 'CLim', [ 0, pLimit ] )
	set( hAx(3:5), 'FontSize', 12 )
	set( hAx([3 5]), 'YGrid', 'on' )
	set( hAx(4), 'XGrid', 'on' )

	figure( hFig )

	pngOut = fullfile( AMPSCZdir, 'Figures', 'QA', [ subjId, '_', sessDate, '_QA.png' ] );		% [ subjTag(5:end), '_', sessTag(5:end), '_QA.png' ]
	if isempty( writeFlag )
		writeFlag = exist( pngOut, 'file' ) ~= 2;		
		if ~writeFlag
			writeFlag(:) = strcmp( questdlg( 'png exists. overwrite?', mfilename, 'no', 'yes', 'no' ), 'yes' );
		end
	end
	if writeFlag
%		print( hFig, pngOut, '-dpng' )		% 1800x1000 figure window becomes 2813x1563
%		saveas( hFig, pngOut, 'png' )		% 1800x1000 figure window becomes 2813x1563
%		getframe( hFig )					% 1800x1000 figure window has     3600x2000 cdata
		figPos = get( hFig, 'Position' );
		img = getframe( hFig );
		img = imresize( img.cdata, figPos(4) / size( img.cdata, 1 ), 'bicubic' );		% scale by height
%		size( img )
		imwrite( img, pngOut, 'png' )
		fprintf( 'wrote %s\n', pngOut )
	end
	
	return
	
%%
iSeq = 2

		bvFile = fullfile( bvDir, sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, sprintf( 'task-%s', taskInfo{taskSeq(iSeq),1} ), sprintf( 'run-%02d', nRun(iSeq) ) ) );
		H      = bieegl_readBVtxt( bvFile );
		fs     = 1 / ( H.Common.SamplingInterval * 1e-6 );					% sampling interval is in microseconds, get sampling rate in Hz
		M      = bieegl_readBVtxt( [ bvFile(1:end-3), 'mrk' ] );
		
		eeg    = bieegl_readBVdata( bieegl_readBVtxt( bvFile ), bvDir );
		kStim  = strcmp( { M.Marker.Mk.type }, 'Stimulus' );
		i1     = M.Marker.Mk(find(kStim,1,'first')).position;
		i2     = M.Marker.Mk(find(kStim,1,'last' )).position;
		i2(:)  = i2 + ceil( 2 * fs );
		i2(:)  = max( i2, size( eeg, 2 ) );
		eeg    = eeg(:,i1:i2);
		nfft   = size( eeg, 2 );

		Iblink = find( ismember( { chanLocs(1:64).labels }, { 'Fp1', 'Fp2', 'AFz' } ) );		% channel(s) to use for blink detection
		yBlink = mean( eeg(Iblink,:), 1 );

plot( detrend( eeg(Iblink,:), 0 ) )


	
end
