function AMPSCZ_EEG_alphaRest( subjectID, sessionDate )

	narginchk( 2, 2 )

	% make sure FieldTrip's not on path
	if ~contains( which( 'hann.m' ), matlabroot )
		AMPSCZ_EEG_matlabPaths( false );
	end

	% find source files
	[ RestEOrun, RestECrun ] = deal( 1 );
	vhdrDir = fullfile( AMPSCZ_EEG_procSessionDir( subjectID, sessionDate ), 'BIDS' );
	vhdrFmt =  'sub-%s_ses-%s_task-%s_run-%02d_eeg.vhdr';
	vhdrEO  = sprintf( vhdrFmt, subjectID, sessionDate, 'RestEO', RestEOrun ) ;
	vhdrEC  = sprintf( vhdrFmt, subjectID, sessionDate, 'RestEC', RestECrun ) ;
	if exist( fullfile( vhdrDir, vhdrEO ), 'file' ) ~= 2
		error( 'Rest Eyes Open file %s doesn''t exist', vhdrEO )
	end
	if exist( fullfile( vhdrDir, vhdrEC ), 'file' ) ~= 2
		error( 'Rest Eyes Open file %s doesn''t exist', vhdrEC )
	end

	% load data
	eegEO = pop_loadbv( vhdrDir, vhdrEO );
	eegEC = pop_loadbv( vhdrDir, vhdrEC );
	fs    = 1000;
	if eegEO.srate ~= eegEC.srate || eegEO.srate ~= fs
		error( 'expecting %s Hz data', fs )
	end

	% event marker latencies (samples)
	IEO = [ eegEO.event( strcmp( { eegEO.event.type }, 'S 20' ) ).latency ];
	IEC = [ eegEC.event( strcmp( { eegEC.event.type }, 'S 24' ) ).latency ];

	% pad end by 1 median interval
	IEO = [ IEO(1), min( IEO(end) + median( diff( IEO ) ), eegEO.pnts ) ];
	IEC = [ IEC(1), min( IEC(end) + median( diff( IEC ) ), eegEC.pnts ) ];

	% # samples
	NEO = 1 + diff( IEO );
	NEC = 1 + diff( IEC );

	% trim to integer # seconds ensuring integer # cycles @ 10 Hz
	T = 180;
	nEO = round( T * eegEO.srate );
	nEC = round( T * eegEC.srate );
	if nEO < NEO
		IEO(2) = IEO(1) - 1 + nEO;
	elseif nEO > NEO
		warning( 'Rest Eyes Open event stream not long enough to extract %g sec', T )
	end
	if nEC < NEC
		IEC(2) = IEC(1) - 1 + nEC;
	elseif nEO > NEO
		warning( 'Rest Eyes Closed event stream not long enough to extract %g sec', T )
	end
	eegEO = pop_select( eegEO, 'point', IEO, 'nochannel', { 'VIS' } );
	eegEC = pop_select( eegEC, 'point', IEC, 'nochannel', { 'VIS' } );
% 	[ size( eegEO.data ); size( eegEC.data ) ]		% 63 x 180000

%{
	% downsample to 200 Hz
	% double highest frequency you're going to look at
	% pop_resample filters to avoid aliasing
	fs = 200;
% 	eegEO = pop_resample( eegEO, fs );
% 	eegEC = pop_resample( eegEC, fs );
	eegEO = eegEO.data(:,3:5:eegEO.pnts);
	eegEC = eegEC.data(:,3:5:eegEC.pnts);
	nEO(:) = size( eegEO, 2 );
	nEC(:) = size( eegEC, 2 );
%}
	eegEO = eegEO.data;
	eegEC = eegEC.data;
	
	% trim longer to match shorter
% 	if eegEO.pnts > eegEC.pnts
% 		eegEO = pop_select( eegEO, 'point', [ 1, eegEC.pnts ] );
% 	elseif eegEO.pnts < eegEC.pnts
% 		eegEC = pop_select( eegEC, 'point', [ 1, eegEO.pnts ] );
% 	end
	if nEO > nEC
		nEO(:) = nEC;
		eegEO = eegEO(:,1:nEO);
	elseif nEO < nEC
		nEC(:) = nEO;
		eegEC = eegEC(:,1:nEC);
	end
% 	[ size( eegEO ); size( eegEC ) ]		% 63 x 36000,180000

	% compute power spectra
% 	nfft   = eegEO.pnts;
	nfft   = nEO;
	nu     = floor(   nfft       / 2 ) + 1;		% # unique points in spectrum
	n2     = floor( ( nfft + 1 ) / 2 );			% index of last non-unique point in spectrum
	f      = (0:nu-1) * (fs/nfft);
	fftWin = shiftdim( hann( nfft, 'periodic' ), -1 );
	eegEO = powerspect( eegEO );
	eegEC = powerspect( eegEC );
	function p = powerspect( eeg )
% 		p         = fft( bsxfun( @times, eeg.data, fftWin ), nfft, 2 );
		p         = fft( bsxfun( @times, eeg, fftWin ), nfft, 2 );
		p         = abs( p(:,1:nu) ) / nfft;	% amplitude
		p(:,2:n2) = p(:,2:n2) * 2;				% double non-unique freqencies
		p(:)      = p.^2;						% power
	end
	
%{
	% filter in spectral domain to smooth spectra
	nFilt = 5;		% median filter works well, but gets rid of line noise spike if too high.  this was @ 200 Hz
	if nFilt ~= 1
		eegEO(:) = medfilt1( eegEO, nFilt, [], 2 );		% , 'includenan', 'zeropad' );
		eegEC(:) = medfilt1( eegEC, nFilt, [], 2 );
	end
%}

% 	[ size( eegEO ); size( eegEC ) ]		% 63 x 18001,90001

	kf = f >= 1 & f <= 100;
	kf = find( kf );
% 	kf = kf(1):2:kf(end);		% 0.0111 Hz resolution
% 	kf = kf(1):3:kf(end);		% 0.0167 Hz resolution
	kf = kf(1):4:kf(end);		% 0.0222 Hz resolution
% 	kf = kf(1):5:kf(end);		% 0.0278 Hz resolution
% 	kf = kf(1):6:kf(end);		% 0.0333 Hz resolution
% 	kf = kf(1):8:kf(end);		% 0.0444 Hz resolution
% 	kf = kf(1):9:kf(end);		% 0.05 Hz resolution
% 	kf = kf(1):18:kf(end);		% 0.1  Hz resolution
% 	kf = kf(1):36:kf(end);		% 0.2  Hz resolution

	cOrder = get( 0, 'defaultaxescolororder' );
	fontSize   = 14;
	fontWeight = 'normal';

	figWH = [ 350, 250 ];
	hFig  = figure( 'Position', [ 500, 300, figWH ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
	hAx   =   axes( 'Units', 'normalized', 'Position', [ 0.2, 0.2, 0.75, 0.75 ] );
	hLine = semilogy( f(kf), mean( eegEC(:,kf), 1 ), f(kf), mean( eegEO(:,kf), 1 ) );
% 	hLine = semilogy( f(kf), medfilt1( mean( eegEC(:,kf), 1 ), 5 ), f(kf), medfilt1( mean( eegEO(:,kf), 1 ), 5 ) );
	set( hLine(1), 'Color', cOrder(4,:) )
	set( hLine(2), 'Color', cOrder(5,:) )
	set( [
		text( 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Position', [ 0.95, 0.95 ],...
			'String', sprintf( '\\color[rgb]{%g,%g,%g}Eyes Closed\n\\color[rgb]{%g,%g,%g}Eyes Open', cOrder(4,:), cOrder(5,:) ) )
		ylabel( hAx, 'Mean Power (\muV^2)', 'Units', 'normalized', 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom', 'Position', [ -0.15, 0.5, 0 ] )
		xlabel( hAx, 'Frequency (Hz)' )
		], 'FontSize', fontSize, 'FontWeight', fontWeight )

	set([
	], 'FontSize', fontSize, 'FontWeight', fontWeight )

	set( hAx, 'FontSize', 12, 'YGrid', 'on' )			% this is changing x & y labels' fontsize too! not just tick labels

	return
	
end