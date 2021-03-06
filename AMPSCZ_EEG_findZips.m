function Sess = AMPSCZ_EEG_findZips
% Reads AMPSCZ PHOENIX directory trees to find available zip files.
% This function doesn't check whether zip files have already been 
% processed with AMPSCZ_EEG_segmentRaw.m
%
% Usage:
% >> sessionList = AMPSCZ_EEG_findZips;
%
% Output:
% sessionList = #x3 cell array of char where 1st column is site identifier, 
%               2nd column is subject identifier, & 3rd column is date
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 1/25/2021

	siteInfo = AMPSCZ_EEG_siteInfo;

	AMPSCZdir = AMPSCZ_EEG_paths;

	NSess = 0;
	Sess  = cell( 0, 4 );
	
	for networkName = { 'Pronet', 'Prescient' }
	
		ampsczSubjDir = fullfile( AMPSCZdir, networkName{1}, 'PHOENIX', 'PROTECTED' );

		% find sites that have been synched already
		siteList = dir( fullfile( ampsczSubjDir, [ networkName{1}, '*' ] ) );
		% legal directory names
		siteList(~[siteList.isdir]) = [];
		siteList(cellfun( @isempty, regexp( { siteList.name }, [ '^', networkName{1}, '[A-Z]{2}$' ], 'start', 'once' ) )) = [];
		siteList(~ismember( {siteList.name }, strcat( siteInfo(:,2), siteInfo(:,1) ) )) = [];
		% convert to cell
		siteList = { siteList.name };
		nSite = numel( siteList );

		% don't really need to store this info & not that network loop was added, it's incomplete anyhow!
		subjList =  cell( 1, nSite );
		sessList =  cell( 1, nSite );
		fileDate =  cell( 1, nSite );
		nSubj    = zeros( 1, nSite );
		nSess    =  cell( 1, nSite );
		for iSite = 1:nSite
			% search processed subject directories
			subjList{iSite} = dir( fullfile( ampsczSubjDir, siteList{iSite}, 'raw', [ siteList{iSite}(end-1:end), '*' ] ) );
			subjList{iSite}(~[subjList{iSite}.isdir]) = [];
			subjList{iSite}(cellfun( @isempty, regexp( { subjList{iSite}.name }, [ '^', siteList{iSite}(end-1:end), '\d{5}$'], 'start', 'once' ) )) = [];
			% convert to cell
			subjList{iSite} = { subjList{iSite}.name };
			nSubj(iSite)    = numel( subjList{iSite} );

			sessList{iSite} =  cell( 1, nSubj(iSite) );
			fileDate{iSite} =  cell( 1, nSubj(iSite) );
			nSess{iSite}    = zeros( 1, nSubj(iSite) );
			for iSubj = 1:nSubj(iSite)

				% search for valid sesion directories that have zip file(s) w/ expected naming
% 				sessList{iSite}{iSubj} = dir( fullfile( ampsczSubjDir, siteList{iSite}, 'raw', subjList{iSite}{iSubj}, 'eeg', [ subjList{iSite}{iSubj}, '_eeg_*.zip' ] ) );
% 				sessList{iSite}{iSubj}(cellfun( @isempty, regexp( { sessList{iSite}{iSubj}.name }, [ '^', subjList{iSite}{iSubj}, '_eeg_\d{8}_?\d*.zip$' ], 'start', 'once' ) )) = [];

				% allow for case-insensitive site codes
% 				sessList{iSite}{iSubj} = dir( fullfile( ampsczSubjDir, siteList{iSite}, 'raw', subjList{iSite}{iSubj}, 'eeg', '*_eeg_*.zip' ) );	% PI00056_20211230 has no eeg in zip file name
% 				sessList{iSite}{iSubj}(cellfun( @isempty, regexp( { sessList{iSite}{iSubj}.name },...
% 					[ '^[', subjList{iSite}{iSubj}(1), lower( subjList{iSite}{iSubj}(1) ), '][',...
% 					        subjList{iSite}{iSubj}(2), lower( subjList{iSite}{iSubj}(2) ), ']',...
% 							subjList{iSite}{iSubj}(3:end), '_eeg_\d{8}_?\d*.zip$' ],...
% 					'start', 'once' ) )) = [];

				% convert to cell
% 				sessList{iSite}{iSubj} = { sessList{iSite}{iSubj}.name };

				% allow whatever crazy renaming *$#@! people manage to come up with?
				sessList{iSite}{iSubj} = dir( fullfile( ampsczSubjDir, siteList{iSite}, 'raw', subjList{iSite}{iSubj}, 'eeg', '*.zip' ) );
				% no, we at least need to be able to identify date
				sessList{iSite}{iSubj}(cellfun( @isempty, regexp( { sessList{iSite}{iSubj}.name }, '^.*\d{8}_?\d*.zip$', 'start', 'once' ) )) = [];
				fileDate{iSite}{iSubj} = sort( [ sessList{iSite}{iSubj}.datenum ] );		% which type of date is this? created or modified?
				sessList{iSite}{iSubj} = regexp( { sessList{iSite}{iSubj}.name }, '^.*(\d{8})_?\d*.zip$', 'tokens', 'once' );
				sessList{iSite}{iSubj} = [ sessList{iSite}{iSubj}{:} ];		% cell array of 8-digit dates (char)

				% check for multiple zip-files per session, i.e. ignore any trailing _# in the file names
				% unique session names, Iu is index of 1st match, use 'legacy' for last
				% have to do something more complicated to pick out 1st or last zip file chronologically
% 				sessList{iSite}{iSubj} = unique( cellfun( @(u)[upper(u(1:2)),u(3:20)], sessList{iSite}{iSubj}, 'UniformOutput', false ) );
				listPre = sessList{iSite}{iSubj};
				[ sessList{iSite}{iSubj}, Iu ] = unique( sessList{iSite}{iSubj} );

				nSess{iSite}(iSubj) = numel( sessList{iSite}{iSubj} );

				% concatenate found sessions
				for iSess = 1:nSess{iSite}(iSubj)
					NSess(:) = NSess + 1;
% 					Sess(NSess,:) = { siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess}(13:end), fileDate{iSite}{iSubj}(Iu(iSess)) };
% 					Sess(NSess,:) = { siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess}, datestr( fileDate{iSite}{iSubj}(Iu(iSess)), 'yyyymmdd' ) };
					dateSort = sort( fileDate{iSite}{iSubj}( strcmp( listPre, sessList{iSite}{iSubj}{iSess} ) ) );
					% 1st or last?
					Sess(NSess,:) = { siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess}, datestr( dateSort(end), 'yyyymmdd' ) };
	% 				fprintf( '\t%s\t%s\t%s\n', siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess} )
				end
			end
		end
		
	end
	
end


