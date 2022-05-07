function AMPSCZ_EEG_lineNoise( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

	powerType = 'worst';

	narginchk( 2, 7 )
	
%{
% 	if false
% 		[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( 'all' );
% 		vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, false );
% 	else	% faster if you're for sure finding all vhdr files
		bidsDir     = fullfile( AMPSCZ_EEG_procSessionDir( subjectID, sessionDate ), 'BIDS' );
		if ~isfolder( bidsDir )
			error( '%s is not a valid directory', bidsDir )
		end
% 		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-*_run-*_eeg.vhdr' ];
		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-VODMMN_run-*_eeg.vhdr' ];		% VODMMN only, test w/ display?
		vhdr = dir( fullfile( bidsDir, vhdrFmt ) );
% 	end
	nHdr = numel( vhdr );
%}
	
	siteInfo = AMPSCZ_EEG_siteInfo;
	kSite    = ismember( siteInfo(:,1), subjectID(1:2) );
	fLine    = siteInfo{kSite,4};

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

	% VIS channel gets removed, data are resampled & filtered and chronologcially sorted
	eeg = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, Inf ], [ -1, 2 ] );

	% mean reference, nothing fancy, don't want interpolations here
	kRef = ~ismember( { eeg.chanlocs.labels }, { 'TP9', 'TP10' } );
	eeg.data(:) = bsxfun( @minus, eeg.data, mean( eeg.data(kRef,:), 1 ) );

	% these will not be integers but halfway between
	IboundaryEvent = find( strcmp( { eeg.event.type }, 'boundary' ) );
	IboundaryData  = [ eeg.event(IboundaryEvent).latency ];
	Tsegment  = diff( [ ceil( IboundaryData ), eeg.pnts ] ) / eeg.srate;
	
	tSegment     = 180;
	kUse         = Tsegment > tSegment;
	newEventName = 'noiseTest';
	[ eeg.event(IboundaryEvent(kUse)).type ] = deal( newEventName );

	eeg = pop_epoch( eeg, { newEventName }, [ 0, tSegment ] + 0.5/eeg.srate );

	nfft = eeg.pnts;	% 180 s * 250 Hz = 45000 samples, frequency resolution = 0.0056 Hz
	nu   = floor(   nfft       / 2 ) + 1;		% # unique points in spectrum
	n2   = floor( ( nfft + 1 ) / 2 );			% index of last non-unique point in spectrum

	f = (0:nu-1) * ( eeg.srate / nfft );
	P = fft( bsxfun( @times, eeg.data, shiftdim( hann( nfft, 'periodic' ), -1 ) ), nfft, 2 );
	P = abs( P(:,1:nu,:) ) / nfft;		% amplitude
	P(:,2:n2,:) = P(:,2:n2,:) * 2;		% double non-unique freqencies
	P(:) = P.^2;						% power
	
	wf   = 0.25;		% width around line frequency to sum (Hz)
	kDen = f >= 1 & f <= 80;
	kNum = kDen;
	kNum(kNum) = abs( f(kNum) - fLine ) <= wf;
	
	P = permute( sum( P(:,kNum,:), 2 ) ./ sum( P(:,kDen,:), 2 ) * 100, [ 1, 3, 2 ] );		% 63 channels x #runs
	
	switch powerType
		case 'best'
			P = min( P, [], 2 );
		case 'worst'
			P = max( P, [], 2 );
		case 'mean'
			P = mean( P, 2 );
		case 'median'
			P = median( P, 2 );
		case 'first'
			P = P(:,1);
		case 'last'
			P = P(:,end);
	end

	locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
	eeg = pop_chanedit( eeg, 'lookup', locsFile );

	topoOpts = AMPSCZ_EEG_topoOptions( AMPSCZ_EEG_GYRcmap( 256 ) );
	
	clf
	topoplot( P, eeg.chanlocs, topoOpts{:} )%, 'electrodes', 'ptslabels' );
	set( gca, 'CLim', [ 0, 10 ] )
	xlabel( sprintf( 'power @ %g Hz (%%)\n%s of %d', fLine, powerType, eeg.trials ), 'Visible', 'on' )
% 	title( sprintf( '%s - %s', subjectID, sessionDate ) )
	
	
% 	error( 'under construction' )
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

end