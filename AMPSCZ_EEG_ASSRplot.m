function AMPSCZ_EEG_ASSRplot( subjectID, sessionDate, networkName, writeFlag )
% AMPSCZ_EEG_ASSRplot( subjectID, sessionDate, networkName, writeFlag )


	narginchk( 2, 4 )
	if exist( 'networkName', 'var' ) ~= 1
		networkName = [];
	end
	if exist( 'writeFlag', 'var' ) ~= 1
		writeFlag = [];
	end
	
	[ sessionDir, networkName ] = AMPSCZ_EEG_procSessionDir( subjectID, sessionDate, networkName );
	filterStr = '[0.2,Inf]';
	matFile = fullfile( sessionDir, 'mat', [ subjectID, '_', sessionDate, '_ASSR_', filterStr, '.mat' ] );
	if exist( matFile, 'file' ) ~= 2
		error( '%s does not exist', matFile )
	end

	toiRange  = [ -0.248, 0.748 ];		% choose endpoint that will be in EEG.times, i.e. multiples of 4ms
	foi       = (4:2:100)';
	tBaseline = [ -0.200, -0.100 ];					% temporal region of time-frequency power baseline adjustment
	tAvg      = [ 0, 0.5 ] + [ 1, -1 ]*0.1;			% temporal region of time-frequency images to average
	fASSR     = 40;
	fPlot     = [ 10, Inf ];						% frequency range of time-frequency images to plot
	tPlot     = [ -0.1, 1 ];						% temporal range of EEG epoch to plot in ERP axis
	chanPlot  = { 'FCz', 'TP9', 'TP10' };
% 	nPlot     = numel( chanPlot );
	
	iFreq = find( foi == fASSR );
	kfPlot = foi >= fPlot(1) & foi <= fPlot(2);

	% filter for ERP plots, mainly want to see 40 Hz
	fs   = 250;
	fNyq = fs / 2;
	Wp   = ( fASSR + [ -1, 1 ]* 5 ) / fNyq;
	Ws   = ( fASSR + [ -1, 1 ]*20 ) / fNyq;
	Rp   =  0.2;
	Rs   = 20;
	[ nEllip, wEllip ] = ellipord( Wp, Ws, Rp, Rs );
	[ bEllip, aEllip ] = ellip( nEllip, Rp, Rs, wEllip, 'bandpass' );
	ellipStr = sprintf( 'pass band = [ %g, %g ] Hz', wEllip * fNyq );

	load( matFile )
	if EEG.srate ~= fs
		error( 'unexpected sampling rate' )
	end
	
	% channel x frequency x time 3D arrays
	[ POW, ITC, PLA, EPM, toi, ERP, t, chanLabel ] = AMPSCZ_EEG_ASSRanalysis( EEG, toiRange, foi );
	[ ~, ILabel ] = ismember( chanLabel, { EEG.chanlocs.labels } );
	chanlocs = EEG.chanlocs(ILabel);

	% single channel, set of channels?
% 	iChan = find( strcmp( chanLabel, 'Fz' ) );
	iChan = find( strcmp( chanLabel, 'FCz' ) );
% 	iChan = find( strcmp( chanLabel, 'Cz' ) );

	kTime = toi >= tAvg(1) & toi <= tAvg(2);
	[ ~, IPlot ] = ismember( chanPlot, chanLabel );
	if any( IPlot == 0 )
		error( 'non-existent channel(s)' )
	end
	ktPlot =   t >= tPlot(1) &   t <= tPlot(2);

	% convert power to dB units relative to baseline
	kBaseline = toi >= tBaseline(1) & toi <= tBaseline(2);
	POW(:) = log10( bsxfun( @rdivide, POW, mean( POW(:,:,kBaseline), 3 ) ) )*10;
	EPM(:) = log10( bsxfun( @rdivide, EPM, mean( EPM(:,:,kBaseline), 3 ) ) )*10;
% 	POW(:) = bsxfun( @rdivide, POW, mean( POW(:,:,kBaseline), 3 ) );
% 	EPM(:) = bsxfun( @rdivide, EPM, mean( EPM(:,:,kBaseline), 3 ) );
	% delta ITC?
	ITC(:) =        bsxfun( @minus  , ITC, mean( ITC(:,:,kBaseline), 3 ) );

	Wave = filter( bEllip, aEllip, ERP(IPlot,:)' );

	hFig = figure( 'Position', [ 300 100 1400 900 ], 'Tag', mfilename );
	hAx = AMPSCZ_EEG_timeFreqPlot( toi*1e3, foi(kfPlot),...
		shiftdim( cat( 4, POW(iChan,kfPlot,:), EPM(iChan,kfPlot,:), ITC(iChan,kfPlot,:) ), 1 ),...
		[ mean( POW(:,iFreq,kTime), 3 ), mean( EPM(:,iFreq,kTime), 3 ), mean( ITC(:,iFreq,kTime), 3 ) ], chanlocs,...
		t(ktPlot)*1e3, Wave(ktPlot,:),...
		sprintf( '%s %s %s', networkName, subjectID, sessionDate ), { 'POW (dB)', 'EPM (dB)', '\DeltaITC' }, chanLabel{iChan},...
		sprintf( '40 Hz\nMean [%g,%g] ms', tAvg*1e3 ), chanPlot, hFig );
	set( hAx(end), 'XLim', tPlot*1e3 )
	title( hAx(end), ellipStr )
	
	pngDir = fullfile( sessionDir, 'Figures' );
	pngOut = fullfile( pngDir, [ subjectID, '_', sessionDate, '_ASSR_', filterStr, '.png' ] );
	
	if isempty( writeFlag )
		writeFlag = exist( pngOut, 'file' ) ~= 2;		
		if ~writeFlag
			writeFlag(:) = strcmp( questdlg( 'Replace ASSR png?', mfilename, 'no', 'yes', 'no' ), 'yes' );
		end
	end
	if writeFlag
		if ~isfolder( pngDir )
			mkdir( pngDir )
			fprintf( 'created %s\n', pngDir )
		end
		% print( hFig, ... ) & saveas( hFig, ... ) don't preserve pixel dimensions
		figPos = get( hFig, 'Position' );		% is this going to work on BWH cluster when scheduled w/ no graphical interface?
		img = getframe( hFig );
		img = imresize( img.cdata, figPos(4) / size( img.cdata, 1 ), 'bicubic' );		% scale by height
		imwrite( img, pngOut, 'png' )
		fprintf( 'wrote %s\n', pngOut )
	end

