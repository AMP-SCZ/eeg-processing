function [ sessionDir, networkName ] = AMPSCZ_EEG_procSessionDir( subjectID, sessionDate, networkName, createFlag )
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

	narginchk( 2, 4 )

	siteID = subjectID(1:2);
	if exist( 'networkName', 'var' ) ~= 1 || isempty( networkName )
		siteInfo = AMPSCZ_EEG_siteInfo;
		kSite    = strcmp( siteInfo(:,1), siteID );
		if nnz( kSite ) ~= 1
			error( 'site id bug' )
		end
		networkName = siteInfo{kSite,2};
	end
	if exist( 'createFlag', 'var' ) ~= 1 || isempty( createFlag )
		createFlag = false;
	end

	sessionDir = fullfile( AMPSCZ_EEG_paths, networkName, 'PHOENIX', 'PROTECTED',...
		[ networkName, siteID ], 'processed', subjectID, 'eeg', [ 'ses-', sessionDate ] );

	if ~isfolder( sessionDir )		% Box Drive sometimes gives the wrong answer here on 1st attempt!
		if createFlag
			mkdir( sessionDir )
			fprintf( 'created %s\n', sessionDir )
		else
			error( '%s is not a valid directory', sessionDir )
		end
	end

end