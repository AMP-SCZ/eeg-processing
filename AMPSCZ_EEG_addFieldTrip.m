function AMPSCZ_EEG_addFieldTrip
% put FieldTrip on Matlab path & call ft_defaults
% also create/modify fieldtripprefs.mat if needed
%
% usage:
% >> AMPSCZ_EEG_addFieldTrip

	verbose = true;
	
	[ ~, ~, fieldTripDir ] = AMPSCZ_EEG_paths;
	addpath( fieldTripDir, '-begin' )
	if verbose
		fprintf( '\n%s added to path\n', fieldTripDir )
	end
	ftPrefsFile = fullfile( prefdir, 'fieldtripprefs.mat');
	if exist( ftPrefsFile, 'file' ) == 2
		ftPrefs = load( ftPrefsFile );
		if ~isfield( ftPrefs, 'trackusage' )
			error( 'bad fieldtripprefs.mat file?' )
		end
		if ~strcmp( ftPrefs.trackusage, 'no' )
			ftPrefs.trackusage = 'no';
			save( ftPrefsFile, '-struct', 'ftPrefs' )
			if verbose
				fprintf( 'Updated %s\n', ftPrefsFile )
			end
		end
	else
		ftPrefs = struct( 'trackusage', 'no' );
		save( ftPrefsFile, '-struct', 'ftPrefs' )
		if verbose
			fprintf( 'Created %s\n', ftPrefsFile )
		end
	end
	% data2bids.m has lots of dependencies, ft_defaults puts them on path
	% even more paths get added when data2bids.m is called
	ft_defaults
	if ~contains( which( 'ft_read_tsv.m' ), 'modifications' )
		% make sure my modifified fieldrip functions are higher on path
		addpath( fullfile( fileparts( mfilename( 'fullpath' ) ), 'modifications', 'fieldtrip' ), '-begin' )
	end
	
end
