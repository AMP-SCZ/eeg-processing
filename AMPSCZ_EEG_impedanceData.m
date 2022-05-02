function AMPSCZ_EEG_impedanceData( subjectID, sessionDate )
	clear
	
	subjectID   = 'AD00051';
	sessionDate = '20220429';
	
		locsFile = 'AMPSCZ_EEG_actiCHamp65ref_noseX.ced';
		chanlocs = readlocs( locsFile, 'importmode', 'native', 'filetype', 'chanedit' );

	if false
		[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( 'all' );
		vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, false );
	else	% faster if you're for sure finding all vhdr files
		AMPSCZdir = AMPSCZ_EEG_paths;
		siteInfo  = AMPSCZ_EEG_siteInfo;
		siteId    = subjectID(1:2);
		iSite     = ismember( siteInfo(:,1), siteId );
		switch nnz( iSite )
			case 1
% 				iSite = find( iSite );
			case 0
				error( 'Invalid site identifier' )
			otherwise
				error( 'non-unique site bug' )
		end
		networkName = siteInfo{iSite,2};
		bidsDir     = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ],...
								'processed', subjectID, 'eeg', [ 'ses-', sessionDate ], 'BIDS' );
		if ~isfolder( bidsDir )
			error( '%s is not a valid directory', bidsDir )
		end
% 		vhdrFmt = '*.vhdr';
		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-*_run-*_eeg.vhdr' ];
		vhdr = dir( fullfile( bidsDir, vhdrFmt ) );
	end
	nHdr = numel( vhdr );

	[ Z, Zrange, Ztime ] = deal( cell( 1, nHdr ) );
	for iHdr = 1:nHdr
		[ Z{iHdr}, Zrange{iHdr}, Ztime{iHdr} ] = AMPSCZ_EEG_readBVimpedance( fullfile( vhdr(iHdr).folder, vhdr(iHdr).name ) );
		if iHdr == 1
			Zname = Z{iHdr}(:,1);
		elseif size( Z{iHdr}, 1 ) ~= numel( Zname ) || ~all( strcmp( Z{iHdr}(:,1), Zname ) )
			error( 'Impedance channel mismatch across measures' )
		end
		Z{iHdr} = cell2mat( permute( Z{iHdr}(:,2,:), [ 1, 3, 2 ] ) );		% channels x measurements matrix, drop names
	end
	Z      = cat( 2, Z{:} );
	Zrange = cat( 1, Zrange{:} );
	Ztime  = cat( 1, Ztime{:}  ) * [ 3600; 60; 1 ];
	
	% Get rid of redudant copies of measurements & sort chronologically
	[ Ztime, Iu ] = unique( Ztime, 'sorted' );
	Z      = Z(:,Iu);
	Zrange = Zrange(Iu,:);
	
	% Choose measurement - this is done inside AMPSCZ_EEG_plotImpedanceTopo
% 	iZ = find( ~all( isnan( Z ), 1 ), 1, 'last' );

%%
	figure( 'Position', [ 500, 300, 525, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' )		
	hAx = axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
% 	if isempty( iZ )
% 		text( 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Position', [ 0.5, 0.5, 0 ],...
% 			'String', '\color{red}No Impedance Data', 'FontSize', fontSize, 'FontWeight', fontWeight )
% 		set( hAx, 'Visible', 'off', 'DataAspectRatio', [ 1, 1, 1 ] )		% why can I title invisible topo axis, but this hides title!!!
% 	else
		zThresh = 25;				% impedance threshold
		zLimit  = zThresh * 2;
		AMPSCZ_EEG_plotImpedanceTopo( hAx, Zname, Z, chanlocs, Zrange, zThresh, zLimit )
% 	end

	return

end
