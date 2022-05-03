function AMPSCZ_EEG_lineNoise( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

	narginchk( 2, 7 )
	
%{
% 	if false
% 		[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( 'all' );
% 		vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, false );
% 	else	% faster if you're for sure finding all vhdr files
		AMPSCZdir = AMPSCZ_EEG_paths;
		siteInfo  = AMPSCZ_EEG_siteInfo;
		siteId    = subjectID(1:2);
		kSite     = ismember( siteInfo(:,1), siteId );
		switch nnz( kSite )
			case 1
			case 0
				error( 'Invalid site identifier' )
			otherwise
				error( 'non-unique site bug' )
		end
		networkName = siteInfo{kSite,2};
		bidsDir     = fullfile( AMPSCZdir, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteId ],...
								'processed', subjectID, 'eeg', [ 'ses-', sessionDate ], 'BIDS' );
		if ~isfolder( bidsDir )
			error( '%s is not a valid directory', bidsDir )
		end
% 		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-*_run-*_eeg.vhdr' ];
		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-VODMMN_run-*_eeg.vhdr' ];		% VODMMN only, test w/ display?
		vhdr = dir( fullfile( bidsDir, vhdrFmt ) );
% 	end
	nHdr = numel( vhdr );
%}
	
	if exist( 'VODMMNruns', 'var' ) ~= 1
		VODMMNruns = [];
	end
	if exist( 'AODruns', 'var' ) ~= 1
		AODruns = [];
	end
	if exist( 'ASSRruns', 'var' ) ~= 1
		ASSRruns = [];
	end
	if exist( 'RestEOruns', 'var' ) ~= 1
		RestEOruns = [];
	end
	if exist( 'RestECruns', 'var' ) ~= 1
		RestECruns = [];
	end

	% VIS channel gets removed
	eeg = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, Inf ], [ -1, 2 ] );

	% mean reference, nothing fancy, don't want interpolations here
	kRef = ~ismember( { eeg.chanlocs.labels }, { 'TP9', 'TP10' } );
	eeg.data(:) = bsxfun( @minus, eeg.data, mean( eeg.data(kRef,:), 1 ) );

	% these will not be integers but halfway between
	Iboundary = [ eeg.event(strcmp( { eeg.event.type }, 'boundary' )).latency ];
	Tsegment  = diff( [ ceil( Iboundary ), eeg.pnts ] ) / eeg.srate;
	
	kUse = Tsegment > 180;

	error( 'under construction' )
	

end