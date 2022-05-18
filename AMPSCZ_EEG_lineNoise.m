function P = AMPSCZ_EEG_lineNoise( subjectID, sessionDate, powerType, meanRef, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
% AMPSCZ_EEG_lineNoise( subjectID, sessionDate, powerType, meanRef, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
% powerType = 'first', 'last', 'min', 'max', 'mean', or 'median'

	narginchk( 3, 9 )

	% make sure FieldTrip's not on path
	if ~contains( which( 'hann.m' ), matlabroot )
		AMPSCZ_EEG_matlabPaths( false );
	end

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

	if exist( 'meanRef', 'var' ) ~= 1 || isempty( meanRef )
		meanRef = true;
	end
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

	% add in FCz???
	eeg.nbchan(:) = eeg.nbchan + 1;
	eeg.data(eeg.nbchan,:) = 0;
	eeg.chanlocs(eeg.nbchan).labels = 'FCz';
	locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.elc' );		% does .elc or .ced make any difference?
	eeg = pop_chanedit( eeg, 'lookup', locsFile );
	eeg.data = double( eeg.data );

	% these will not be integers but halfway between
	IboundaryEvent = find( strcmp( { eeg.event.type }, 'boundary' ) );
	IboundaryData  = [ eeg.event(IboundaryEvent).latency ];
	Tsegment  = diff( [ ceil( IboundaryData ), eeg.pnts ] ) / eeg.srate;

	tSegment     = 180;
	kUse         = Tsegment > tSegment;
	newEventName = 'noiseTest';
	[ eeg.event(IboundaryEvent(kUse)).type ] = deal( newEventName );

% 	kRef = ~ismember( { eeg.chanlocs.labels }, { 'TP9', 'TP10' } );
% 	eeg.data(:) = bsxfun( @minus, eeg.data, mean( eeg.data(kRef,:), 1 ) );

	eeg = pop_epoch( eeg, { newEventName }, [ 0, tSegment ] + 0.5/eeg.srate );
	
	% mean reference, nothing too fancy, but do faster-based interpolation
	if meanRef
		kRef  = ~ismember( { eeg.chanlocs.labels }, { 'TP9', 'TP10' } );
		kGood = true( eeg.nbchan, 1 );
		for iTrial = 1:eeg.trials
			kGood(kRef) = ~min_z( channel_properties( eeg.data(kRef,:,iTrial), 1:nnz(kRef), [] ) );
			if any( kGood )
				if all( kGood )
					eeg.data(:,:,iTrial) = bsxfun( @minus, eeg.data(:,:,iTrial), mean( eeg.data(kRef,:,iTrial), 1 ) );
				else
					eegTmp = pop_select( eeg, 'trial', iTrial );
					eegTmp = h_eeg_interp_spl( eegTmp, find(~kGood), [] );			% note: help says 3rd input is interpolation method, but really its channels to ignore!
					eeg.data(:,:,iTrial) = bsxfun( @minus, eeg.data(:,:,iTrial), mean( eegTmp.data(kRef,:), 1 ) );
					clear eegTmp
				end
			end
		end
	end

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
		case 'min'
			P = min( P, [], 2 );
		case 'max'
			P = max( P, [], 2 );
		case 'mean'
			P = mean( P, 2 );
		case 'median'
			P = median( P, 2 );
		case 'first'
			P = P(:,1);
		case 'last'
			P = P(:,end);
		case 'all'
			return
	end

	locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
	eeg = pop_chanedit( eeg, 'lookup', locsFile );

	[ cmap, badChanColor ] = AMPSCZ_EEG_GYRcmap( 256 );
	topoOpts = AMPSCZ_EEG_topoOptions( cmap );
	pLimit   = 10;		% line power limit/threshold

	figure( 'Position', [ 500, 300, 525, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' )		
	hAx = axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
	topoplot( P, eeg.chanlocs, topoOpts{:} );%, 'electrodes', 'ptslabels' );
	set( hAx, 'CLim', [ 0, pLimit ] )
	
	[ topoX, topoY ] = bieegl_topoCoords( eeg.chanlocs );
	kThresh = P > pLimit;
	line( topoY(kThresh), topoX(kThresh), repmat( 10.5, 1, nnz(kThresh) ), 'LineStyle', 'none', 'Marker', 'o', 'Color', badChanColor )

	xlabel( hAx, sprintf( 'Power @ %g Hz (%%)', fLine ), 'Visible', 'on', 'FontSize', 14, 'FontWeight', 'normal' )

% 	title( hAx, sprintf( '%s - %s', subjectID, sessionDate ) )
	colorbar

	text( hAx, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Position', [ 1.35, 0.95, 0 ],...
		'FontSize', 12, 'String', sprintf( [	'{\\it%s} of %d epochs\n\n',...
												'Min. = %0.1f\n',...
												'Max. = %0.1f\n',...
												'Med. = %0.1f\n',...
												'# > %g %% = %d / %d' ],...
		powerType, eeg.trials, min(P), max(P), median(P), pLimit, sum(P>pLimit), numel(P) ) )

end