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
% * use checksum digit? is this only used @ time of acquisition?
% * make a separate bieegl_writeBVtext function? 
% * create some sort of sheet where you can look for previous processing status? - undone
% * right now if there are multiple zip files for a single sesssion, and one or more is bad
%   then nothing will get segmented, even if the good one(s) contain everything needed to
%   continue.  a solution would be to delete the useless zip file, but there should be 
%   some test of the brain vision files to help determine this.
% * if zip files have no sub-folder structure, create the default?

% 	error( 'Needs to be modified for BWH paths & latest PHOENIX organization' )

	try

		narginchk( 0, 0 )

		verbose = true;

% 		AMPSCZdir = '/data/predict/kcho/flow_test';
		AMPSCZdir = 'C:\Users\donqu\Documents\NCIRE\AMPSCZ\';
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
% 		nExt      = numel( rawExts );
		testCodes = cellfun( @(u) u{1,1}, taskInfo(:,2), 'UniformOutput', true );		% used to identify task for recording segment
		nRun      =  histcounts( categorical( taskSeq, 1:nTask ) );						% expected #runs for each task

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
				zipFiles = dir( fullfile( rawDir, subjDirs(iSubj).name, 'eeg', '*.zip' ) );		% could use subjDirs(isubj).folder
				% throw out illegal filenames
				% make sure to allow for session coming in as multiple zips
				% allow lower case site codes?
				zipFiles( cellfun( @isempty, regexp( { zipFiles.name }, [ '^[', siteName(1), lower( siteName(1) ), '][',...
					siteName(2), lower( siteName(2) ), ']\d{5}_eeg_\d{8}_?\d*.zip$' ], 'start', 'once' ) ) ) = [];

				% check for multiple zip-files per session, i.e. ignore any trailing _# in the file names
				% unique session names
				sessionName  = unique( cellfun( @(u)[upper(u(1:2)),u(3:20)], { zipFiles.name }, 'UniformOutput', false ) );
				nSession     = numel( sessionName );

				for iSession = 1:nSession

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
					statusFile = fullfile( outputDir, [ '.', sessionName{iSession}, '_segment.status' ] );
					if exist( statusFile, 'file' ) == 2
						[ fidStatus, errMsg ] = fopen( statusFile, 'r+' );
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
						% for any status other than complete '3', need to start at the beginning?
						% e.g. to get baseName & subDir from unzip step.  don't worry, won't do un-needed overwrites.
						char1(:) = abs( '0' );
					else
						[ fidStatus, errMsg ] = fopen( statusFile, 'w' );
						if fidStatus == -1
							error( errMsg )
						end
						char1 = abs( '0' );		% 48
					end

					% Current session's valid zip file(s)
					IZip = find( strncmpi( { zipFiles.name }, sessionName{iSession}, 20 ) );
					nZip = numel( IZip );

					logFile = fullfile( outputDir, [ '.', sessionName{iSession}, '_segment.log' ] );		% datestr( now, 'YYYYMMDD' )
					[ fidLog, errMsg ] = fopen( logFile, 'w' );		% replace existing log files?  add a date stamp?  
					if fidLog == -1
						error( errMsg )
					end

					% Unzip
					if char1 == abs( '0' )		% this is always true until something more sophisticated is done later

						baseName  = '';
						zipStatus = zeros( 1, nZip );	% {0=needs extraction, 1=already extracted, -1=bad zip, don't extract
						for iZip = 1:nZip
							% Check zip-file content
							% e.g. 'Vision/Raw Files/XX#####_eeg_YYYYYMMDD.eeg' ...
							zipFile    = fullfile( zipFiles(IZip(iZip)).folder, zipFiles(IZip(iZip)).name );
							zipContent = listZipContents( zipFile );		% #x1 cell array, relative to zip file parent directory
							% -- check for existence of unzipped files
							unzipCheck = cellfun( @(u)exist(u,'file')==2, fullfile( outputDir, zipContent ) );
							[ zipContentPath, zipContentFile, zipContentExt ] = fileparts( zipContent );	% extensions include initial '.'
							if all( unzipCheck )
								zipStatus(iZip) = 1;
								writeToLog( verbose, '%s already extracted\n', zipFile )
								if isempty( baseName )
									baseName = zipContentFile{1}(1:20);		% what's more reliable zip-file name or contents?
									subDir   = zipContentPath{1};
								end
								continue
							elseif any( unzipCheck )
								% partially deleted zip content, re-extract?
								writeToLog( verbose, '%s partially extracted?\n', zipFile )
							end
							% -- path tests
							if ~all( strcmp( zipContentPath, zipContentPath{1} ) )
								zipStatus(iZip) = -1;
								writeToLog( verbose, '%s inconsistent paths in content\n', zipFile )
								continue
							elseif ~strcmp( zipContentPath{1}, 'Vision/Raw Files' )
								writeToLog( verbose, '%s unexpected zip-file path %s\n', zipFile, zipContentPath{1} )
							end
							% -- filename tests
							% zip file names already validated for expected format so length is guaranteed >= 20
							% check that content name matches file name
							if ~all( strcmp( zipContentFile, zipFiles(IZip(iZip)).name(1:end-4) ) )
								zipStatus(iZip) = -1;
								writeToLog( verbose, '%s content name doesn''t match zip file name\n', zipFile )
								continue
% 							elseif ~all( strncmp( zipContentFile, zipContentFile{1}(1:20), 20 ) )
% 								% check for internal file name consistency?
% 								% this wouldn't necessarily be a problem, but is part of AMPSCZ EEG data specifications
% 								% impossible to fail this test and pass the one above
% 								zipStatus(iZip) = -1;
% 								writeToLog( verbose, '%s inconsistent file names in content\n', zipFile )
% 								continue
							end
							% -- extension tests
							if ~all( ismember( { '.eeg', '.vhdr', '.vmrk' }, zipContentExt ) )		% can tolerate missing .txt?
								zipStatus(iZip) = -1;
								writeToLog( verbose, '%s missing critical file(s)\n', zipFile )
								continue
							elseif ~ismember( '.txt', zipContentExt )
								writeToLog( verbose, '%s missing .txt file\n', zipFile )
							end
							kValidExt = ismember( zipContentExt, rawExts );
							if ~all( kValidExt )
								writeToLog( verbose, '%s unexpected extension(s) in content\n', zipFile )
							end

							% checks across multiple zip fiels
							if isempty( baseName )		% i.e. not already unzipped and no erros
								baseName = zipContentFile{1}(1:20);
								subDir   = zipContentPath{1};
							else
								if ~all( strncmp( zipContentFile(kValidExt), baseName, 20 ) )
									zipStatus(iZip) = -1;
									writeToLog( verbose, '%s inconsistent file names across multiple zip files\n', zipFile )
									continue
								end
								if ~all( strcmp( zipContentPath(kValidExt), subDir ) )
									% *** make this a warning not an error? ***
									% if extracted files end up in different folders, there'll need to be logic
									% to find evertything before segmenting.  can't just use baseName & subDir.
									zipStatus(iZip) = -1;
									writeToLog( verbose, '%s inconsistent paths across multiple zip files\n', zipFile )
									continue
								end
							end

							% Unzip
							tic
							unzip( zipFile, outputDir )
							zipStatus(iZip) = 1;
							writeToLog( verbose, '%s unzipped (%0.3f sec)\n', zipFile, toc )

						end		% zip-file loop

						char1(:) = abs( '1' );
						fseek( fidStatus, 0, 'bof' );
						timeStr = datestr( now, 'yyyymmddTHHMMSS' );
						if all( zipStatus == 1 )
							fprintf( fidStatus, '%d %s [%s]', 1, 'unzipped', timeStr );
						else
							fprintf( fidStatus, '%d %s [%s]', 1, 'partially unzipped', timeStr );
% 							continue		% keep processing sessions w/ bad zips?
						end

					end		% Unzip if

					% Segment
					if ismember( char1, abs( '1' ) )
						IUnzipped  = IZip( zipStatus == 1 );
						nUnzipped  = numel( IUnzipped );
						ImarkerSeg = cell( 1, nUnzipped );
						% empty Brain Vision header & marker structres for bieegl_readBVtxt.m
						H = struct( 'Common', cell( 1, nUnzipped ), 'Binary', [], 'Channel', [], 'Coordinates', [], 'Comment', [], 'inputFile', '' );
						M = struct( 'Common', cell( 1, nUnzipped ), 'Marker', [], 'inputFile', '' );
						% For each triplet/quadruplet of Brain Vision files...
						for iUnzipped = 1:nUnzipped
							% Read Brain Vision Header File
							iZip = IUnzipped(iUnzipped);
							H(iUnzipped) = bieegl_readBVtxt( fullfile( outputDir, subDir, [ zipFiles(iZip).name(1:end-4), '.vhdr' ] ), struct( 'convertResolution', false ) );
							if ~strcmp( H(iUnzipped).Common.MarkerFile, [ zipFiles(iZip).name(1:end-4), '.vmrk' ] )
								writeToLog( verbose, '%s header/marker file mismatch\n', H(iUnzipped).inputFile )
								continue	% empty ImarkerSeg{iUnzipped} will flag bad BV files
							end
							if ~strcmp( H(iUnzipped).Common.DataFile  , [ zipFiles(iZip).name(1:end-4), '.eeg' ] )
								writeToLog( verbose, '%s header/data file mismatch\n', H(iUnzipped).inputFile )
								continue
							end
							% Read Brain Vision Marker File
							M(iUnzipped) = bieegl_readBVtxt( fullfile( rawDir, subDir, H(iUnzipped).Common.MarkerFile ) );
							if ~strcmp( M(iUnzipped).Common.DataFile, H(iUnzipped).Common.DataFile )
								writeToLog( verbose, '%s header/marker data file mismatch\n', H(iUnzipped).inputFile )
								continue
							end
							% Task segment indices, note: LostSamples events are of 'New Segment' type but have non-empty descriptions
							ImarkerSeg{iUnzipped} = find(...
								strcmp( { M(iUnzipped).Marker.Mk.type }, 'New Segment' ) &...
								cellfun( @isempty, { M(iUnzipped).Marker.Mk.description } ) );
						end		% unzipped file loop

						kBadBV = cellfun( @isempty, ImarkerSeg, 'UniformOutput', true );
						if any( kBadBV )
							if all( kBadBV )
								continue		% go to next session
							end
							H(kBadBV) = [];
							M(kBadBV) = [];
							ImarkerSeg(kBadBV) = [];
						end
						IBV = IUnzipped(~kBadBV);
						nBV = numel( IBV );

						nSegment = cellfun( @numel, ImarkerSeg, 'UniformOutput', true );
						if sum( nSegment ) ~= nSeq
							writeToLog( verbose, '# segments (%d) ~= expected # tasks (%d)\n', sum( nSegment ), nSeq )
% 							continue		% go to next session
						end

						iSeq = 0;
						ImarkerEnd = cell( 1, nBV );
						Itask      = cell( 1, nBV );

						% SEGMENT BY TASK ======================================================
						for iBV = 1:nBV

							ImarkerEnd{iBV} = zeros( 1, nSegment(iBV) );
							Itask{iBV}      = zeros( 1, nSegment(iBV) );

							for iSegment = 1:nSegment(iBV)

								% range of markers to evaluate, not range of time points
								% includes 'New Segment' markers
								if iSegment == nSegment(iBV)
									ImarkerEnd{iBV}(iSegment) = numel( M(iBV).Marker.Mk );				% last marker in the series
								else
									ImarkerEnd{iBV}(iSegment) = ImarkerSeg{iBV}(iSegment+1) - 1;		% one before the next segment starts
								end
								ImarkerRange = ImarkerSeg{iBV}(iSegment):ImarkerEnd{iBV}(iSegment);		% include new segment marker?
								kLostSamples = strncmp( { M(iBV).Marker.Mk(ImarkerRange).description }, 'LostSamples:', 12 );
								if any( kLostSamples )
									writeToLog( verbose, '%s segment #%d - %d epochs of lost samples\n', H(iBV).Common.MarkerFile, iSegment, sum( kLostSamples ) )
% 									ImarkerRange(kLostSamples) = [];
									continue		% Itask{iBV}(iSegment)==0 will flag bad segments
								end

								% verify expected event coding 'S  #', 'S ##', or 'S###'
								eventCode = regexp( { M(iBV).Marker.Mk(ImarkerRange(2:end)).description }, '^S[ ]*(\d+)$', 'tokens', 'once' );
								if any( cellfun( @isempty, eventCode ) )
									writeToLog( verbose, '%s segment #%d - Unexpected Marker description(s), can''t identify event code\n', H(iBV).Common.MarkerFile, iSegment )
									continue
								end
								% convert char codes to numeric
								eventCode = cellfun( @str2double, [ eventCode{:} ], 'UniformOutput', true );

								% identify task by presence of 1st code in taskInfo
								iTaskType = ismember( testCodes, eventCode );
								switch sum( iTaskType )
									case 1
										% make sure all event codes in segment are valid for current task segment
										if ~all( ismember( eventCode, [ taskInfo{iTaskType,2}{:,1} ] ) )
											writeToLog( verbose, '%s segment #%d - Unexpected events in task segment\nunique codes =', H(iBV).Common.MarkerFile, iSegment )
											writeToLog( verbose, ' %d', unique( eventCode(:) )' )
											writeToLog( verbose, '\n' )
											continue		% segment loop
										end
										% index into taskInfo cell array
										Itask{iBV}(iSegment) = find( iTaskType );
										iSeq(:) = iSeq + 1;
										% verify expected task sequence
										if iSeq > nSeq
											writeToLog( verbose, 'Longer than expected task sequence %d = %s\n', iSeq, taskInfo{Itask{iBV}(iSegment),1} )
										elseif Itask{iBV}(iSegment) ~= taskSeq(iSeq)
											writeToLog( verbose, 'Unexpected task sequence %d = %s\n', iSeq, taskInfo{Itask{iBV}(iSegment),1} )
										end
									case 0
										writeToLog( verbose, '%s segment #%d - Can''t identify task, none of codes', H(iBV).Common.MarkerFile, iSegment )
										writeToLog( verbose, ' %d', testCodes )
										writeToLog( verbose, ' found\nunique codes =' )
										writeToLog( verbose, ' %d', unique( eventCode(:) )' )
										writeToLog( verbose, '\n' )
										continue
									otherwise
										writeToLog( verbose, '%s segment #%d - Can''t identify task, multiples task codes', H(iBV).Common.MarkerFile, iSegment )
										writeToLog( verbose, ' %d', testCodes(iTaskType) )
										writeToLog( verbose, ' found\nunique codes =' )
										writeToLog( verbose, ' %d', unique( eventCode(:) )' )
										writeToLog( verbose, '\n' )
										continue
								end

							end		% segment loop

						end		% BV file loop

						if ~all( histcounts( categorical( [ Itask{:} ], 1:nTask ) ) == nRun )		% #runs found in data files, OK to have zeros in Itask here
							writeToLog( verbose, 'Unexpected number(s) of task runs\n' )
						end

						% Normally BIDS is BIDS/sub-id/ses-id/modality
						% in the PHOENIX structure it's PHOENIX/PROTECTED/site/processed/subjid/modality/ses-id/BIDS/
						bidsDir = fullfile( outputDir, 'BIDS' );
						if ~isfolder( bidsDir )
							mkdir( bidsDir )
						end
						
						subjCode    = [ 'sub-', upper( baseName(1:2) ), baseName(3:7) ];
						sessionCode = [ 'ses-', baseName(13:20) ];

						% zero nRun so it can be reused as running count
						nRun(:) = 0;
						for iBV = 1:nBV

							% Read Brain Vision Data File
							D = bieegl_readBVdata( H(iBV) );
							for iSegment = 1:nSegment(iBV)

								% add task and run info to output file name
								iTask = Itask{iBV}(iSegment);
								if iTask == 0
									break
								end
								nRun(iTask) = nRun(iTask) + 1;
								outputSegment = sprintf( '%s_%s_task-%s_run-%02d_eeg', subjCode, sessionCode, taskInfo{iTask,1}, nRun(iTask) );

								% WRITE OUTPUT FILES
								% HEADER -----------------------------------------------------------
								outputFile = fullfile( bidsDir, [ outputSegment, '.vhdr' ] );
								Hout = H(iBV);		% you need Hout even if not writing .vhdr
								Hout.Common.DataFile   = [ outputSegment, '.eeg'  ];
								Hout.Common.MarkerFile = [ outputSegment, '.vmrk' ];
								if exist( outputFile, 'file' ) == 2
									writeToLog( false, '%s exists, not replacing\n', outputFile )
								else
									writeToLog( verbose, 'writing %s...', outputFile )

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
% 											writeToLog( verbose, ' Unexpected %s.%s class [abort]\n', fn1, fn2{1} )
% 											break
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
% 											writeToLog( verbose, ' Unexpected %s.%s class [abort]\n', fn1, fn2{1} )
% 											break
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
										if verbose
											warning( 'MATLAB:fcloseError', 'fclose error' )
										end
									end

									writeToLog( verbose, ' done\n' )
								end

								% MARKER -----------------------------------------------------------
								outputFile = fullfile( bidsDir, Hout.Common.MarkerFile );
								if exist( outputFile, 'file' ) == 2
									writeToLog( false, '%s exists, not replacing\n', outputFile )
								else
									ImarkerRange = ImarkerSeg{iBV}(iSegment):ImarkerEnd{iBV}(iSegment);
									Mout = M(iBV);
									Mout.Common.DataFile = Hout.Common.DataFile;
									Mout.Marker.Mk       = Mout.Marker.Mk(ImarkerRange);
									% make marker positions relative to beginning of segment
									markerPos = [ Mout.Marker.Mk.position ];
									markerPos(:) = markerPos - ( markerPos(1) - 1 );
									markerPos = num2cell( markerPos );
									[ Mout.Marker.Mk.position ] = deal( markerPos{:} );

									writeToLog( verbose, 'writing %s...', outputFile )
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

									writeToLog( verbose, ' done\n' )
								end


								% DATA -------------------------------------------------------------
								outputFile = fullfile( outputDir, Hout.Common.DataFile );
								if exist( outputFile, 'file' ) == 2
									segFileLogFcn( '%s exists, not replacing\n', outputFile )
								else
									if iSegment == nSegment(iBV)
										iDataEnd = size( D, 2 );
									else
										iDataEnd = M(iBV).Marker.Mk(ImarkerSeg{iBV}(iSegment+1)).position - 1;
									end
									IdataRange = M(iBV).Marker.Mk(ImarkerSeg{iBV}(iSegment)).position:iDataEnd;
									writeToLog( verbose, 'writing %s...', outputFile )
									[ fid, msg ] = fopen( outputFile, 'w' );
									if fid == -1
										error( msg )
									end
									fwrite( fid, D(:,IdataRange), class( D ) );		% writes down column 1, before going to column 2 etc. in standard Matlab fashion
									if fclose( fid ) == -1
										warning( 'MATLAB:fcloseError', 'fclose error' )
									end
									writeToLog( verbose, ' done\n' )
								end

								% TEXT -------------------------------------------------------------
								% I'm not writing/copying text outputs, Neurosig Log File
								% they just have coarse time stamps of the operator event sequence (1 minute resolution)

							end		% segment loop

						end		% zip-file loop #4 write output files

error( 'left off here' )
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

					end

					% Add Sidecars.  
					% if char1 == abs('3') you would have continued already

				end		% session loop

			end		% subject loop

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

	function writeToLog( echoFlag, fmt, varargin )
		fprintf( fidLog, fmt, varargin{:} );
		if echoFlag
			fprintf( 1, fmt, varargin{:} )		% echo to command window
		end
	end

end