function AMPSCZ_EEG_QC( sessionName, writeFlag, figLayout, writeDpdash, legacyPaths )
% Usage:
% >> AMPSCZ_EEG_QC( [sessionName], [writeFlag], [figLayout], [writeDpdash], [legacyPaths] )
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
%
% Dependencies: EEGLAB

% to do:
% add some verbosity flag for warnings?
% re-ref by epoch in preprocessing

	narginchk( 0, 5 )

	if exist( 'writeFlag', 'var' ) ~= 1
		writeFlag = [];
	elseif ~isempty( writeFlag ) && ~( islogical( writeFlag ) && isscalar( writeFlag ) )
		error( 'writeFlag must be empty or logical scalar' )
	end
	if exist( 'figLayout', 'var' ) ~= 1 || isempty( figLayout )
		figLayout = 2;	% 1 = multi-panel png, 2 = individual pngs, otherwise no pngs
	end
	if exist( 'writeDpdash', 'var' ) ~= 1 || isempty( writeDpdash )
		writeDpdash = true;
	end
	if exist( 'legacyPaths', 'var' ) ~= 1 || isempty( legacyPaths )
		legacyPaths = false;		% temporary hack to be able to process files in old folder heirarchy
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
					AMPSCZ_EEG_QC( sessionName{iSession}, writeFlag, figLayout, writeDpdash, legacyPaths )
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
		sessionList = AMPSCZ_EEG_findProcSessions;
		iSession = strcmp( strcat( sessionList(:,2), '_', sessionList(:,3) ), sessionName );
		if ~any( iSession ) && ~legacyPaths
			error( 'Session %s not available', sessionName )
		end
% 		iSession = find( iSession, 1, 'first' );		% there can't be duplicates in sessionList!
	else
		[ sessionList, iSession ] = AMPSCZ_EEG_findProcSessions( 'multiple' );
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
				AMPSCZ_EEG_QC( sprintf( '%s_%s', sessionList{iSession(iMulti),2:3} ), writeFlag, figLayout, writeDpdash, legacyPaths )
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
	locsFile    = fullfile( AMPSCZtools, 'AMPSCZ_EEG_actiCHamp65ref_noseX.ced' );

	[ AMPSCZdir, eegLabDir ] = AMPSCZ_EEG_paths;

	% minimum & maximum reaction times (s), button presses out of this range not counted as responses
	RTrange = AMPSCZ_EEG_RTrange;
	
	hannPath = which( 'hann.m' );		% There's a hann.m in fieldrip, that's pretty useless, it just calls hanning.m
	if ~contains( hannPath, matlabroot )
% 		error( 'fix path so hann.m is native MATLAB' )
		if ~AMPSCZ_EEG_matlabPaths
			restoredefaultpath
		end
	end
	if isempty( which( 'eeglab.m' ) )
		if ~AMPSCZ_EEG_matlabPaths
			addpath( eegLabDir, '-begin' )
			eeglab
			drawnow
			close( gcf )
		end
	end
	if ~contains( which( 'topoplot.m' ), 'modifications' )
		addpath( fullfile( AMPSCZtools, 'modifications', 'eeglab' ), '-begin' )
	end
	
	siteInfo = AMPSCZ_EEG_siteInfo;
	[ taskInfo, taskSeq ] = AMPSCZ_EEG_taskSeq;
	nTask = size( taskInfo, 1 );		% i.e. 5
	nSeq  = numel( taskSeq );
% 	cTask = [
% 		0   , 0.75, 0.75
% 		1   , 0.75, 0
% 		0   , 0.75, 0
% 		0.75, 0.75, 0
% 		0.75, 0.75, 0.75
% 	];

	% Replace some names w/ Standard to get event counts in a meaningful column
	for iTask = find( ismember( taskInfo(:,1), { 'ASSR', 'RestEO', 'RestEC' } ) )'
		[ taskInfo{iTask,2}{:,2} ] = deal( 'Standard' );
	end

	siteId = sessionName(1:2);
	iSite  = find( strcmp( siteInfo(:,1), siteId ) );
	if numel( iSite ) ~= 1
		error( 'site identification error' )
	end
	networkName = siteInfo{iSite,2};
	
	subjId   = sessionName(1:7);
	sessDate = sessionName(9:16);
	subjTag  = [ 'sub-', subjId   ];
	sessTag  = [ 'ses-', sessDate ];
	sessDir  = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ], 'processed', subjId, 'eeg', sessTag );
	bvDir    = fullfile( sessDir, 'BIDS' );

	if legacyPaths
		% hack for old BIDS folder structure
		sessDir = fullfile( fileparts( AMPSCZdir ), 'ProNET' );
		bvDir   = fullfile( sessDir, siteId, 'BIDS', subjTag, sessTag, 'eeg' );
	end
	
	% e.g. pop_chanedit( struct( 'labels', Z(:,1) ) )...
	chanLocs = readlocs( locsFile, 'importmode', 'native', 'filetype', 'chanedit' );

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
% 	QCvars   = { 'Run', 'Standard', 'Target', 'Novel', 'Tone1', 'Tone2', 'VIS', 'Hit', 'FA', 'Extra', 'Misc' };
% 	QCvars   = { 'Run', taskInfo{1,2}{[ 1:3, 5:6 ],2}, 'VIS', 'TrgHit', 'NovelFA', 'OtherFA', 'Misc' };
	QCvars   = { 'Run', taskInfo{1,2}{[ 1:3, 5:6 ],2}, 'VIS', 'TrgHit', 'NovelFA', 'StndFA', 'Misc' };
	nVar     = numel( QCvars );
	kVar     = false(    1, nVar );
	QCtable  =  cell( nSeq, nVar );
	QCstatus = zeros( nSeq, nVar ); 

	goodColor = '\color[rgb]{0,0.75,0}';
	okColor   = '\color[rgb]{0.75,0.75,0}';
	badColor  = '\color{red}';
	respData  = [];
	nEventMissing = 0;
	nEventExtra   = 0;
	nVisMissing   = 0;
	nVisExtra     = 0;
	for iSeq = 1:nSeq

		taskName = taskInfo{taskSeq(iSeq),1};
		codeInfo = taskInfo{taskSeq(iSeq),2};

		kVar(:) = strcmp( QCvars, 'Run' );
		[ ~, iRunOrder ] = ismember( [ taskSeq(iSeq), nRun(iSeq) ], [ taskSeqFound(:), nRunFound(:) ], 'rows' );
		QCtable{iSeq,kVar}  = sprintf( '(%02d) %s-%02d', iRunOrder, taskName, nRun(iSeq) );

		bvFile = fullfile( bvDir, sprintf( '%s_%s_%s_%s_eeg.vhdr', subjTag, sessTag, sprintf( 'task-%s', taskName ), sprintf( 'run-%02d', nRun(iSeq) ) ) );
		fileExist(iSeq) = exist( bvFile, 'file' ) == 2;
		if ~fileExist(iSeq)
			warning( '%s missing', bvFile )
			continue
		end
		if iRunOrder == iSeq
			QCstatus(iSeq,kVar) = 2;
		else
			QCstatus(iSeq,kVar) = 1;
		end

		H  = bieegl_readBVtxt( bvFile );
		fs = 1 / ( H.Common.SamplingInterval * 1e-6 );					% sampling interval is in microseconds, get sampling rate in Hz
		M  = bieegl_readBVtxt( [ bvFile(1:end-3), 'mrk' ] );

		kLostSamples = strncmp( { M.Marker.Mk.description }, 'LostSamples:', 12 );
		kVar(:) = strcmp( QCvars, 'Misc' );
		if any( kLostSamples )
			nSampleLost = regexp( { M.Marker.Mk(kLostSamples).description }, '^LostSamples: (\d+)$', 'tokens', 'once' );
			nSampleLost = str2double( [ nSampleLost{:} ] );
			QCtable{iSeq,kVar} = sprintf( 'Lost %d epochs, %d samples', numel( nSampleLost ), sum( nSampleLost ) );
		else
			QCstatus(iSeq,kVar) = 2;
		end

		
		% check that # non-response event codes found matches expected value
		% ??? build this check into unzip program ??? or keep in QC
% 		Istim = find( ~cellfun( @isempty, codeInfo(:,3) ) );
		Istim = find( ~cellfun( @(u)strcmp(u,'Response'), codeInfo(:,2) ) );
% 		nStim = numel( Istim );
% 		codeFound{iSeq} = [ codeInfo(Istim,:), cell( nStim, 1 ) ];
		for iCode = Istim(:)'
			nExpected = codeInfo{iCode,3};
			nFound    = sum( strcmp( { M.Marker.Mk.description }, sprintf( 'S%3d', codeInfo{iCode,1} ) ) );
			kVar(:) = strcmp( QCvars, codeInfo{iCode,2} );
			QCtable{iSeq,kVar} = sprintf( '%d/%d', nFound, nExpected );
			if nFound == nExpected
				QCstatus(iSeq,kVar) = 2;
			else
				warning( '%s experiment, %s events: %d expected %d found', taskName, codeInfo{iCode,2}, nExpected, nFound )
				if nExpected > nFound
					nEventMissing(:) = nEventMissing + nExpected - nFound;
				else
					nEventExtra(:) = nEventExtra + nFound - nExpected;
				end
% 				continue
			end
		end

		eeg   = bieegl_readBVdata( H );
		kStim = strcmp( { M.Marker.Mk.type }, 'Stimulus' );
		i1    = M.Marker.Mk(find(kStim,1,'first')).position;
		i2    = M.Marker.Mk(find(kStim,1,'last' )).position;
		switch taskName
			case { 'VODMMN', 'AOD' }
% 				i1(:) = i1 - ceil( 1 * fs );
				i2(:) = i2 + ceil( 2 * fs );
			case { 'ASSR', 'RestEO', 'RestEC' }
				i2(:) = i2 + median( diff( [ M.Marker.Mk(kStim).position ] ) );
			otherwise
				error( 'bug' )
		end
% 		i1(:) = max( i1, 1 );
		i2(:) = min( i2, size( eeg, 2 ) );
		eeg   = eeg(:,i1:i2);
		nfft  = size( eeg, 2 );
		
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
			kVar(:) = strcmp( QCvars, 'VIS' );
			QCtable{iSeq,kVar} = sprintf( '%d/%d', nVis, nMrk );
			if nVis == nMrk
				QCstatus(iSeq,kVar) = 1 + ( nMrk == 160 );
			else
				% write out message instead of error
				warning( 'expecting %d photosensor onsets, found %d', nMrk, nVis )
				if nMrk > nVis
					nVisMissing(:) = nVisMissing + nMrk - nVis;
				else
					nVisExtra(:) = nVisExtra + nVis - nMrk;
				end
			end
		end
		
		% Get subject performance data
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
			kVar(:) = strcmp( QCvars, 'TrgHit' );
			QCtable{iSeq,kVar} = sprintf( '%d/%d', nHit, nTarg );
			if nHit == nTarg
				QCstatus(iSeq,kVar) = 2;
			elseif nTarg - nHit <= errTol
				QCstatus(iSeq,kVar) = 1;
			end
			kVar(:) = strcmp( QCvars, 'NovelFA' );
			QCtable{iSeq,kVar} = sprintf( '%d/%d', nFA, nNovl );
			if nFA == 0
				QCstatus(iSeq,kVar) = 2;
			elseif nFA <= errTol
				QCstatus(iSeq,kVar) = 1;
			end
			%{
			if nExtra ~= 0
				kVar(:) = strcmp( QCvars, 'OtherFA' );
				QCtable{iSeq,kVar} = sprintf( '%d', nExtra );
				if nExtra <= errTol
					QCstatus(iSeq,kVar) = 1;
				end
% 			else
% 				QCstatus(iSeq,kVar) = 2;
			end
			%}
			kVar(:) = strcmp( QCvars, 'StndFA' );
			QCtable{iSeq,kVar} = sprintf( '%d/%d', nFA0, nStnd );
			if nFA0 == 0
				QCstatus(iSeq,kVar) = 2;
			elseif nFA0 <= errTol
				QCstatus(iSeq,kVar) = 1;
			end
			% convert response latency from samples to seconds
			kResp = stimResp(:,2) ~= 0;
			stimResp(kResp,2) = stimResp(kResp,2) / fs;
			respData = [ respData; stimResp ];
		end

% 		if ismember( taskName, { 'ASSR', 'RestEO', 'RestEC' } )
% 		end
% 		if ismember( iSeq, 11:12 )		% RestEO, RestEC
% 		end
		
		% percentage of [1,80]Hz power @ line frequency
		nu     = floor(   nfft       / 2 ) + 1;		% # unique points in spectrum
		n2     = floor( ( nfft + 1 ) / 2 );			% index of last non-unique point in spectrum
		f      = (0:nu-1) * (fs/nfft);

		% exclude any channels in average reference?
		% e.g. correlation,variance,hurst exponent as in FASTER
		% or   extreme amplitudes, lack of correlation, lack of predicatability, unusal high-frequency noise as in PREP
		Ieeg        = 1:63;		% EEG channels.  exclude 'VIS'
		Ireref      = Ieeg;		% channels to potentially inlcude in reference estimate
		rerefMethod = 2;		% 0 = none, 1 = iterative winsorized peak-to-peak, 2 = FASTER, 3 = PREP (too slow for QC)
		switch rerefMethod
			case 0
			case 1
				% winsorize on peak-to-peak
				chanProp = max( eeg(Ireref,:), [], 2 ) - min( eeg(Ireref,:), [], 2 );
				nStd = 3;
				kOld = true( 63, 1 );
				nIt  = 1;
				kNew = chanProp <= median( chanProp(kOld) ) + std( chanProp(kOld) ) * nStd;
				while any( kNew ~= kOld ) && nIt < 1e2
					kOld(:) = kNew;
					kNew(:) = chanProp <= median( chanProp(kOld) ) + std( chanProp(kOld) ) * nStd;
					nIt(:)  = nIt + 1;
				end
% 				nIt
				if any( kNew )
					Ireref = Ireref( kNew );
					eeg(Ieeg,:) = bsxfun( @minus, eeg(Ieeg,:), mean( eeg(Ireref,:), 1 ) );
				end
			case 2
				% average reference after FASTER channel exclusions
				% how about interpolate excluded channels & include them in average
				% might require adopting EEGLAB structure
% 				chanProp = channel_properties( eeg(Ireref,:), 1:numel(Ireref), [] );	% #x3
% 				chanOutlier = min_z( chanProp );										% #x1
				kGood = ~min_z( channel_properties( eeg(Ireref,:), 1:numel(Ireref), [] ) );
				if any( kGood )
					Ireref = Ireref( kGood );
					eeg(Ieeg,:) = bsxfun( @minus, eeg(Ieeg,:), mean( eeg(Ireref,:), 1 ) );
% 					if ~all( kGood )
% 						eegStruct = ...
% 						eegStruct = h_eeg_interp_spl( eegStruct, Ireref(~kGood), [] );			% note: help says 3rd input is interpolation method, but really its channels to ignore!
% 						eeg(Ieeg,:) = eegStruct.data;
% 					end
% 					eeg(Ieeg,:) = bsxfun( @minus, eeg(Ieeg,:), mean( eeg(Ieeg,:), 1 ) );
				end
			case 3
				% PREP robust reference - can I do this w/o full EEGLAB structures?  needs chanlocs for sure
% 				error( 'under construction' )
% 				eegStruct = struct( 'data', eeg(Ieeg,:), 'srate', fs, 'chanlocs', chanLocs(Ieeg) );
				eegStruct = eeg_checkset( eeg_emptyset );
				[ eegStruct.nbchan, eegStruct.pnts, eegStruct.trials ] = size( eeg(Ieeg,:) );
				eegStruct.times    = (0:eegStruct.pnts-1) / fs;
				eegStruct.data     = eeg(Ieeg,:);
				eegStruct.srate    = fs;
				eegStruct.chanlocs = chanLocs(Ieeg);
				eegStruct.xmin     = 0;
				eegStruct.xmax     = ( eegStruct.pnts - 1 ) / eegStruct.srate + eegStruct.xmin;

				rerefOpts = struct( 'referenceChannels', Ireref, 'evaluationChannels', Ireref, 'rereference', Ieeg, 'referenceType', 'robust' );
				doInterp = false;
				if doInterp
					[ eegStruct, rerefOpts ] = performReference( eegStruct, rerefOpts );
					eeg(Ieeg,:) = eegStruct.data;
				else
					fprintf( '\n\n\n\t\t\t%d\n\n\n\n', iSeq )
% 					rerefOpts.interpolationOrder = 'none';		% this doesn't work, at least w/ robust referenceType
					[ ~, rerefOpts ] = performReference( eegStruct, rerefOpts );
					eeg(Ieeg,:) = bsxfun( @minus, eeg(Ieeg,:), rerefOpts.referenceSignal );
				end
		end
		
		EEG    = fft( bsxfun( @times, eeg(1:63,:), shiftdim( hann( nfft, 'periodic' ), -1 ) ), nfft, 2 );		% exclude VIS channel, re-reference
		EEG    = abs( EEG(:,1:nu) ) / nfft;			% amplitude
		EEG(:,2:n2) = EEG(:,2:n2) * 2;				% double non-unique freqencies
		EEG(:) = EEG.^2;							% power?
		kDen   = f >= 1 & f <= 80;
		kNum   = kDen;
		kNum(kNum) = abs( f(kNum) - fLine ) <= wf;
		pLine(:,iSeq) = sum( EEG(:,kNum), 2 ) ./ sum( EEG(:,kDen), 2 ) * 100;

		switch taskName
			case 'RestEO'
				eegEO = eeg(1:63,:);
				fsEO = fs;
			case 'RestEC'
				eegEC = eeg(1:63,:);
				fsEC = fs;
		end

	end
	pLineMax = max( pLine, [], 2 );
	
	
	%% Resting state data
	restChan = 'Mean';
% 	restChan = 'Oz';
% 	restChan = 'POz';
% 	restChan = 'Pz';
	doRestSpectra = all( QCstatus(11:12,[1,2,11]) ~= 0, 1:2 );
	if doRestSpectra

		% verify sampling rate match
		if fsEC ~= fsEO
			error( 'sampling rate varies between EO & EC Rest' )
		end

		% trim longer resting EEG file to length of shorter
		i1(:) = size( eegEO, 2 );
		i2(:) = size( eegEC, 2 );
		if i1 < i2
			eegEC(:,i1+1:i2) = [];
		elseif i1 > i2
			eegEO(:,i2+1:i1) = [];
		end
		
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
		% power
		eegEO(:) = eegEO.^2;
		eegEC(:) = eegEC.^2;
		
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
% 	dPrime = norminv( hitRate ) - norminv( FARate );
% 	APrime = nan( 3, 1 );
% 	k = FARate <= hitRate;
% 	APrime(k) = 0.75 + ( hitRate - FARate ) / 4;
% 	k = FARate <= 0.5 & 0.5 <= hitRate;
% 	APrime(k) = APrime(k) - FARate(k) .* ( 1 - hitRate(k) );
% 	k = FARate <= hitRate & hitRate < 0.5;
% 	APrime(k) = APrime(k) - FARate(k) ./ hitRate(k) / 4;
% 	k = 0.5 < FARate & FARate <= hitRate;
% 	APrime(k) = APrime(k) - ( 1 - hitRate(k) ) ./ ( 1 - FARate(k) ) / 4;

	zThresh = 25;		% impedance threshold
	pLimit  = 10;		% line power limit/threshold

	% see https://sites.google.com/g.harvard.edu/dpdash/documentation/user_doc?authuser=0
	% in particular pages 12-14 for making dpdash compatible outputs
	% "For runs, you can populate 1,2,3,...,12 under day column. 
	%  Mandatory fields that do not make sense to you e.g. reftime, 
	%  timeofday, weekday can be left empty in the CSV file" - Tashrif

	if doRestSpectra
		kf = f >= 8 & f <= 12;		% alpha band
		if strcmp( restChan, 'Mean' )
% 			alphaRatio = mean( mean( eegEC(:,kf), 1 )   ./       mean( eegEO(:,kf), 1 ) );		% mean ratio
			alphaRatio = mean( mean( eegEC(:,kf), 1 ) )  / mean( mean( eegEO(:,kf), 1 ) );		% ratio of means
% 			alphaRatio =       mean( eegEO(:,kf), 1 )'   \       mean( eegEC(:,kf), 1 )';		% scaling coefficient
		else
			iRest = find( strcmp( {chanLocs.labels}, restChan ) );
% 			alphaRatio = mean( eegEC(iRest,kf)   ./       eegEO(iRest,kf) );
			alphaRatio = mean( eegEC(iRest,kf) )  / mean( eegEO(iRest,kf) );
% 			alphaRatio =       eegEO(iRest,kf)'   \       eegEC(iRest,kf)';
		end
	else
		alphaRatio = [];
	end
	
	if isempty( zRange )
		zRangeDash = { [], [] };
	else
		zRangeDash = { zRange(iZr,1), zRange(iZr,2) };
	end
	if isempty( Z )
		nHighZChans = [];
	else
		nHighZChans = sum( Zdata(:,iZ) > zThresh );		% Zdata doesn't exist when Z is empty
	end
	dpdashData = {
		'reftime'        , '%0.0f'       , []
		'day'            , '%d'          , []		% use for runs?
		'timeofday'      , '%d:%02d:%02d', []
		'weekday'        , '%d'          , []
		'Technician'     , '%s'          , ''
		'dTrialsVODMMN'  , '%d'          , sum( taskSeqFound == 1 ) - sum( taskSeq == 1 )
		'dTrialsAOD'     , '%d'          , sum( taskSeqFound == 2 ) - sum( taskSeq == 2 )
		'dTrialsASSR'    , '%d'          , sum( taskSeqFound == 3 ) - sum( taskSeq == 3 )
		'dTrialsRestEO'  , '%d'          , sum( taskSeqFound == 4 ) - sum( taskSeq == 4 )
		'dTrialsRestEC'  , '%d'          , sum( taskSeqFound == 5 ) - sum( taskSeq == 5 )
		'MissingTriggers', '%d'          , nEventMissing
		'ExtraTriggers'  , '%d'          , nEventExtra
		'MissingFlashes' , '%d'          , nVisMissing
		'ExtraFlashes'   , '%d'          , nVisExtra
		'ImpRangeLo'     , '%g'          , zRangeDash{1}
		'ImpRangeHi'     , '%g'          , zRangeDash{2}
		'HighImpChans'   , '%d'          , nHighZChans
		'HighNoiseChans' , '%d'          , sum( pLineMax > pLimit )
		'HitRateVis'     , '%0.2f'       , hitRate(1) * 100		% (%)
		'HitRateAud'     , '%0.2f'       , hitRate(2) * 100
		'FARateNovelVis' , '%0.2f'       , FARate(1)  * 100
		'FARateNovelAud' , '%0.2f'       , FARate(2)  * 100
		'FARateStdVis'   , '%0.2f'       , FARate0(1) * 100
		'FARateStdAud'   , '%0.2f'       , FARate0(2) * 100
		'RTmedianVis'    , '%0.0f'       , median( respData( respData(:,1) == 1 & kResp & kVis, 2 ) ) * 1e3		% (ms)
		'RTmedianAud'    , '%0.0f'       , median( respData( respData(:,1) == 1 & kResp & kAud, 2 ) ) * 1e3		% note: median([]) = NaN
		'AlphaRatioEC'   , '%0.2f'       , alphaRatio
	};
		% file sequence flag?

	if writeDpdash
		% fileanme = <StudyName>-<SubjectID>-<Assessment>-day<D1>to<D2>.csv
		% StudyName, SujectID, Assessment [A-Za-z0-9]
		% D1, D2 [0-9]
		% delmiter = comma
		% 1st row contains variables names
		% 1st 4 variable names must be reftime, day, timeofday, and weekday
		% reftime = milliseconds since 6:00:00 AM on day of consent
		% day = days since consent day, consent day = 1
		% timeofday = time in 24 hr notation hh:mm:ss (leading zeros not required)
		% weekday = integer day of week, 1=saturday

		% run sheet files: .../Pronet/PHOENIX/PROTECTED/PronetCA/raw/CA00007/eeg/CA00007.Pronet.Run_sheet_eeg.csv
		% way down @ bottom
		% 0,0,chreeg_primaryperson,


		% need to figure out where to find consent date?
		% need to put technician intials in here, where are they coming from? should already be there in file tree?
		% line termination convention? line terminator after last line?
		% how do we look @ it?
		csvDir = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ], 'processed', subjId, 'eeg' );
%		csvDir = sessDir;
%		csvDir = fullfile( sessDir, '?' );				% keep everything organized by site/subject/session for BWH
%		csvName = sprintf( '%s-%s-%s-day%dto%d.csv', 'AMPSCZ', subjId, 'EEGqc', 1, 1 );
		csvName = sprintf( '%s-%s-%s-day%dto%d.csv', 'AMPSCZ', subjId, [ 'EEGqc', sessDate ], 1, 1 );
		csvFile = fullfile( csvDir, csvName );
		if isempty( writeFlag )
			writeCSV = exist( csvFile, 'file' ) ~= 2;
			if ~writeCSV
				writeCSV(:) = strcmp( questdlg( [ 'Replace ', csvName, ' ?' ], mfilename, 'no', 'yes', 'no' ), 'yes' );
			end
		else
			writeCSV = writeFlag;
		end
		if writeCSV
			[ fid, msg ] = fopen( csvFile, 'w' );
			if fid == -1
				error( msg )
			end
			nDash = size( dpdashData, 1 );
			fprintf( fid, '%s', dpdashData{1,1} );
			if nDash > 1
				fprintf( fid, ',%s', dpdashData{2:nDash,1} );
			end
%			fprintf( fid, '\r\n' );		% windowsy
			fprintf( fid, '\n' );		% linuxy
			if ~isempty( dpdashData{1,3} )
				fprintf( fid, dpdashData{1,2}, dpdashData{1,3} );
			end
			for iDash = 2:nDash
				if isempty( dpdashData{iDash,3} )
					fprintf( fid, ',' );
				else
					fprintf( fid, [ ',', dpdashData{iDash,2} ], dpdashData{iDash,3} );
				end
			end
%			fprintf( '\n' );			% add another line ending?
			if fclose( fid ) == -1
				warning( 'MATLAB:fcloseError', 'fclose error' )
			end
			fprintf( 'wrote %s\n', csvFile )
		end
	end

	hAx = gobjects( 1, 6 );
	switch figLayout
		case 1		% Single png, multiple panels
			hFig = findobj( 'Type', 'figure', 'Tag', mfilename );
			if isempty( hFig )
				hFig = figure( 'Tag', mfilename );
			elseif numel( hFig ) > 1
				hFig = hFig(1);
				clf( hFig )
			else
				clf( hFig )
			end
			% nomachine desktop e.g. 1812x1048
%			set( hFig, 'Position', [ -2500, -300, 1800, 1000 ] )		% SCN laptop w/ VA disiplay attached
			set( hFig, 'Position', [    50,   50, 1400, 1000 ], 'MenuBar', 'none' )		% SCN laptop native display @ 200%, i've since switched to 225% it still saves OK figure even if they're partially off screen
		case 2		% Multiple single-panel pngs for dashboard
			nFig = 6;
			hFig = gobjects( 1, nFig );
			for iFig = 1:2
				hFig(iFig) = figure( 'Position', [ 475+25*iFig, 325-25*iFig, 525, 250 ] );
				hAx(iFig)  =  axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
			end
			for iFig = 3:nFig
				hFig(iFig) = figure( 'Position', [ 475+25*iFig, 325-25*iFig, 350, 250 ] );
				hAx(iFig)  =  axes( 'Units', 'normalized', 'Position', [ 0.2, 0.2, 0.75, 0.75 ] );
			end
			set( hFig, 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
		otherwise
			return
	end
	
	%% some topoplot options
	%   electrodes [on], off, labels, numbers, ptslabels, ptsnumbers
	%   style: map, contour, [both], fill, blank
	%   shading: [flat] interp
	zLimit  = zThresh * 2;
	topoOpts = { 'nosedir', '+X', 'style', 'map', 'colormap', cmap, 'shading', 'flat', 'maplimits', [ 0, zLimit ], 'conv', 'on',...
		'headrad', 0.5, 'electrodes', 'on', 'emarker', { '.', 'k', 8, 0.5 }, 'hcolor', repmat( 0.333, 1, 3 ),...
		'gridscale', 200, 'circgrid', 360 };
% 	'intrad', max( [ chanLocs(ILocs(kZ)).radius ] )
% 	'plotrad', max( [ chanLocs(ILocs(kZ)).radius ] )*1.1

	cOrder = get( 0, 'defaultaxescolororder' );
	fontSize   = 14;
	fontWeight = 'normal';

	badChanColor = [ 0.875, 1, 1 ];
	
	% 1. Impedance
	figure( hFig(1) )
	if figLayout == 1
		hAx(1) = subplot( 3, 2, 1 );
	end
		topoOpts = [ topoOpts, { 'whitebk', 'on' } ];
		if isempty( Z ) || all( isnan( [ Z{kZ,2,iZ} ] ) )
			text( 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Position', [ 0.5, 0.5, 0 ],...
				'String', [ badColor, zMsg ], 'FontSize', fontSize, 'FontWeight', fontWeight )
			set( hAx(1), 'Visible', 'off', 'DataAspectRatio', [ 1, 1, 1 ] )		% why can I title invisible topo axis, but this hides title!!!
		else
			% [ hTopo, cdata ] = topoplot...
			topoplot( min( [ Z{kZ,2,iZ} ], zLimit*2 ), chanLocs(ILocs(kZ)), topoOpts{:} );		% Infs don't get interpolated

			topoRadius = [ chanLocs(ILocs(kZ)).radius ];
			topoTheta  = [ chanLocs(ILocs(kZ)).theta  ];
			fXY        = 0.5 / max( min( 1, max( topoRadius ) * 1.02 ), 0.5 );		% topoplot.m squeeze factor
			topoX      =  topoRadius .* cosd( topoTheta ) * fXY;
			topoY      = -topoRadius .* sind( topoTheta ) * fXY;
			kThresh    = [ Z{kZ,2,iZ} ] > zThresh;
			% this was w/ nose @ +Y
% 			line(  topoX(kThresh), topoY(kThresh), repmat( 10.5, 1, sum(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )
			line( -topoY(kThresh), topoX(kThresh), repmat( 10.5, 1, sum(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )

			colorbar%( 'southoutside' );
		end
		if ~isempty( Z )
			zStr = '';
			for i = 1:size( zRange, 1 )
				if all( zRange(i,:) == [ 25, 75 ] )
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
	topoOpts{10} = [ 0, pLimit ];
	if figLayout == 1
		hAx(2) = subplot( 3, 2, 2 );
	else
		figure( hFig(2) )
	end
		topoplot( pLineMax, chanLocs(1:63), topoOpts{:} );
	
		topoRadius = [ chanLocs(1:63).radius ];
		topoTheta  = [ chanLocs(1:63).theta  ];
		fXY        = 0.5 / max( min( 1, max( topoRadius ) * 1.02 ), 0.5 );		% topoplot.m squeeze factor
		topoX      =  topoRadius .* cosd( topoTheta ) * fXY;
		topoY      = -topoRadius .* sind( topoTheta ) * fXY;
		kThresh    = pLineMax > pLimit;
% 		line(  topoX(kThresh), topoY(kThresh), repmat( 10.5, 1, sum(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )
		line( -topoY(kThresh), topoX(kThresh), repmat( 10.5, 1, sum(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )
	
		colorbar%( 'southoutside' );
			text( 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.35, 0.95, 0 ],...
				'FontSize', 12, 'String', sprintf( [	'Min. = %0.1f\n',...
														'Max. = %0.1f\n',...
														'Median = %0.1f\n',...
														'# > %g %% = %d / %d' ],...
				min(pLineMax), max(pLineMax), median(pLineMax), pLimit, sum(pLineMax>pLimit), numel(pLineMax) ) )
	
	% 3. Response rates
	if figLayout == 1
		hAx(3) = subplot( 3, 3, 4 );
	else
		figure( hFig(3) )
	end
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
	if figLayout == 1
		hAx(4) = subplot( 3, 3, 5 );
	else
		figure( hFig(4) )
	end
		RT   = respData(kResp,2) * 1e3;
		kVis = kVis(kResp);
		kAud = kAud(kResp);
		kHit = respData(kResp,1) == 1;		% target
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
	if figLayout == 1
		hAx(5) = subplot( 3, 3, 6 );
	else
		figure( hFig(5) )
	end
	if doRestSpectra
		% [0,30]Hz linear, [1,100]Hz log?
		switch 1	% 1 = EO & EC spectra, 2 = ratio, 3 = both
			case 1
%				kf = f > 0;
				kf = f >= 1 & f <= 100;
				if strcmp( restChan, 'Mean' )
					hLine = semilogy( f(kf), mean( eegEC(:,kf), 1 ), f(kf), mean( eegEO(:,kf), 1 ) );
				else
					iRest = find( strcmp( {chanLocs.labels}, restChan ) );
					hLine = semilogy( f(kf), eegEC(iRest,kf), f(kf), eegEO(iRest,kf) );
				end
				set( hLine(1), 'Color', cOrder(4,:) )
				set( hLine(2), 'Color', cOrder(5,:) )
				set( [
					text( 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Position', [ 0.95, 0.95 ],...
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
	if figLayout == 1
		hAx(6) = subplot( 3, 1, 3 );
		% Brain Products "Photo Sensor" is a photo diode
		% QCvars = { 'Run', taskInfo{1,2}{[ 1:3, 5:6 ],2}, 'VIS', 'TrgHit', 'NovelFA', 'OtherFA', 'Misc' };
% 		QCline1 = QCvars;
% 		QCline1 = { 'Run',  'Oddball',       '',      '',      'MMN',        '', 'Display',    'Hit',    'FA',         '', 'Misc' };
		QCline1 = {    'Run',       'OD',     'OD',    'OD',      'MMN',     'MMN', 'Display',    'Hit',    'FA',       'FA',    'Misc.' };
		QCline2 = { '(seq#)', 'Standard', 'Target', 'Novel', 'Standard', 'Deviant',   '(160)', 'Target', 'Novel', 'Standard', 'comments' };
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
				'Position', [ xTxt(iVar), 1+1/nSeq, 0 ], 'String', QCline1{iVar},...
				'FontSize', 12, 'FontWeight', 'normal', 'FontName', 'Courier' )			
			text( 'Units', 'normalized', 'HorizontalAlignment', hAlign, 'VerticalAlignment', 'top',...
				'Position', [ xTxt(iVar), 1+0/nSeq, 0 ], 'String', QCline2{iVar},...
				'FontSize', 12, 'FontWeight', 'normal', 'FontName', 'Courier' )			
			for iSeq = 1:nSeq
				switch QCstatus(iSeq,iVar)
					case 2
						colorStr = goodColor;
					case 1
						colorStr =   okColor;
					otherwise
						colorStr =  badColor;
				end
				text( 'Units', 'normalized', 'HorizontalAlignment', hAlign, 'VerticalAlignment', 'top',...
					'Position', [ xTxt(iVar), 1-iSeq/nSeq, 0 ], 'String', [ colorStr, QCtable{iSeq,iVar} ],...
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
	else
		figure( hFig(6) )
		bar( 1:7,  [ dpdashData{[6:10,12,14],3} ] )
		hold on
		bar( 6:7, -[ dpdashData{[     11,13],3} ] )
		hold off
		set( hAx(6), 'XTick', 1:7, 'XTickLabel', { 'VODMMN', 'AOD', 'ASSR', 'RestEO', 'RestEC', 'Event', 'Sensor' }, 'XTickLabelRotation', 45 )
		deltaMax = max( abs( [ dpdashData{6:14,3} ] ) );
		if deltaMax ~= 0
			set( hAx(6), 'YLim', [ -1, 1 ] * deltaMax * 1.05 )
		end
	end

	set([
		title(  hAx(1), sprintf( '%s\n\\fontsize{12}%s', subjId, sessDate ), 'Visible', 'on' )
		ylabel( hAx(1), sprintf( 'Recording %d / %d', iZ, nZ ), 'Visible', 'on' )
		xlabel( hAx(1), 'Impedance (k\Omega)', 'Visible', 'on' )

		xlabel( hAx(2), sprintf( 'Power @ %g Hz (%%)', fLine ), 'Visible', 'on' )

		ylabel( hAx(3), 'Response Rate (%)' )

		xlabel( hAx(4), 'Target Reaction Time (ms)' )

% 		ylabel( hAx(5), [ restChan, ' Amplitude (\muV)' ] )
		ylabel( hAx(5), [ restChan, ' Power (\muV^2)' ] )
% 		ylabel( hAx(5), { 'EC / EO'; [ restChan, ' Amplitude' ] } )
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
	set( hAx(3:5), 'FontSize', 12 )			% this is changing x & y labels too! not just tick labels
	set( hAx([3 5]), 'YGrid', 'on' )
	set( hAx(4), 'XGrid', 'on' )
	
	if figLayout == 2
% 		ylabel( hAx(6), 'Unexpected Counts', 'FontSize', fontSize, 'FontWeight', fontWeight )
		ylabel( hAx(6), '\Delta#', 'FontSize', fontSize, 'FontWeight', fontWeight )
		set( hAx(6), 'Position', [ 0.2, 0.3, 0.75, 0.65 ], 'FontSize', 12 )			% this is changing x & y labels too! not just tick labels
		set( get( hAx(1), 'Title' ), 'String', '' )
		% topoplot changes some things
		set( hFig(1:2), 'Color', 'w' )
		set(  hAx(1:2), 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] )
% 		disp( QCtable )
	end


	pngDir = fullfile( sessDir, 'Figures' );				% keep everything organized by site/subject/session for BWH
% 	pngDir = fullfile( AMPSCZdir, 'Figures', 'QC' );		% write all sessions in 1 common directory for ease of local analysis
	if legacyPaths
		pngDir = fullfile( sessDir, 'Figures', 'QC' );
	end
	if ~isfolder( pngDir )
		mkdir( pngDir )
		fprintf( 'created %s\n', pngDir )
	end

	if figLayout == 1

		figure( hFig )
%		drawnow
		pause( 0.010 )		% figure renders OK 1 at a time, but png had text in wrong place?
%		return

		pngOut = fullfile( pngDir, [ subjId, '_', sessDate, '_QC.png' ] );		% [ subjTag(5:end), '_', sessTag(5:end), '_QC.png' ]
		if isempty( writeFlag )
			writePng = exist( pngOut, 'file' ) ~= 2;
			if ~writePng
				writePng(:) = strcmp( questdlg( [ 'Replace ', subjId, ' ', sessDate, ' QC png?' ], mfilename, 'no', 'yes', 'no' ), 'yes' );
			end
		else
			writePng = writeFlag;
		end
		if writePng
%			print( hFig, pngOut, '-dpng' )		% 1800x1000 figure window becomes 2813x1563
%			saveas( hFig, pngOut, 'png' )		% 1800x1000 figure window becomes 2813x1563
%			getframe( hFig )					% 1800x1000 figure window has     3600x2000 cdata
			figPos = get( hFig, 'Position' );		% is this going to work on BWH cluster when scheduled w/ no graphical interface?
			img = getframe( hFig );
			img = img.cdata;
			if size( img, 1 ) ~= figPos(4)
				img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
			end
%			size( img )
			imwrite( img, pngOut, 'png' )
			fprintf( 'wrote %s\n', pngOut )
		end
		
	else
		
		%              1            2            3                   4               5            6
		figSuffix = { 'impedance', 'lineNoise', 'responseAccuracy', 'responseTime', 'restAlpha', 'counts' };
		htmlFile  = fullfile( pngDir, [ subjId, '_', sessDate, '_QC.html' ] );
		writeHtml = exist( htmlFile, 'file' ) ~= 2;
		for iFig = 1:nFig
			pngOut = fullfile( pngDir, [ subjId, '_', sessDate, '_QC', figSuffix{iFig}, '.png' ] );		% [ subjTag(5:end), '_', sessTag(5:end), '_QC.png' ]
			if isempty( writeFlag )
				writePng = exist( pngOut, 'file' ) ~= 2;
				if ~writePng
					writePng(:) = strcmp( questdlg( [ 'Replace ', subjId, ' ', sessDate, ' QC png?' ], mfilename, 'no', 'yes', 'no' ), 'yes' );
				end
			else
				writePng = writeFlag;
			end
			if writePng
				figPos = get( hFig(iFig), 'Position' );		% is this going to work on BWH cluster when scheduled w/ no graphical interface?
				img = getframe( hFig(iFig) );
				img = img.cdata;
				if size( img, 1 ) ~= figPos(4)
					img = imresize( img, figPos(4) / size( img, 1 ), 'bicubic' );		% scale by height
				end
				imwrite( img, pngOut, 'png' )
				fprintf( 'wrote %s\n', pngOut )
				writeHtml(:) = true;
			end
		end
		% write html file
		if writeHtml && ( isempty( writeFlag ) || writeFlag )
			[ fid, msg ] = fopen( htmlFile, 'w' );
			if fid == -1
				error( msg )
			end
			fprintf( fid, '<!DOCTYPE html>\n' );
			fprintf( fid, '<html lang="en">\n' );
			fprintf( fid, '<head>\n' );
			fprintf( fid, '\t<meta charset="UTF-8">\n' );
			fprintf( fid, '\t<title>%s %s QC</title>\n', subjId, sessDate );
			fprintf( fid, '\t<style>\n' );
			fprintf( fid, '\t\tdiv { min-width: 1200px; margin-bottom: 40px; }\n' );
			fprintf( fid, '\t</style>\n' );
			fprintf( fid, '</head>\n' );
			fprintf( fid, '<body>\n' );
			fprintf( fid, '\t<div style="padding-left: 50px; font-size: 2.5em;">\n' );
			fprintf( fid, '\t\t%s<br>%s\n', subjId, sessDate );
			fprintf( fid, '\t</div>\n' );
			fprintf( fid, '\t<div>\n' );
			fprintf( fid, '\t\t<img src="%s_%s_QCimpedance.png" alt="impedance"  width="525" height="250">\n', subjId, sessDate );
			fprintf( fid, '\t\t<img src="%s_%s_QClineNoise.png" alt="line noise" width="525" height="250">\n', subjId, sessDate );
			fprintf( fid, '\t</div>\n' );
			fprintf( fid, '\t<div>\n' );
			fprintf( fid, '\t\t<img src="%s_%s_QCresponseAccuracy.png" alt="accuracy"      width="350" height="250">\n', subjId, sessDate );
			fprintf( fid, '\t\t<img src="%s_%s_QCresponseTime.png"     alt="reaction time" width="350" height="250">\n', subjId, sessDate );
			fprintf( fid, '\t\t<img src="%s_%s_QCrestAlpha.png"        alt="spectra"       width="350" height="250">\n', subjId, sessDate );
			fprintf( fid, '\t</div>\n' );
			fprintf( fid, '\t<div>\n' );
			fprintf( fid, '\t\t<img src="%s_%s_QCcounts.png"           alt="counts"        width="350" height="250">\n', subjId, sessDate );
			fprintf( fid, '\t</div>\n' );
			fprintf( fid, '</body>\n' );
			fprintf( fid, '</html>\n' );
			if fclose( fid ) == -1
				warning( 'MATLAB:fcloseError', 'fclose error' )
			end
			fprintf( 'wrote %s\n', htmlFile )
		end

	end
	
	return
	
%%	update QC figures
%

		% e.g.
		clear

		writeFlag   = [];
		figLayout   = 2;	% 1 = 1 png, multi-panel; 2 = 5 pngs, single-panel
		writeDpdash = [];
		legacyPaths = false;

		seg  = AMPSCZ_EEG_findProcSessions;
		nSeg = size( seg, 1 );
		
		AMPSCZdir = AMPSCZ_EEG_paths;
		if figLayout == 2
			figSuffix = { 'impedance', 'lineNoise', 'responseAccuracy', 'responseTime', 'restAlpha', 'counts' };
		else
			figSuffix = { '' };
		end
		nFig = numel( figSuffix );
		kSeg = true( 1, nSeg );
		for iSeg = 1:nSeg
			for iFig = 1:nFig
				QCfigs = dir( fullfile( AMPSCZdir, seg{iSeg,1}(1:end-2), 'PHOENIX', 'PROTECTED', seg{iSeg,1},...
					'processed', seg{iSeg,2}, 'eeg', [ 'ses-', seg{iSeg,3} ], 'Figures', [ '*_QC', figSuffix{iFig}, '.png' ] ) );
				if isempty( QCfigs )
					kSeg(iSeg) = false;
					break
				end
			end
		end
		seg  = seg(~kSeg,:);
		nSeg = size( seg, 1 );

		if figLayout == 2
			for iSeg = 1:nSeg
				close all
				AMPSCZ_EEG_QC( [ seg{iSeg,2}, '_', seg{iSeg,3} ], writeFlag, figLayout, writeDpdash, legacyPaths )
			end
		else
			AMPSCZ_EEG_QC( strcat( seg(:,2), '_', seg(:,3) ), writeFlag, figLayout, writeDpdash, legacyPaths )
		end
		
		fprintf( 'done\n' )
%
%%

end

