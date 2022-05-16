function [ sessionDir, networkName ] = AMPSCZ_EEG_procSessionDir( subjectID, sessionDate, networkName )
% get the directory of a proccessed EEG session by subject ID and date
% if you optionally add the newtork name, it will save the step of determining
% it from the site code embedded in the subject ID.
%
% usage:
% >> sessionDir = AMPSCZ_EEG_procSessionDir( subjectID, sessionDate, [networkName] )
%
% optional networkName is either 'Pronet' or 'Presicent'
%
% e.g.
% >> sessionDir = AMPSCZ_EEG_procSessionDir( 'SF12345', '20220101' );

	narginchk( 2, 3 )

	siteID = subjectID(1:2);
	if nargin == 2 || isempty( networkName )
		siteInfo = AMPSCZ_EEG_siteInfo;
		kSite    = strcmp( siteInfo(:,1), siteID );
		if nnz( kSite ) ~= 1
			error( 'site id bug' )
		end
		networkName = siteInfo{kSite,2};
	end

	sessionDir = fullfile( AMPSCZ_EEG_paths, networkName, 'PHOENIX', 'PROTECTED',...
		[ networkName, siteID ], 'processed', subjectID, 'eeg', [ 'ses-', sessionDate ] );

	if ~isfolder( sessionDir )
		error( '%s is not a valid directory', sessionDir )
	end

end