function AMPSCZ_EEG_unzip
% Starts with AMPSCZ EEG zip file(s), 
% segments them by run and saves BIDS-format files in a PHOENIX folder structure
% No sidecar files added yet, see AMP_SCZ_BIDSsidecars.m
%
% Usage:
% >> AMPSCZ_EEG_unzip
% 
% dependencies:
%	listZipContents.m
%	AMPSCZ_EEG_siteNames.m
%	AMPSCZ_EEG_taskSeq.m
%	bieegl_readBVtxt.m
%	bieegl_readBVdata.m
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 09/27/2021


% To do:
% use checksum digit?
% make a separate bieegl_writeBVtext function? 
% add in a dialog to overwrite paritially extracted zip files?  can we allow anything interactive in this pipeline?
% stop logging stuff that's already been done! - done.  create some sort of sheet where you can look for previous processing status? - undone

% 	error( 'Needs to be modified for BWH paths & latest PHOENIX organization' )

	try

		narginchk( 0, 0 )
		
		verbose = true;
		debug   = false;

		AMPSCZdir = '/data/predict/kcho/flow_test';
		if ~isfolder( AMPSCZdir )
			error( 'Invalid project directory' )
		end
		siteInfo  = AMPSCZ_EEG_siteInfo;
		nSite     = size( siteInfo, 1 );
% 		subGroups = unique( siteInfo(:,2) );
% 		nGroup    = numel( subGroups );

		[ taskInfo, taskSeq ] = AMPSCZ_EEG_taskSeq;
		rawExts = { '.vhdr', '.vmrk', '.eeg', '.txt' };
		nTask     = size( taskInfo, 1 );
		nSeq      = numel( taskSeq );			% total #tasks with repeats, not number of unique tasks
		nExt      = numel( rawExts );
% 		rawExist  = false( 1, nExt );
		testCodes = cellfun( @(u) u{1,1}, taskInfo(:,2), 'UniformOutput', true );		% used to identify task for recording segment

		% for segmented BV files that exist already, echo to command window too?
% 		segFileLogFcn = @writeToLog;
		segFileLogFcn = @writeToLogNoEcho;

		if verbose
			fprintf( '\n' )
		end
		for iSite = 1:nSite
			
			siteName  = siteInfo{iSite,1};
			siteGroup = siteInfo{iSite,2};
			if verbose
				fprintf( [ '\n%s ', repmat( '=', [ 1, 80-1-numel(siteName) ] ), '\n' ], siteName )
			end

			% Check if site has existing PROTECTED raw directory
			siteDir = fullfile( AMPSCZdir, siteGroup, 'PHOENIX', 'PROTECTED', [ siteGroup, siteName ] );
			rawDir  = fullfile( siteDir, 'raw' );
			if ~isfolder( rawDir )		% windows isfolder/isdir aren't case-sensitive
				if verbose
					fprintf( '\nsite %s/raw not found\n', [ siteGroup, siteName ] )
				end
				continue
			end
			procDir = fullfile( siteDir, 'processed' );
			if ~isfolder( procDir )
				if ~debug
					mkdir( procDir )
				elseif verbose
					fprintf( 'created %s\n', procDir )
				end
			end

			% Scan for valid subject directories
			subjDirs = dir( rawDir );
			% directories only
			subjDirs(~[subjDirs.isdir]) = [];
			% valid names only
			subjDirs(cellfun( @isempty, regexp( { subjDirs.name }, [ siteName, '\d{5}$' ], 'start', 'once' ) )) = [];
			% eeg sub-directories only
			subjDirs(cellfun( @exist, fullfile( rawDir, { subjDirs.name }, 'eeg' ), 'UniformOutput', true ) ~= 7) = [];
			nSubj = numel( subjDirs );

			for iSubj = 1:nSubj

				% zip files expected to each contain 4 files
				% each with the identical name as the zip file except for the extensions
				% .eeg, .vhdr, .vmrk (brain vision core format) and .txt
				% data and header are mandatory for BV, marker file is not
				zipFiles = dir( fullfile( rawDir, subjDirs(iSubj).name, 'eeg', '*.zip' );		% could use subjDirs(isubj).folder
				% throw out illegal filenames
				% make sure to allow for session coming in as multiple zips
				% allow lower case site codes?
				zipFiles( cellfun( @isempty, regexp( { zipFiles.name }, [ '^[', siteName(1), lower( siteName(1) ), '][',...
					siteName(2), lower( siteName(2) ), ']\d{5}_eeg_\d{8}_?\d*.zip$' ], 'start', 'once' ) ) ) = [];

				% check for multiple zip-files per session, i.e. ignore any trailing _# in the file names
				% unique session names
				sessionName  = unique( cellfun( @(u)[upper(u(1:2)),u(3:20)], { zipFiles.name }, 'UniformOutput', false ) );
				nSession     = numel( sessionName );
				
				for iSession = 1:nsession
					
					outputDir = fullfile( procDir, subjDirs(iSubj).name, 'eeg', [ 'ses-', sessionName{iSession}(13:20) ] );
					if ~isfolder( outputDir )
						if ~debug
							% note: mkdir can create directories in parents that don't yet exist
							mkdir( outputDir )
						elseif verbose
							fprintf( 'created %s\n', outputDir )
						end
					end
					
					% Check status
					statusFile = fullfile( outputDir, [ '.', sessionName{iSession}, '.status' ] );
					if exist( statusFile, 'file' ) == 2
						[ fidStatus, errMsg ] = fopen( statusFile, 'r' );
						if fidStatus == -1
							error( errMsg )
						end
						char1 = fread( fidStatus, 1, 'char' );		% read as double.  you'll get empty output w/ empty file, not error
						if strcmp( char1, '3' )
							fidStatus(:) = fclose( fidStatus );
							if fidStatus == -1
							end
							if verbose
								fprintf( '%s unzipped/segmetned previously\n', sessionName{iSession} )
							end
							continue
						end
					else
						[ fidStatus, errMsg ] = fopen( statusFile, 'w' );
						if fidStatus == -1
							error( errMsg )
						end
						char1 = abs( '0' );		% 48
					end
					
					% Unzip
					if char1 == abs( '0' )
						% current session's zip file(s)
						Izip = find( strncmpi( { zipFiles.name }, sessionName{iSession}, 20 ) );
						nZip = numel( Izip );

						baseName = '';
						kBadZip  = false( 1, nZip );
						for iZip = 1:nZip
							% Check zip-file content
							% e.g. 'Vision/Raw Files/XX#####_eeg_YYYYYMMDD.eeg' ...
							zipContent = listZipContents( fullfile( zipFiles(Izip(iZip)).folder, zipFiles(Izip(iZip)).name ) );		% #x1 cell array, relative to zipFile parent directory
							% -- check for existence of unzipped files
							unzipCheck = cellfun( @(u)exist(u,'file')==2, fullfile( outputDir, zipContent ) );
							[ zipContentPath, zipContentFile, zipContentExt ] = fileparts( zipContent );	% extensions include initial '.'
							if all( unzipCheck )
								if isempty( baseName )
									baseName    = zipContentFile{1}(1:20);			% what's more reliable zip-file name or contents?
									subDir      = zipContentPath{1};
								end
								if verbose
									fprintf( 'zip-file already extracted\n' )
								end
								fseek( fidStatus, 0, 'bof' )
								fprintf( fitStatus, '%d unzipped %s', 1, datestr( now, 'yyyymmddTHHMMSS' ) )
								continue
							elseif any( unzipCheck )
								kBadZip(iZip) = true;		% not necessarily a bad zip file?, partially deleted?
								if verbose
									writeToLog( 'zip-file partially extracted\n' )
								end
% 								continue
							end
							% -- path tests
							if ~all( strcmp( zipContentPath, zipContentPath{1} ) )
								kBadZip(iZip) = true;
								if verbose
									fprintf( 'inconsistent paths in zip-file contents\n' )
								end
								fseek( fidStatus, 0, 'bof' )
								fprintf( fitStatus, '%d inconsistent paths in zip file %s', 0, datestr( now, 'yyyymmddTHHMMSS' ) )
								continue
							end
							if ~strcmp( zipContentPath{1}, 'Vision/Raw Files' )
								if verbose
									fprintf( 'WARNING: unexpected zip-file path %s\n', zipContentPath{1} )
								end
							end
							
							error( 'left off here' )
							
							% -- filename tests
		% 					if numel( zipContentFile{1} ) < 20
		% 						kBadZip(iZip) = true;
		% 						writeToLog( 'zip file content name too short\n' )
		% 						continue
		% 					end
							% checking them all here will imply length >= 20 & is redundant with check below
							if ~all( strcmp( zipContentFile, zipFiles(Izip(iZip)).name(1:end-4) ) )
								kBadZip(iZip) = true;
								writeToLog( 'zip file content name doesn''t match zip file name\n' )
								continue
							end
							%    this wouldn't necessarily be a problem, but is part of ProNET data specifications
		% 					if ~all( strncmp( zipContentFile, zipContentFile{1}(1:20), 20 ) )
		% 						writeToLog( 'inconsistent file names in zip-file contents\n' )
		% 					end
							% -- extension tests
							if ~all( ismember( { '.eeg', '.vhdr', '.vmrk' }, zipContentExt ) )		% can tolerate missing .txt?
								kBadZip(iZip) = true;
								writeToLog( 'zip file missing critical file(s)\n' )
								continue
							end
							if ~ismember( '.txt', zipContentExt )
								writeToLog( 'zip file missing .txt file\n' )
							end
							if numel( zipContent ) ~= nExt
		% 						error( '# files in %s ~= %d', zipFile, nExt )
								writeToLog( '# files in %s ~= %d\n', zipFile, nExt )
							end
							if ~all( ismember( zipContentExt, rawExts ) )
								writeToLog( 'unexpected extension(s) in zip-file content\n' )
							end

							% -- store some parameters for 1st zip file in each session
		% 					if iZip == 1
							if isempty( baseName )
								baseName    = zipContentFile{1}(1:20);			% what's more reliable zip-file name or contents?
								subDir      = zipContentPath{1};
							end

							% -- check for existence of unzipped files
		% 					for iExt = 1:nExt
		% 						rawExist(iExt) = exist( fullfile( rawDir, subDir, [ zipFiles(Izip(iZip)).name(1:end-4), rawExts{iExt} ] ), 'file' ) == 2;
		% 					end
		% 					if all( rawExist )
		% 						writeToLog( 'zip-file already extracted\n' )
		% 						continue
		% 					elseif any( rawExist )
		% 						error( 'partially-extracted zip file? %s\n', zipFile )
		% 					end

							% checks across zips
							if ~all( strcmp( zipContentPath, subDir ) )
								kBadZip(iZip) = true;
								writeToLog( 'inconsistent paths in zip-file contents\n' )
								continue
							end
							if ~all( strncmp( zipContentFile, baseName, 20 ) )
								kBadZip(iZip) = true;
								writeToLog( 'inconsistent file names in zip-file contents\n' )
								continue
							end

							% Unzip
							writeToLog( 'extracting %s...', zipFile )
							tic
							unzip( zipFile, rawDir )
							writeToLog( ' done.  (%0.3f sec)\n', toc )

						end		% zip-file loop #1 (unzip)

					end
					
					% Segment
					if ismember( char1, abs( '01' ) )
					end
					
					% Add Sidecars.  
					% if char1 == abs('3') you would have continued already

				end

			end
			
			rawDir     = fullfile( AMPSCZdir, siteInfo{iSite,1}, 'raw' );
			bidsDir    = fullfile( AMPSCZdir, siteInfo{iSite,1}, 'BIDS' );




			for iSession = 1:nSession

				% this was to avoid updating log file @ all, but required everything to be 100% perfect
				% how about storing string as you go, and only write to log file if any new segmented files get created?


			
				
				if any( kBadZip )
					Izip(kBadZip) = [];
					nZip(:) = numel( Izip );
					if nZip == 0
						continue		% skip to next session
					end
					kBadZip = false( 1, nZip );
				end
			
				% For each triplet/quadruplet of BrainVision files...
				writeToLog( 'Reading ProNET event markers from Brain Vision files\n' )
				H = struct( 'Common', cell( 1, nZip ), 'Binary', [], 'Channel', [], 'Coordinates', [], 'Comment', [], 'inputFile', '' );
				M = struct( 'Common', cell( 1, nZip ), 'Marker', [], 'inputFile', '' );

				ImarkerSeg =  cell( 1, nZip );
				for iZip = 1:nZip

					% Read BrainVision Header File
					H(iZip) = bieegl_readBVtxt( fullfile( rawDir, subDir, [ zipFiles(Izip(iZip)).name(1:end-4), '.vhdr' ] ), struct( 'convertResolution', false ) );
					if ~strcmp( H(iZip).Common.MarkerFile, [ zipFiles(Izip(iZip)).name(1:end-4), '.vmrk' ] )
						kBadZip(iZip) = true;
						writeToLog( 'header/marker file mismatch\n' )
						continue
					end
					if ~strcmp( H(iZip).Common.DataFile  , [ zipFiles(Izip(iZip)).name(1:end-4), '.eeg' ] )
						kBadZip(iZip) = true;
						writeToLog( 'header/data file mismatch\n' )
						continue
					end

					% Read BrainVision Marker File
					M(iZip) = bieegl_readBVtxt( fullfile( rawDir, subDir, H(iZip).Common.MarkerFile ) );
					if ~strcmp( M(iZip).Common.DataFile, H(iZip).Common.DataFile )
						kBadZip(iZip) = true;
						writeToLog( 'marker/header data file mismatch\n' )
						continue
					end

					% Task segment indices, note: LostSamples events are of 'New Segment' type but have non-empty descriptions
					ImarkerSeg{iZip} = find( strcmp( { M(iZip).Marker.Mk.type }, 'New Segment' ) & cellfun( @isempty, { M(iZip).Marker.Mk.description } ) );

				end		% zip-file loop #2 (read BV text files)
				
				if any( kBadZip )
					if all( kBadZip )
						continue
					end
					H(kBadZip) = [];
					M(kBadZip) = [];
					ImarkerSeg(kBadZip) = [];
					nZip(:) = numel( H );
% 					kBadZip = false( 1, nZip );
					clear kBadZip
				end

%				siteCode    = baseName(1:2);
				subjCode    = [ 'sub-', upper( baseName(1:2) ), baseName(3:7) ];
				sessionCode = [ 'ses-', baseName(13:20) ];
% 				checkSum    =           baseName(7);

				nSegment = cellfun( @numel, ImarkerSeg );
				if sum( nSegment ) ~= nSeq
% 					error( '# segments (%d) ~= # tasks (%d)', sum( nSegment ), nSeq )
 					writeToLog( '# segments (%d) ~= # tasks (%d)\n', sum( nSegment ), nSeq )
				end

				iSeq = 0;
				ImarkerEnd = cell( 1, nZip );
				Itask      = cell( 1, nZip );

				% SEGMENT BY TASK ======================================================
				writeToLog( 'Testing ProNET task segments\n' )
				for iZip = 1:nZip

					ImarkerEnd{iZip} = zeros( 1, nSegment(iZip) );
					Itask{iZip}      = zeros( 1, nSegment(iZip) );

					for iSegment = 1:nSegment(iZip)

						% range of markers to evaluate, not range of time points
						% includes 'New Segment' markers
						if iSegment == nSegment(iZip)
							ImarkerEnd{iZip}(iSegment) = numel( M(iZip).Marker.Mk );			% last marker in the series
						else
							ImarkerEnd{iZip}(iSegment) = ImarkerSeg{iZip}(iSegment+1) - 1;		% one before the next segment starts
						end
						ImarkerRange = ImarkerSeg{iZip}(iSegment):ImarkerEnd{iZip}(iSegment);
						kLostSamples = strncmp( { M(iZip).Marker.Mk(ImarkerRange).description }, 'LostSamples:', 12 );
						if any( kLostSamples )
							writeToLog( '%d epochs of lost samples, %s segment %d\n', sum( kLostSamples ), zipFiles(Izip(iZip)).name, iSegment )
							ImarkerRange(kLostSamples) = [];
						end

						% verify expected event coding 'S  #', 'S ##', or 'S###'
						eventCode = regexp( { M(iZip).Marker.Mk(ImarkerRange(2:end)).description }, '^S[ ]*(\d+)$', 'tokens', 'once' );
						if any( cellfun( @isempty, eventCode ) )
% 							error( 'Unexpected Marker description(s), can''t identify event code' )
							writeToLog( 'Unexpected Marker description(s), can''t identify event code\n' )
							continue
						end
						% convert char codes to numeric
% 						eventCode = cellfun( @eval, [ eventCode{:} ] );
						eventCode = cellfun( @str2double, [ eventCode{:} ], 'UniformOutput', true );

						% identify task by presence of 1st code in taskInfo
% 						iTaskType = cellfun( @(u) ismember( u{1,1}, eventCode ), taskInfo(:,2) );
						iTaskType = ismember( testCodes, eventCode );
						switch sum( iTaskType )
							case 1
								% make sure all event codes in segment are valid for current task segment
								if ~all( ismember( eventCode, [ taskInfo{iTaskType,2}{:,1} ] ) )
% 									error( 'Unexpected events in task segment' )
									writeToLog( 'Unexpected events in task segment\nunique codes =' )
									writeToLog( ' %d', unique( eventCode(:) )' )
									writeToLog( '\n' )
									continue		% segment loop
								end
								% index into taskInfo cell array
								Itask{iZip}(iSegment) = find( iTaskType );
								iSeq(:) = iSeq + 1;
								% verify expected task sequence
								if iSeq > nSeq
									writeToLog( 'Longer than expected task sequence %d = %s\n', iSeq, taskInfo{Itask{iZip}(iSegment),1} )
								elseif Itask{iZip}(iSegment) ~= taskSeq(iSeq)
%									error( 'Unexpected task sequence' )
									writeToLog( 'Unexpected task sequence %d = %s\n', iSeq, taskInfo{Itask{iZip}(iSegment),1} )
								end
							case 0
								writeToLog( 'Can''t identify task, none of codes' )
								writeToLog( ' %d', testCodes )
								writeToLog( ' found\nunique codes =' )
								writeToLog( ' %d', unique( eventCode(:) )' )
								writeToLog( '\n' )
							otherwise
								writeToLog( 'Can''t identify task, multiples task codes' )
								writeToLog( ' %d', testCodes(iTaskType) )
								writeToLog( ' found\nunique codes =' )
								writeToLog( ' %d', unique( eventCode(:) )' )
								writeToLog( '\n' )
						end

					end		% segment loop
					
				end		% zip-file loop #3 get test segments
				
				% round #runs for each task over all zip files
				nRun  =  histcounts( categorical(    taskSeq  , 1:nTask ) );				% expected #runs for each task
				if ~all( histcounts( categorical( [ Itask{:} ], 1:nTask ) ) == nRun )		% #runs found in data files, OK to have zeros in Itask here
% 					error( 'Unexpected number(s) of task runs' )
					writeToLog( 'Unexpected number(s) of task runs\n' )
				end

% 				writeToLog( 'Saving Brain Vision data segmented into %d runs\n', nSeq )
				writeToLog( 'Saving Brain Vision data segmented into %d runs\n', iSeq )
				outputDir = bidsDir;
				if ~isfolder( outputDir )
					mkdir( outputDir )
					writeToLog( 'Created directory %s\n', outputDir )
				end
				outputDir = fullfile( outputDir, subjCode );
				if ~isfolder( outputDir )
					mkdir( outputDir )
					writeToLog( 'Created directory %s\n', outputDir )
				end
				outputDir = fullfile( outputDir, sessionCode );
				if ~isfolder( outputDir )
					mkdir( outputDir )
					writeToLog( 'Created directory %s\n', outputDir )
				end
				outputDir = fullfile( outputDir, 'eeg' );
				if ~isfolder( outputDir )
					mkdir( outputDir )
					writeToLog( 'Created directory %s\n', outputDir )
				end

				% zero nRun so it can be reused as running count
				nRun(:) = 0;
				for iZip = 1:nZip

					% Read BrainVision Data File
					D = bieegl_readBVdata( H(iZip), fullfile( rawDir, subDir ) );
					for iSegment = 1:nSegment(iZip)

						% add task and run info to output file name
						iTask = Itask{iZip}(iSegment);
						if iTask == 0
							break
						end
						nRun(iTask) = nRun(iTask) + 1;
						outputSegment = sprintf( '%s_%s_task-%s_run-%02d_eeg', subjCode, sessionCode, taskInfo{iTask,1}, nRun(iTask) );

						% WRITE OUTPUT FILES
						% HEADER -----------------------------------------------------------
						outputFile = fullfile( outputDir, [ outputSegment, '.vhdr' ] );
						Hout = H(iZip);		% you need Hout even if not writing .vhdr
						Hout.Common.DataFile   = [ outputSegment, '.eeg'  ];
						Hout.Common.MarkerFile = [ outputSegment, '.vmrk' ];
						if exist( outputFile, 'file' ) == 2
							segFileLogFcn( '%s exists, not replacing\n', outputFile )
						else
							writeToLog( 'writing %s...', outputFile )

							[ fid, msg ] = fopen( outputFile, 'w' );
							if fid == -1
								error( msg )
							end
							fprintf( fid, 'BrainVision Data Exchange Header File Version 1.0\r\n' );
							fprintf( fid, '; BrainVision Data segmented by tasks by BIEEGL\r\n' );

							% Header-Common
							fn1 = 'Common';
							fprintf( fid, '\r\n[%s Infos]\r\n', fn1 );
							fprintf( fid, '; Data orientation: MULTIPLEXED=ch1,pt1, ch2,pt1 ...\r\n' );
							fprintf( fid, '; Sampling interval in microseconds\r\n' );
							for fn2 = fieldnames( Hout.(fn1) )'
								if ischar( Hout.(fn1).(fn2{1}) )
									fmt = '%s';
								elseif isnumeric( Hout.(fn1).(fn2{1}) )
									if mod( Hout.(fn1).(fn2{1}), 1 ) == 0
										fmt = '%d';
									else
										fmt = '%f';
									end
								else
									fclose( fid );
									error( 'Unexpected %s class', fn2{1} )
								end
								fprintf( fid, [ '%s=', fmt, '\r\n' ], fn2{1}, Hout.(fn1).(fn2{1}) );
							end

							% Header-Binary
							fn1 = 'Binary';
							fprintf( fid, '\r\n[%s Infos]\r\n', fn1 );
							for fn2 = fieldnames( Hout.(fn1) )'
								if ischar( Hout.(fn1).(fn2{1}) )
									fmt = '%s';
								else
									fclose( fid );
									error( 'Unexpected %s class', fn2{1} )
								end
								fprintf( fid, [ '%s=', fmt, '\r\n' ], fn2{1}, Hout.(fn1).(fn2{1}) );
							end

							% Header-Channel
							fn1 = 'Channel';
							fprintf( fid, '\r\n[%s Infos]\r\n', fn1 );
							fprintf( fid, '; Each entry: Ch<Channel number>=<Name>,<Reference channel name>,\r\n' );
							fprintf( fid, '; <Resolution in "Unit">,<Unit>, Future extensions..\r\n' );
							fprintf( fid, '; Fields are delimited by commas, some fields might be omitted (empty).\r\n' );
							fprintf( fid, '; Commas in channel names are coded as "\\1".\r\n' );
							if ischar( Hout.(fn1).Ch(1).resolution )
								fmt = '%s';
							else
								fmt = '%f';
							end
							for iCh = 1:numel( Hout.(fn1).Ch )
								% what's the right format if unit was omitted?  no trailing comma?
								if isempty( Hout.(fn1).Ch(iCh).unit )
									fprintf( fid, [ 'Ch%d=%s,%s,', fmt,    '\r\n' ], iCh, Hout.(fn1).Ch(iCh).name, Hout.(fn1).Ch(iCh).reference, Hout.(fn1).Ch(iCh).resolution );
								else
									fprintf( fid, [ 'Ch%d=%s,%s,', fmt, ',%s\r\n' ], iCh, Hout.(fn1).Ch(iCh).name, Hout.(fn1).Ch(iCh).reference, Hout.(fn1).Ch(iCh).resolution, Hout.(fn1).Ch(iCh).unit );
								end
							end

							% Header-Coordinates
							fn1 = 'Coordinates';
							if ~isempty( Hout.(fn1).Ch )
								fprintf( fid, '\r\n[%s]\r\n', fn1 );
								for iCh = 1:numel( Hout.(fn1).Ch )
									fprintf( fid, 'Ch%d=%f,%f,%f\r\n', iCh, Hout.(fn1).Ch(iCh).radius, Hout.(fn1).Ch(iCh).theta, Hout.(fn1).Ch(iCh).phi );
								end
							end

							% Header-Comment
							fn1 = 'Comment';
							if ~isempty( Hout.(fn1) )
								fprintf( fid, '\r\n[%s]\r\n', fn1 );
								for iRow = 1:numel( Hout.(fn1) )
									fprintf( fid, '%s\r\n', Hout.(fn1){iRow} );		% trailing linefeeds gone
								end
							end

							if fclose( fid ) == -1
								warning( 'MATLAB:fcloseError', 'fclose error' )
							end

							writeToLog( ' done\n' )
						end

						% MARKER -----------------------------------------------------------
						outputFile = fullfile( outputDir, Hout.Common.MarkerFile );
						if exist( outputFile, 'file' ) == 2
							segFileLogFcn( '%s exists, not replacing\n', outputFile )
						else
							ImarkerRange = ImarkerSeg{iZip}(iSegment):ImarkerEnd{iZip}(iSegment);
							Mout = M(iZip);
							Mout.Common.DataFile = Hout.Common.DataFile;
							Mout.Marker.Mk       = Mout.Marker.Mk(ImarkerRange);
							% make marker positions relative to beginning of segment
							markerPos = [ Mout.Marker.Mk.position ];
							markerPos(:) = markerPos - ( markerPos(1) - 1 );
							markerPos = num2cell( markerPos );
							[ Mout.Marker.Mk.position ] = deal( markerPos{:} );

							writeToLog( 'writing %s...', outputFile )
							[ fid, msg ] = fopen( outputFile, 'w' );
							if fid == -1
								error( msg )
							end
							fprintf( fid, 'BrainVision Data Exchange Marker File Version 1.0\r\n' );

							% Marker-Common
							fn1 = 'Common';
							fprintf( fid, '\r\n[%s Infos]\r\n', fn1 );
							for fn2 = fieldnames( Mout.(fn1) )'
								if ischar( Mout.(fn1).(fn2{1}) )
									fmt = '%s';
								else
									fclose( fid );
									error( 'Unexpected %s class', fn2{1} )
								end
								fprintf( fid, [ '%s=', fmt, '\r\n' ], fn2{1}, Mout.(fn1).(fn2{1}) );
							end

							% Marker-Marker
							fn1 = 'Marker';
							fprintf( fid, '\r\n[%s Infos]\r\n', fn1 );
							fprintf( fid, '; Each entry: Mk<Marker number>=<Type>,<Description>,<Position in data points>,\r\n' );
							fprintf( fid, '; <Size in data points>, <Channel number (0 = marker is related to all channels)>\r\n' );
							fprintf( fid, '; Fields are delimited by commas, some fields might be omitted (empty).\r\n' );
							fprintf( fid, '; Commas in type or description text are coded as "\\1".\r\n' );
							for iMk = 1:numel( Mout.(fn1).Mk )
								if isempty( Mout.(fn1).Mk(iMk).date )
									fprintf( fid, 'Mk%d=%s,%s,%d,%d,%d\r\n'   , iMk, Mout.(fn1).Mk(iMk).type, Mout.(fn1).Mk(iMk).description, Mout.(fn1).Mk(iMk).position, Mout.(fn1).Mk(iMk).points, Mout.(fn1).Mk(iMk).channel );
								else
									fprintf( fid, 'Mk%d=%s,%s,%d,%d,%d,%s\r\n', iMk, Mout.(fn1).Mk(iMk).type, Mout.(fn1).Mk(iMk).description, Mout.(fn1).Mk(iMk).position, Mout.(fn1).Mk(iMk).points, Mout.(fn1).Mk(iMk).channel, Mout.(fn1).Mk(iMk).date );
								end
							end

							if fclose( fid ) == -1
								warning( 'MATLAB:fcloseError', 'fclose error' )
							end

							writeToLog( ' done\n' )
						end


						% DATA -------------------------------------------------------------
						outputFile = fullfile( outputDir, Hout.Common.DataFile );
						if exist( outputFile, 'file' ) == 2
							segFileLogFcn( '%s exists, not replacing\n', outputFile )
						else
							if iSegment == nSegment(iZip)
								iDataEnd = size( D, 2 );
							else
								iDataEnd = M(iZip).Marker.Mk(ImarkerSeg{iZip}(iSegment+1)).position - 1;
							end
							IdataRange = M(iZip).Marker.Mk(ImarkerSeg{iZip}(iSegment)).position:iDataEnd;
							writeToLog( 'writing %s...', outputFile )
							[ fid, msg ] = fopen( outputFile, 'w' );
							if fid == -1
								error( msg )
							end
							fwrite( fid, D(:,IdataRange), class( D ) );		% writes down column 1, before going to column 2 etc. in standard Matlab fashion
							if fclose( fid ) == -1
								warning( 'MATLAB:fcloseError', 'fclose error' )
							end
							writeToLog( ' done\n' )
						end

						% TEXT -------------------------------------------------------------
						% I'm not writing/copying text outputs, Neurosig Log File
						% they just have coarse time stamps of the operator event sequence (1 minute resolution)

					end		% segment loop

				end		% zip-file loop #4 write output files

				writeToLog( '%s finished @ %s\n\n\n', mfilename, datestr( now, 'yyyymmddTHHMMSS' ) )
				if fclose( fidLog ) == -1
					warning( 'MATLAB:fcloseError', 'fclose error' )
				end
				
				fidOk  = fopen( okFile, 'w' );
				if fidOk == -1
					error( 'Can''t open log file %s', okFile )
				end
				fprintf( fidOk, '%s completed %s w/o error', sessionName{iSession}, mfilename );
				if fclose( fidOk ) == -1
					warning( 'MATLAB:fcloseError', 'fclose error' )
				end

			end		% session loop

		end		% site loop

		return

	catch ME

		if exist( 'fidLog', 'var' ) == 1 && fidLog ~= -1 && ~isempty( fopen( fidLog ) )		% log file still open
			writeToLog( '%s\n', ME.message )
			if fclose( fidLog ) == -1
				warning( 'MATLAB:fcloseError', 'fclose error' )
			end
		end
		fclose( 'all' );		% close any open BV files
		rethrow( ME )

	end
	
	return
	
	function writeToLog( fmt, varargin )
		fprintf( fidLog, fmt, varargin{:} );
		fprintf(      1, fmt, varargin{:} )		% echo to command window
	end
	function writeToLogNoEcho( fmt, varargin )
		fprintf( fidLog, fmt, varargin{:} );
	end


end