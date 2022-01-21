function success = AMPSCZ_EEG_matlabPaths
% add AMPSCZ_EEG paths from AMPSCZ_EEG_matlabPaths.mat
% if it exists in toolbox directory.  see lower section after
% function return for how to make this mat-file
%
% EEGLAB + ADJUST + AMPSCZ + faster & eeglab mods get added
% fieldtrip & its mods not included
%
% usage:
% >> success = AMPSCZ_EEG_matlabPaths
%
% returns true if paths added, false if not

% to do:
% put in checks and only add paths if needed?
%	removing redundant code from AMPSCZ_EEG_preproc, AMPSCZ_EEG_QC, AMPSCZ_EEG_ERPplot
% include an option of force addpath if i do the above

% 	narginchk( 0, 0 )
	success = false;
	pathMatFile = fullfile( fileparts( mfilename( 'fullpath' ) ), 'AMPSCZ_EEG_matlabPaths.mat' );
	if exist( pathMatFile, 'file' ) ~= 2
		return
	end
	AMPSCZpaths = load( pathMatFile );
	path(    AMPSCZpaths.pathFull )					% need to wipe out fieldtrip
% 	addpath( AMPSCZpaths.pathDiff, '-begin' )
% 	verbose = true;
% 	if verbose
		fprintf( 'AMPSCZ EEG added to top of path\n' )
% 	end
	success(:) = true;

	return

	%% get strings of full AMPSCZ_EEG paths (w/o fieldtrip)
	%% and differences from default
	%% save to mat?

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
	
end