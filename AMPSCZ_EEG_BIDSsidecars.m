function AMP_SCZ_BIDSsidecars( verbose )

	error( 'Needs to be modified for BWH paths & latest PHOENIX organization' )

% FieldTrip's ft_read_tsv.m & ft_write_tsv.m replaced by my edited versions in "modifications" folder
% to handle Matlab datetime class which they didn't support.

% see https://www.fieldtriptoolbox.org/example/bids_eeg/

% cfg.dataset
%     'BIDS\sub-SF11111\eeg\sub-SF11111_task-VisMMN_run-01_eeg'
% 
% cfg.outputfile
%     'BIDS\sub-SF11111\eeg\sub-SF11111_task-VisMMN_eeg'
%
% Error using data2bids (line 723)
% cfg.dataset and cfg.outputfile should be the same

% mm = merge_table( ss, ss2, 'filename' );
% Warning: The assignment added rows to the table, but did not assign values to all of the table's existing variables. Those variables are extended
% with rows containing default values. 
%
% removing filename input suppresses this warning.  this happens even with compatible table columns?

% 9/8/2021
% modfied ft_read_tsv.m an dt_write_tsv.m to handle datetime class - SCN

% ***
% no participants.json file as in https://osf.io/cj2dr/
% include sourcedata/sub-id/eeg/originalData ?
% include stimuli/? e.g. png?
% scans.tsv is bonus?

% ***
% you get this warning, ft_preamble_init.m line 134, cfg.outputfilepresent = 'overwrite'
% ft_warning('output file %s is already present: it will be overwritten', chiL7fee_outputfile{i});
% when doing decorate even if you're not writing data

% ***
% What is "TriggerChannelCount" in _eeg.json file? "Number of channels for digital (TTL bit level) trigger."
% MiscChannelCount = "Number of miscellaneous analog channels for auxiliary signals"

% to do:
% add to _eeg.json: Manufacturer, ManufacturersModelName, SoftwareVersions, Instructions, DeviceSerialNumber,
%                   *SoftwareFilters* = get from vhdr i.e. "Disabled", *RecordingType* = continuous
%                   HeadCircumference, EEGPlacementScheme, HardwareFilters
% _channels.json?



	try

		narginchk( 0, 1 )
		if nargin == 0
			verbose = true;
		elseif ~isscalar( verbose ) || ~islogical( verbose )
			error( 'Invalid "verbose" input' )
		end
		
		if isempty( which( 'data2bids.m' ) )
% 			addpath( 'C:\Users\VHASFCNichoS\Downloads\fieldtrip\fieldtrip-master\fieldtrip-master', '-begin' )
			addpath( 'C:\Users\donqu\Downloads\fieldtrip\fieldtrip-20210929' )
% 			addpath( '\\R01SFCHSM03.r01.med.va.gov\homedir$\VHASFCNichoS\My Documents\GitHub\ProNET\modifications\fieldtrip', '-begin' )
			addpath( fullfile( fileparts( mfilename( 'fullpath' ) ), 'modifications', 'fieldtrip' ), '-begin' )
			% see https://www.fieldtriptoolbox.org/privacy/
%			prefs = load( fullfile( prefdir, 'fieldtripprefs.mat') )
% 				prefs = 
% 				  struct with fields:
% 					trackusage: 'B9D0DBD3'
%			prefs.trackusage = 'no';
%			save( fullfile( prefdir, 'fieldtripprefs.mat' ), '-struct', 'prefs' )		
			ft_defaults			% data2bids.m has lots of dependencies this gets them all on the path
		end
		
		if ispc
			speroDir = 'S:\bieegl02\home\scnicholas';
		elseif ismac
			error( 'unsupported OS' )
		elseif isunix
			speroDir = '/home/bjr39/mathalon2/home/scnicholas';
		end
		projectDir = fullfile( speroDir, 'playground', 'EEG', 'ProNet' );
		projectDir = 'C:\Users\donqu\Documents\NCIRE\ProNET';

		siteName = ProNET_siteNames;
		nSite    = size( siteName, 1 );
		
		taskInfo = ProNET_taskSeq;
		
		cfg = struct(...
			'method',                      'decorate',...
			'datatype',                    'eeg',...
			'writejson',                   'merge',...		% ['yes'], 'replace', 'merge', 'no'
			'writetsv',                    'merge',...		% ['yes'], 'replace', 'merge', 'no'
			'bidsroot',                    '',...
			'InstitutionName',             'AMP SCZ',...
			'InstitutionalDepartmentName', '',...
			'InstitutionAddress',          '',...
			'eeg',                         struct( 'PowerLineFrequency', [], 'EEGReference', '' ),...		%  EEG specific config options
			'sub',                         '',...
			'run',                         '',...
			'TaskName',                    '',...
			'TaskDescription',             '',...
			'dataset',                     '',...
			'outputfile',                  '',...
			'participants',                struct( 'age', [], 'sex', '' ),...
			'scans',                       struct( 'acq_time', '' ) );
		%   cfg.Manufacturer                = string
		%   cfg.ManufacturersModelName      = string
		%   cfg.DeviceSerialNumber          = string
		%   cfg.SoftwareVersions            = string
		%   cfg.Instructions                = string
		% cfg.eeg.RecordingType
		% cfg.eeg.HeadCircumference
		% cfg.eeg.EEGPlacementScheme
		% cfg.eeg.SoftwareFilters
		% cfg.eeg.HardwareFilters


	% { participant id, age, sex }
	% no 'sub-' prefix on id
	% age units = years?  integer?, nan for unknown
	% sex = 'm' or 'f', [] for unspecified
% 	sub = { 'SF1111', [ 1970 1 29 ], 'm' };


	
		for iSite = 1:nSite
			cfg.InstitutionalDepartmentName = siteName{iSite,1};
			cfg.InstitutionAddress          = siteName{iSite,3};
% 			if true
% 				cfg.eeg.PowerLineFrequency = 60;
% 			else
% 				cfg.eeg.PowerLineFrequency = 50;
% 			end
			cfg.eeg.PowerLineFrequency = siteName{iSite,4};
			bidsDir      = fullfile( projectDir, siteName{iSite,1}, 'BIDS' );
			cfg.bidsroot = bidsDir;
			subDirs = dir( fullfile( bidsDir, 'sub-*' ) );
			subDirs(~[ subDirs.isdir ]) = [];
			subDirs(cellfun( @isempty, regexp( { subDirs.name }, '^sub-[A-Z]{2}\d{5}$', 'start', 'once' ) )) = [];
			nSub = numel( subDirs );
			for iSub = 1:nSub
				cfg.sub = subDirs(iSub).name(5:end);
	
					% specify the information for the participants.tsv file
					% this is optional, you can also pass other pieces of info
					cfg.participants.age = 0;
					cfg.participants.sex = '';
	
				sesDirs = dir( fullfile( bidsDir, subDirs(iSub).name, 'ses-*' ) );
				sesDirs(~[ sesDirs.isdir ]) = [];
				sesDirs(cellfun( @isempty, regexp( { sesDirs.name }, '^ses-\d{8}$', 'start', 'once' ) )) = [];
				nSes = numel( sesDirs );
				for iSes = 1:nSes
					eegDir = fullfile( bidsDir, subDirs(iSub).name, sesDirs(iSes).name, 'eeg' );
					if ~isfolder( eegDir )
						continue
					end
					eegFiles = dir( fullfile( eegDir, [ subDirs(iSub).name, '_', sesDirs(iSes).name, '_task-*_run-*_eeg.eeg' ] ) );
					eegFiles(cellfun( @isempty, regexp( { eegFiles.name }, [ subDirs(iSub).name, '_', sesDirs(iSes).name, '_task-[A-Za-z]+_run-\d{2}_eeg.eeg' ], 'start', 'once' ) )) = [];
					nEEG = numel( eegFiles );
					for iEEG = 1:nEEG
						
						% this will add:
						%    sub-**####_ses-########_task-*_run-*_eeg.json
						%    sub-**####_ses-########_task-*_run-*_channels.tsv
						%    sub-**####_ses-########_task-*_run-*_events.tsv
						% and in parent folder of eeg
						%    sub-**####_scans.tsv
						bidsTestFile = fullfile( eegFiles(iEEG).folder, [ eegFiles(iEEG).name(1:end-3), 'json' ] );
						if exist( bidsTestFile, 'file' ) == 2
							if verbose
								fprintf( 'BIDS sidecar exists %s\n', bidsTestFile )		% really print this for all 12 runs/session?
							end
							continue
						end
						cfg.dataset    = fullfile( eegFiles(iEEG).folder, eegFiles(iEEG).name );
						cfg.outputfile = cfg.dataset;		% if you don't include this option it'll try to do it automatically & leave off .eeg extension & throw an error

						nameParse = regexp( eegFiles(iEEG).name, '^sub-[A-Z]{2}\d{5}_ses-\d{8}_task-([A-Za-z]+)_run-(\d{2})_eeg.eeg$', 'once', 'tokens' );
						iTask     = strcmp( nameParse{1}, taskInfo(:,1) );
						cfg.TaskName        = taskInfo{iTask,1};
						cfg.TaskDescription = taskInfo{iTask,3};
						cfg.run             = nameParse{2};

						H = bieegl_readBVtxt( [ cfg.dataset(1:end-3), 'vhdr' ] );
						% 'Reference Channel Name = FCz'
						refChan = regexp( H.Comment, '^Reference Channel Name\s*=\s*(.+)$', 'once', 'tokens' );
						kRef = ~cellfun( @isempty, refChan );
						if sum( kRef ) == 1
							cfg.eeg.EEGReference = refChan{kRef}{1};
						else
							warning( 'no/multiple reference channel(s) found' )
						end

						% specify the information for the scans.tsv file
						% this is optional, you can also pass other pieces of info - whose comments are these?
						M = bieegl_readBVtxt( [ cfg.dataset(1:end-3), 'vmrk' ] );
						iMk = find( strcmp( { M.Marker.Mk.type }, 'New Segment' ), 1, 'first' );
						cfg.scans.acq_time = [ M.Marker.Mk(iMk).date(1:4), '-', M.Marker.Mk(iMk).date(5:6),...
							'-', M.Marker.Mk(iMk).date(7:8), 'T', M.Marker.Mk(iMk).date(9:10), ':',...
							M.Marker.Mk(iMk).date(11:12), ':', M.Marker.Mk(iMk).date(13:14) ];

						data2bids( cfg );

					end
				end
			end
		end

		fprintf( '%s finished\n', mfilename )

		return
		
	catch ME
		rethrow( ME )
	end

end















