function [ AMPSCZdir, eegLabDir, fieldTripDir, adjustDir ] = AMPSCZ_EEG_paths
% AMPSCZ Machine-dependent paths
% 
% usage:
% >> [ AMPSCZdataDir, eegLabDir, fieldTripDir, adjustDir ] = AMPSCZ_EEG_paths;


	narginchk( 0, 0 )

% 	bwhHostName = 'grx##.research.partners.org';
	if isunix % && strncmp( )
% 		AMPSCZdir    = '/data/predict/kcho/flow_test';					% don't work here, outputs will get deleted.  aws rsync to NDA s2
		AMPSCZdir    = '/data/predict/kcho/flow_test/spero';			% kevin got rid of group folder & only gave me pronet?
		downloadDir  = '/PHShome/sn1005/Downloads';
		eegLabDir    = fullfile( downloadDir, 'eeglab',    'eeglab2021.1' );
		fieldTripDir = fullfile( downloadDir, 'fieldtrip', 'fieldtrip-20211209' );
		adjustDir    = '';	%fullfile( downloadDir, 'adjust',    'ADJUST1.1.1' );
		error( 'needs ADJUST1.1.1' )
	elseif ispc
		AMPSCZdir    = 'C:\Users\donqu\Documents\NCIRE\AMPSCZ';
		downloadDir  = 'C:\Users\donqu\Downloads';
		eegLabDir    = fullfile( downloadDir, 'eeglab',    'eeglab2021.1' );
		fieldTripDir = fullfile( downloadDir, 'fieldtrip', 'fieldtrip-20210929' );
		adjustDir    = fullfile( downloadDir, 'adjust',    'ADJUST1.1.1' );
	else
	end

	if ~isfolder( AMPSCZdir )
		error( 'Invalid project directory' )
	end

end