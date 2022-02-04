function AMPSCZ_EEG_checkRun( subjStr, dateStr, runType, runNumber )
% Check that segmented AMPSCZ Brain Vision files have expected #s of stimulus codes
%
% Usage:
% AMPSCZ_EEG_checkRun( subjStr, dateStr, runType, runNumber )
%
% Where:
% subjStr   = 7-character subject identifier
% dateStr   = 8-character date string YYYYMMDD
% runType   = 'VODMMN', 'AOD', 'ASSR', 'RestEO', 'RestEC'
% runNumber = numeric scalar
%
% e.g.
% >> AMPSCZ_EEG_checkRun( 'SF12345', '20220101', 'VODMMN', 5 )
%
% Written by: Spero Nicholas, NCIRE

	narginchk( 4, 4 )
	
	if ~ischar( subjStr ) || isempty( regexp( subjStr, '^[A-Z]{2}\d{5}$', 'start', 'once' ) )
		error( 'Invalid subject identifier' )
	end
	if ~ischar( dateStr ) || isempty( regexp( dateStr, '^\d{8}$', 'start', 'once' ) )
		error( 'Invalid date string' )
	end
	taskInfo = AMPSCZ_EEG_taskSeq;
% 	if ~ischar( subjStr ) || ~ismember( runType, { 'VODMMN', 'AOD', 'ASSR', 'RestEO', 'RestEC' } )
	if ~ischar( subjStr ) || ~ismember( runType, taskInfo(:,1) )
		error( 'Invalid run Type' )
	end
	if ~isnumeric( runNumber ) || ~isscalar( runNumber ) || mod( runNumber, 1 ) ~= 0
		error( 'Run # must be numeric scalar' )
	end
	
	AMPSCZdir = AMPSCZ_EEG_paths;
	siteInfo  = AMPSCZ_EEG_siteInfo;
	iSite     = strncmp( subjStr, siteInfo(:,1), 2 );
	if nnz( iSite ) ~= 1
		error( 'Can''t identify site %s', subjStr(1:2) )
	end
	iSite = find( iSite );
	bidsDir = fullfile( AMPSCZdir, siteInfo{iSite,2}, 'PHOENIX', 'PROTECTED',...
		[ siteInfo{iSite,2}, siteInfo{iSite,1} ], 'processed',...
		subjStr, 'eeg', [ 'ses-', dateStr ], 'BIDS' );
	if ~isfolder( bidsDir )
		error( 'folder %s does not exist', bidsDir )
	end
	
	vhdrName = sprintf( 'sub-%s_ses-%s_task-%s_run-%02d_eeg.vhdr', subjStr, dateStr, runType, runNumber );
	vhdrFile = fullfile( bidsDir, vhdrName );
	if exist( vhdrFile, 'file' ) ~= 2
		error( '%s does not exist', vhdrFile )
	end
	
	% should I read this with EEGLAB or bieegl_readBVtxt.m?
% 	if ~false
% 		eeg = pop_loadbv( bidsDir, vhdrName );
% 		eventCode = { eeg.event(strcmp({eeg.event.code},'Stimulus')).type };
% 	else
		vhdr = bieegl_readBVtxt( vhdrFile );
% 		vmrk = bieegl_readBVtxt( fullfile( fileparts( vhdr.inputFile ), vhdr.Common.MarkerFile ) );
		vmrk = bieegl_readBVtxt( fullfile( bidsDir, vhdr.Common.MarkerFile ) );
		eventCode = { vmrk.Marker.Mk(strcmp({vmrk.Marker.Mk.type},'Stimulus')).description };
% 	end

	[ ~, iTask ] = ismember( runType, taskInfo(:,1) );
	codeCount = taskInfo{iTask,2}(~strcmp(taskInfo{iTask,2}(:,2),'Response'),[1,3]);
	codeCount(:,1) = cellfun( @(u)sprintf('S%3d',u), codeCount(:,1), 'UniformOutput', false );
	nCode = size( codeCount, 1 );
	ok = true;
	for iCode = 1:nCode
		stimCount = nnz(   strcmp( eventCode, codeCount{iCode,1} ) );	% strcmp a little faster than ismember
% 		stimCount = nnz( ismember( eventCode, codeCount{iCode,1} ) );
		if stimCount ~= codeCount{iCode,2}
			if ok
				fprintf( '%s\n', vhdrName )
			end
			ok(:) = false;
			fprintf( '\t%s ''%s'' expected %3d found %3d\n', taskInfo{iTask,1}, codeCount{iCode,1}, codeCount{iCode,2}, stimCount )
		end
	end
	if ok
		fprintf( '%s OK\n', vhdrName )
	end

	return

end