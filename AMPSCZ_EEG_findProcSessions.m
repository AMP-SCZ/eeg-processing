% find sessions available for QA/QC & downstream analyses

clear

siteInfo = AMPSCZ_EEG_siteInfo;

pronetSubjDir = '/data/predict/kcho/flow_test/spero/Pronet/PHOENIX/PROTECTED';

% find sites that have been synched already
siteList = dir( fullfile( pronetSubjDir, 'Pronet*' ) );
% legal directory names
siteList(~[siteList.isdir]) = [];
siteList(cellfun( @isempty, regexp( { siteList.name },'^Pronet[A-Z]{2}$', 'start', 'once' ) )) = [];
siteList(~ismember( {siteList.name }, strcat( siteInfo(:,2), siteInfo(:,1) ) )) = [];
% convert to cell
siteList = { siteList.name };
nSite = numel( siteList );

subjList =  cell( 1, nSite );
sessList =  cell( 1, nSite );
nSubj    = zeros( 1, nSite );
nSess    =  cell( 1, nSite );
NSess    = 0;
Sess     = cell( 0, 3 );
for iSite = 1:nSite
	% search processed subject directories
	subjList{iSite} = dir( fullfile( pronetSubjDir, siteList{iSite}, 'processed', [ siteList{iSite}(7:8), '*' ] ) );
	subjList{iSite}(~[subjList{iSite}.isdir]) = [];
	subjList{iSite}(cellfun( @isempty, regexp( { subjList{iSite}.name }, [ '^', siteList{iSite}(7:8), '\d{5}$'], 'start', 'once' ) )) = [];
	% convert to cell
	subjList{iSite} = { subjList{iSite}.name };
	nSubj(iSite)    = numel( subjList{iSite} );
	
	sessList{iSite} =  cell( 1, nSubj(iSite) );
	nSess{iSite}    = zeros( 1, nSubj(iSite) );
	for iSubj = 1:nSubj(iSite)
		% search for valid sesion directories that have a dataset_description.json file indicating segmenting was complete
		sessList{iSite}{iSubj} = dir( fullfile( pronetSubjDir, siteList{iSite}, 'processed', subjList{iSite}{iSubj}, 'eeg', 'ses-*' ) );
		sessList{iSite}{iSubj}(~[sessList{iSite}{iSubj}.isdir]) = [];
		sessList{iSite}{iSubj}(cellfun( @isempty, regexp( { sessList{iSite}{iSubj}.name }, '^ses-\d{8}$', 'start', 'once' ) )) = [];
		sessList{iSite}{iSubj}(cellfun( @(u)exist(u,'file')~=2, fullfile( { sessList{iSite}{iSubj}.folder }, { sessList{iSite}{iSubj}.name }, 'BIDS', 'dataset_description.json' ) )) = [];
		% convert to cell
		sessList{iSite}{iSubj} = { sessList{iSite}{iSubj}.name };
		nSess{iSite}(iSubj)    = numel( sessList{iSite}{iSubj} );
		
		% concatenate found sessions
		for iSess = 1:nSess{iSite}(iSubj)
			NSess(:) = NSess + 1;
			Sess(NSess,:) = { siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess} };
% 			fprintf( '\t%s\t%s\t%s\n', siteList{iSite}, subjList{iSite}{iSubj}, sessList{iSite}{iSubj}{iSess} )
		end

	end
end

disp( Sess )




