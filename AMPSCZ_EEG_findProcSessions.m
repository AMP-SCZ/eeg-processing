function [ Sess, iSession ] = AMPSCZ_EEG_findProcSessions( selectionMode )
% Reads AMPSCZ PHOENIX directory trees to find locally available data for analysis.
% This function searches for BIDS/dataset_description.json to determine if a 
% session has been processed
%
% Usage:
% >> sessionList = AMPSCZ_EEG_findProcSessions;
%
% optionally bring up a listdlg to select session(s) from the list
% >> [ sessionList, iSession ] = AMPSCZ_EEG_findProcSessions( [ selectionMode = 'single' ] );
%
% Inputs:
% selectionMode = 'single' (default) or 'multiple', only relevent when asking for listdlg output
%
% Output:
% sessionList = #x2 cell array of char where 1st column is subject identifier, 2nd column is date
% iSession    = (optional) index in list, [] if dialog closed or cancelled
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 11/24/2021

	narginchk( 0, 1 )

	siteInfo = AMPSCZ_EEG_siteInfo;

	AMPSCZdir = AMPSCZ_EEG_paths;

	NSess = 0;
	Sess  = cell( 0, 3 );
	
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
		nSubj    = zeros( 1, nSite );
		nSess    =  cell( 1, nSite );
		for iSite = 1:nSite
			% search processed subject directories
			subjList{iSite} = dir( fullfile( ampsczSubjDir, siteList{iSite}, 'processed', [ siteList{iSite}(end-1:end), '*' ] ) );
			subjList{iSite}(~[subjList{iSite}.isdir]) = [];
			subjList{iSite}(cellfun( @isempty, regexp( { subjList{iSite}.name }, [ '^', siteList{iSite}(end-1:end), '\d{5}$'], 'start', 'once' ) )) = [];
			% convert to cell
			subjList{iSite} = { subjList{iSite}.name };
			nSubj(iSite)    = numel( subjList{iSite} );

			sessList{iSite} =  cell( 1, nSubj(iSite) );
			nSess{iSite}    = zeros( 1, nSubj(iSite) );
			for iSubj = 1:nSubj(iSite)
				% search for valid sesion directories that have a dataset_description.json file indicating segmenting was complete
				sessList{iSite}{iSubj} = dir( fullfile( ampsczSubjDir, siteList{iSite}, 'processed', subjList{iSite}{iSubj}, 'eeg', 'ses-*' ) );
				sessList{iSite}{iSubj}(~[sessList{iSite}{iSubj}.isdir]) = [];
				sessList{iSite}{iSubj}(cellfun( @isempty, regexp( { sessList{iSite}{iSubj}.name }, '^ses-\d{8}$', 'start', 'once' ) )) = [];
				sessList{iSite}{iSubj}(cellfun( @(u)exist(u,'file')~=2, fullfile( { sessList{iSite}{iSubj}.folder }, { sessList{iSite}{iSubj}.name }, 'BIDS', 'dataset_description.json' ) )) = [];
				% convert to cell
				sessList{iSite}{iSubj} = { sessList{iSite}{iSubj}.name };
				nSess{iSite}(iSubj)    = numel( sessList{iSite}{iSubj} );

				% concatenate found sessions
				for iSess = 1:nSess{iSite}(iSubj)
					NSess(:) = NSess + 1;
					Sess(NSess,:) = { siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess}(5:end) };
	% 				fprintf( '\t%s\t%s\t%s\n', siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess} )
				end
			end
		end
		
	end

	if nargout > 1
		if nargin == 1
			if ~ischar( selectionMode ) || ~ismember( selectionMode, { 'single', 'multiple' } )
				error( 'Invalid selectionMode input' )
			end
		else
			selectionMode = 'single';
		end
		iSession = listdlg( 'ListString', strcat( Sess(:,2), '_', Sess(:,3) ),...
			'PromptString', 'Select Session:', 'SelectionMode', selectionMode,...
			'InitialValue', 1, 'Name', mfilename, 'ListSize', [ 300, 600 ] );		% default size = [ 160, 300 ]
% 		if isempty( iSession )
% 			return
% 		end
	end
	
end


