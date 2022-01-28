function [ Sess, iSession ] = AMPSCZ_EEG_findProcSessions( selectionMode )
% Reads AMPSCZ PHOENIX directory trees to find available data for analysis.
% This function searches for BIDS/dataset_description.json to determine if a 
% session has been processed with AMPSCZ_EEG_segmentRaw.m
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
% sessionList = #x3 cell array of char where 1st column is site identifier, 
%               2nd column is subject identifier, & 3rd column is date
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
	
	return
	
	%% find zips that haven't been extracted yet
	
	% SD00059_eeg_20211217.zip content name doesn't match zip file name, SD00037 inside
	
	zip = AMPSCZ_EEG_findZips;
	seg = AMPSCZ_EEG_findProcSessions;
	% can't do ismember(...,'rows') on cell arrays, concatenate 2nd dimension
	zip = strcat( zip(:,1), '_', zip(:,2), '_', zip(:,3) );
	seg = strcat( seg(:,1), '_', seg(:,2), '_', seg(:,3) );
	ok = true;
	fprintf( '\n' )
	k = ismember( seg, zip );
	if ~all( k )
		fprintf( 'segmented sessions w/o zip files:\n' )
		disp( seg(~k) )
		ok(:) = false;
	end
	k = ismember( zip, seg );
	if ~all( k )
		fprintf( 'unsegmented zip files:\n' )
		disp( zip(~k) )
		ok(:) = false;
	end
	if ok
		fprintf( 'all zip-files extracted\n' )
	end
	
	%% check for QC images
	seg = AMPSCZ_EEG_findProcSessions;
	nSeg = size( seg, 1 );
	AMPSCZdir = AMPSCZ_EEG_paths;
	ok = true;
	fprintf( '\n' )
	for iSeg = 1:nSeg
		QCfigs = dir( fullfile( AMPSCZdir, seg{iSeg,1}(1:end-2), 'PHOENIX', 'PROTECTED', seg{iSeg,1}, 'processed', seg{iSeg,2}, 'eeg', [ 'ses-', seg{iSeg,3} ], 'Figures', '*QC.png' ) );
		if isempty( QCfigs )
			fprintf( 'No QC figs for %s %s\n', seg{iSeg,2:3} )
			ok(:) = false;
		elseif numel( QCfigs ) ~= 1
			disp( { QCfigs.name }' )
			ok(:) = false;
		end
	end
	if ok
		fprintf( 'all sessions have QC png\n' )
	end

	%% check for ERP mat files
	seg = AMPSCZ_EEG_findProcSessions;
	nSeg = size( seg, 1 );
	AMPSCZdir = AMPSCZ_EEG_paths;
	ok = true;
	fprintf( '\n' )
	for iSeg = 1:nSeg
		matFiles = dir( fullfile( AMPSCZdir, seg{iSeg,1}(1:end-2), 'PHOENIX', 'PROTECTED', seg{iSeg,1}, 'processed', seg{iSeg,2}, 'eeg', [ 'ses-', seg{iSeg,3} ], 'mat', '*_[0.1,Inf].mat' ) );
		if isempty( matFiles )
			fprintf( 'No ERP mat-files for %s %s %s\n', seg{iSeg,1}(1:end-2), seg{iSeg,2:3} )
			ok(:) = false;
		elseif numel( matFiles ) ~= 111
			disp( { matFiles.name }' )
			ok(:) = false;
		end
	end
	if ok
		fprintf( 'all sessions have ERP mat files\n' )
	end

	%% check for ERP png & mp4
	seg = AMPSCZ_EEG_findProcSessions;
	nSeg = size( seg, 1 );
	AMPSCZdir = AMPSCZ_EEG_paths;
	ok = true;
	imgExt = '.png';
% 	imgExt = '.mp4';
	fprintf( '\n' )
	for iSeg = 1:nSeg
		imgFiles = dir( fullfile( AMPSCZdir, seg{iSeg,1}(1:end-2), 'PHOENIX', 'PROTECTED', seg{iSeg,1}, 'processed', seg{iSeg,2}, 'eeg', [ 'ses-', seg{iSeg,3} ], 'Figures', [ '*', imgExt ] ) );
		if isempty( imgFiles )
			fprintf( 'No ERP image files for %s %s %s\n', seg{iSeg,1}(1:end-2), seg{iSeg,2:3} )
			ok(:) = false;
		elseif numel( imgFiles ) ~= 111
			disp( { imgFiles.name }' )
			ok(:) = false;
		end
	end
	if ok
		fprintf( 'all sessions have ERP image files\n' )
	end

end


