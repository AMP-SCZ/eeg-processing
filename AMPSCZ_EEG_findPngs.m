function pngFile = AMPSCZ_EEG_findPngs( varargin )
% for now find sessions that have a _QClineNoise.png file
% and dump list to command window

	AMPSCZdir = AMPSCZ_EEG_paths;
	siteInfo  = AMPSCZ_EEG_siteInfo;
	networks  = unique( siteInfo(:,2), 'stable' );
% 	taskName  = 'AOD';
% 	taskName  = 'VOD';
% 	taskName  = 'MMN';

	pngFile = cell( 0, 1 );
	iPng    = 0;

	fprintf( repmat( '\n', [ 1, 3 ] ) )
	tic
	for iNetwork = 1:numel( networks )
		fprintf( '%s\n', networks{iNetwork} )
		sites = dir( fullfile( AMPSCZdir, networks{iNetwork}, 'PHOENIX', 'PROTECTED', [ networks{iNetwork}, '*' ] ) );
% 		sites(~[sites.isdir]) = [];
% 		sites(cellfun( @isempty, regexp( { sites.name }, [ '^', networks{iNetwork}, '[A-Z]{2}$' ], 'start', 'once' ) )) = [];
		kSite = strcmp( siteInfo(:,2), networks{iNetwork} );
		sites(~ismember( { sites.name }, strcat( siteInfo(kSite,2), siteInfo(kSite,1) ) )) = [];
		for iSite = 1:numel( sites )
			fprintf( '\t%s\n', sites(iSite).name(end-1:end) )
			if ~isfolder( fullfile( sites(iSite).folder, sites(iSite).name, 'processed' ) )
				continue
			end
			subjs = dir( fullfile( sites(iSite).folder, sites(iSite).name, 'processed', [ sites(iSite).name(end-1:end), '*' ] ) );
			subjs(~[subjs.isdir]) = [];
			subjs(cellfun( @isempty, regexp( { subjs.name }, [ '^', sites(iSite).name(end-1:end), '\d{5}$' ], 'start', 'once' ) )) = [];
			for iSubj = 1:numel( subjs )
% 				fprintf( '%s\n', subjs(iSubj).name )
				if ~isfolder( fullfile( subjs(iSubj).folder, subjs(iSubj).name, 'eeg' ) )
					continue
				end
				sesss = dir( fullfile( subjs(iSubj).folder, subjs(iSubj).name, 'eeg', 'ses-*' ) );
				sesss(~[sesss.isdir]) = [];
				sesss(cellfun( @isempty, regexp( { sesss.name }, '^ses-\d{8}$', 'start', 'once' ) )) = [];
				for iSess = 1:numel( sesss )
					if ~isfolder( fullfile( sesss(iSess).folder, sesss(iSess).name, 'Figures' ) )		% this is for re-running AMPSCZ_EEG_ERPplot.m only?
						continue
					end
					figs = dir( fullfile( sesss(iSess).folder, sesss(iSess).name, 'Figures', [ subjs(iSubj).name, '_', sesss(iSess).name(5:end), '_QClineNoise.png' ] ) );
					% older pngs don't have the filter bandwidth tag in the file name!
% 					figs = dir( fullfile( sesss(iSess).folder, sesss(iSess).name, 'Figures', [ subjs(iSubj).name, '_', sesss(iSess).name(5:end), '_', taskName, '*.png' ] ) );
% 					figs = dir( fullfile( sesss(iSess).folder, sesss(iSess).name, 'Figures', [ subjs(iSubj).name, '_', sesss(iSess).name(5:end), '_', taskName, '_[*,*].png' ] ) );
					figs([figs.isdir]) = [];
% 					figs(cellfun( @isempty, regexp( { figs.name }, [ '^', subjs(iSubj).name, '_', sesss(iSess).name(5:end), '_', taskName, '_\[[\d\.]+,(Inf|[\d\.]+)\].png$' ], 'start', 'once' ) )) = [];
					for iFig = 1:numel( figs )
						try

							fprintf( '\t\t%s\n', fullfile( figs(iFig).folder, figs(iFig).name ) )
							iPng(:) = iPng + 1;
							pngFile{iPng} = fullfile( figs(iFig).folder, figs(iFig).name );

						catch ME
% 							fprintf( '\t\tFAIL  %s\n', fullfile( figs(iFig).folder, figs(iFig).name ) )
							fprintf( '\t\t%s\n', ME.message )
						end
					end
				end
			end
		end
	end
	fprintf( 'done\n' )

end