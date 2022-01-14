% get strings of full AMPSCZ_EEG paths (w/o fieldtrip)
% and differences from default
% save to mat?

	clear
	close all
	
	restoredefaultpath
	path0 = path;
	
	AMPSCZtools = 'C:\Users\donqu\Documents\GitHub\AMP-SCZ\eeg-processing';
	addpath( AMPSCZtools )
	modDir = fullfile( fileparts( which( 'AMPSCZ_EEG_paths.m' ) ), 'modifications' );
	[ AMPSCZdir, eegLabDir, fieldTripDir, adjustDir ] = AMPSCZ_EEG_paths;
	addpath( eegLabDir )
	eeglab
	addpath( adjustDir )
	rmpath(  AMPSCZtools )
	addpath( AMPSCZtools )
	addpath( fullfile( modDir, 'eeglab' ) )
	addpath( fullfile( modDir, 'faster' ) )
% 	addpath( fullfile( modDir, 'fieldtrip' ) )
	pathFull = path;
	
	% convert long line of char to cell array
	path0    = split( path0,    ';' );
	pathDiff = split( pathFull, ';' );					% not diff yet
	if ~all( ismember( path0, pathDiff ) )
		error( 'huh?' )
	end
	pathDiff = setdiff( pathDiff, path0, 'stable' );	% now diff
	% convert back to char
	pathDiff = strcat( pathDiff, ';' );
	pathDiff = [ pathDiff{:} ];

% 	save( fullfile( AMPSCZtools, 'AMPSCZ_EEG_matlabPaths.mat' ), 'pathFull', 'pathDiff' )
	