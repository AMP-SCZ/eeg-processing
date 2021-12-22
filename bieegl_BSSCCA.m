function [ eeg, stats ] = bieegl_BSSCCA( eeg, IchanEEG, betaBand, nBoot, CI )
% blind source separation - canonical correlation analysis
% remove white noise from mix of white & 1/f noise
% e.g. EMG from EEG
%
% USAGE:
% >> [ eeg, stats ] = bieegl_BSSCCA( eeg, IchanEEG, betaBand, nBoot, CI )

% betaBand defines range of power spectrum to fit with linear log(power) vs log(frequency) model
%	betaBand(1) < frequency <= betaBand(2)

% to do:
% reorganize the stats output
% maybe need IchanInterp to check if refChan is interpolated?   or give up on pre-allocating A,r,U - YES

		narginchk( 5, 5 )

		nEEG = numel( IchanEEG );
		nfft = eeg.pnts;
		nu   = floor(   nfft       / 2 ) + 1;		% # unique points in spectrum
		n2   = floor( ( nfft + 1 ) / 2 );			% index of last non-unique point in spectrum

		fftWin = hanning( nfft );
		
		f        = eeg.srate / nfft * (0:nu-1)';
		kBand    = f > betaBand(1) & f <= betaBand(2);
		nBand    = sum( kBand );
		betaX    = [ log( f(kBand) ), ones( nBand, 1 ) ];
		Irand    = zeros( nBand, 1 );
		Iboot    = (1:nBoot)';
		Iinterp  = ( 1 + [ -1, 1 ]*CI ) / 2 * nBoot;
			
		stats    = nan( eeg.trials, 9, nEEG );		% stuff BJR was adding into eeg.stats
				
		for iEpoch = 1:eeg.trials

			% transpose to samples x channels, eeg.pnts x numel( IchanEEG )
			X = eeg.data(IchanEEG,:,iEpoch)';
			Y = [ zeros( 1, numel( IchanEEG ) ); X(1:end-1,:) ];		% Y(i,:) = X(i-1,:)

			% center the data:
			X(:) = bsxfun( @minus, X, mean( X, 1 ) );
			Y(:) = bsxfun( @minus, Y, mean( Y, 1 ) );

			% run the cca:
			% [ A, B, r, U, V, stats ] = canoncorr( X, Y )
			% if   X = n x d1
			%      Y = n x d2
			% then d = min( rank( X ), rank( Y ) )
			%      A = d1 x d		canonical coefficients for X
			%      B = d2 x d		                           Y 
			%      r =  1 x d		canonical correlations
			%      U =  n x d		canonical scores for X
			%      V =  n x d		                     Y
			% where U = detrend(X,'constant')*A
			%       V = detrend(Y,'constant')*B
			%       r(i) = corrcoef( U(:,i), V(:,i) )
			% and A & B maximize r
			[ A, ~, r, U ] = canoncorr( X, Y );
			nCCA     = numel( r );

			% choose which components to keep
% 			doSlopeEst = true;
% 			if doSlopeEst
				% FFT of hanning windowed data:
				Ufft           = fft( bsxfun( @times, U, fftWin ), nfft, 1 );
				Upower         = Ufft(1:nu,:)   / nfft;
				Upower(2:n2,:) = Upower(2:n2,:) * 2;
%				Upower(:) = Upower .* conj( Upower );
				Upower(:) = abs( Upower ).^2;
				Upower(:) = log( Upower );

				% try a bootstrap procedure to obtain non-parametric confidence intervals:
				beta     = zeros(     2, nCCA );
				betaBoot =   nan( nBoot, nCCA );
				for iBoot = 1:nBoot
					Irand(:) = ceil( rand( nBand, 1 ) * nBand );
					beta(:)  = betaX(Irand,:) \ Upower(Irand,:);
					betaBoot(iBoot,:) = beta(1,:);
				end
				betaCI = interp1( Iboot, sort( betaBoot, 1, 'ascend' ), Iinterp, 'pchip' );
				kClean = betaCI(1,:) < -1;		% throw out components where slope confidence interval is above -1

				% slope estimated from all frequencies in band
				beta(:) = betaX \ Upower(kBand,:);
% 			else
% 				kClean = r > 0.75;		% what would this threhold be?
% 			end

			% reconstruct the data from selected components
% 			switch 3
% 				case 1
					kNonzero = any( A ~= 0, 2 );		% channels (rows) that have least 1 non-zero column in A
					if all( kNonzero )					% A should be square
						Aclean = inv( A )';
					else
						Aclean = inv( A(kNonzero,:) )';
					end
% 					Aclean(:,~kClean) = 0;
% 					eeg.data(IchanEEG(kNonzero),:,iEpoch) = Aclean * U';
					eeg.data(IchanEEG(kNonzero),:,iEpoch) = Aclean(:,kClean) * U(:,kClean)';
% 				case 2
% 					% this method doesn't require identifying subset of chanels from rows of A
% 					% but can make some reconstructed channels have very little signal, better to leave them untouched as above?
% 					Aclean = pinv( A );
% 					eeg.data(IchanEEG,:,iEpoch) = ( U(:,kClean) * Aclean(kClean,:) )';
% 				case 3
% 					kNonzero = any( A ~= 0, 2 );		% channels (rows) that have least 1 non-zero column in A
% 					Aclean   = pinv( A );
% 					eeg.data(IchanEEG(kNonzero),:,iEpoch) = ( U(:,kClean) * Aclean(kClean,kNonzero) )';
% 			end
			
			
			% r contains the correlation coefficients, which we will store:
			% store the ratio of high (30-200) to low (1-30) frequency power, excluding
			% 60 Hz which may exert strong influence on the upper-band mean
			stats(iEpoch,1,1:nCCA) = r;
% 			if doSlopeEst
				% normalized power (to total of 1):
				kBandN  = f <= 125;
				Unorm   = bsxfun( @rdivide, Upower, sum( Upower(kBandN,:), 1 ) );
				kBandM1 = f >= 15 & f <= 125 & ~( f > 57 & f < 63 );
				kBandM2 = f > 1 & f < 15;
				UpowerM = median( Upower(kBandM1,:), 1 );		% could calculate stats(iEpoch,3,:) first then divide w/ shiftdim.
				kBandS  = f >= 15 & f <= 125;
				kBandC  = kBandN;

				stats(iEpoch,2,1:nCCA) = UpowerM ./ median( Upower(kBandM2,:), 1 );
				stats(iEpoch,3,1:nCCA) = UpowerM;
				stats(iEpoch,4,1:nCCA) = sum( Unorm(kBandS,:), 1 );
				stats(iEpoch,5,1:nCCA) = corr(      f(kBandC)  ,      Upower(kBandC,:), 'type', 'Spearman' );		% Spearman = Pearson of ranking
				stats(iEpoch,6,1:nCCA) = corr( log( f(kBandC) ), log( Upower(kBandC,:) )                   );		% default = Pearson
				stats(iEpoch,7,1:nCCA) = beta(1,:);
				stats(iEpoch,8,1:nCCA) = betaCI(1,:);
				stats(iEpoch,9,1:nCCA) = betaCI(2,:);
% 			end

		end

		return
		
%% simulation tests
%{

	fprintf( '\n\n\n--------\n' )
	clear

	nt  = 3000;		% # time samples
	nc  = 64;		% # channels
	ne  = 200;		% # epochs
	nE  = 100;		% # eeg sources
	nM  = 50;		% # emg sources
	snr = inf;
	EEG = zscore( cumsum( randn( [ nt*ne, nE ] ), 1 ), 0, 1 ) * randn( nE, nc );
	EMG = zscore(         randn( [ nt*ne, nM ] )     , 0, 1 ) * randn( nM, nc );

%	EEG = reshape( EEG, [ nt, ne, nc ] );
%	EMG = reshape( EEG, [ nt, ne, nc ] );

	D   = EEG + EMG * 5e-1;		% simulated data, noise free
	
	sigmaEEG = std( EEG, 0, 1 );
	sigmaEMG = std( EMG, 0, 1 );
	sigma    = std(   D, 0, 1 );
	
	% add white noise
	if ~isinf( snr )
		Zw = randn( nt*ne, nc ) * diag( sigma / snr );
%		Zw = randn( nt*ne, nc ) * mean( sigma ) / snr;
		D(:) = D + Zw;
	end
	
	% 60 Hz noise (w/ uniform random phase?)
% 	Zs = sin( 2*pi*60/1000*(1:nt*ne)' + 2*pi*rand(1,nc) );
% 	Zs(:) = Zs * diag( rand(1,nc) * mean( sigma ) );
% 	D(:) = D + Zs;
	
	% re-reference
% 	iRef = nc + 1;
	iRef = 1:2;
	D(:)   = bsxfun( @minus,   D, mean(   D(:,iRef), 2 ) );
	EEG(:) = bsxfun( @minus, EEG, mean( EEG(:,iRef), 2 ) );
	EMG(:) = bsxfun( @minus, EMG, mean( EMG(:,iRef), 2 ) );
	
	D   = permute( reshape(   D, [ nt, ne, nc ] ), [ 3, 1, 2 ] ) ;
	EEG = permute( reshape( EEG, [ nt, ne, nc ] ), [ 3, 1, 2 ] ) ;
	EMG = permute( reshape( EMG, [ nt, ne, nc ] ), [ 3, 1, 2 ] ) ;
% 	D(:)    = bsxfun( @minus,   D, mean(   D, 2 ) );
% 	EEG(:)  = bsxfun( @minus, EEG, mean( EEG, 2 ) );
% 	EMG(:)  = bsxfun( @minus, EMG, mean( EEG, 2 ) );

	if ~isinf( snr )
		Zw = permute( reshape( Zw, [ nt, ne, nc ] ), [ 3, 1, 2 ] );
	end
	
	iEEG = 1:nc;
	iEEG = setdiff( iEEG, iRef(end) );
	
	eeg1 = struct( 'pnts', nt, 'srate', 1000, 'trials', ne, 'data', D );
	[ eeg2, stats ] = bieegl_BSSCCA( eeg1, iEEG, [ 0, 125 ], 1e3, 0.95 );
	disp( 'done' )

	clf
	i = 1;				% epoch
% 	i = 2;
	j = 1;%:nc;			% channel
	subplot( 1, 2, 1 ), plot( EEG(j,:,i)', eeg1.data(j,:,i)', '.' ), title( corr( EEG(j,:,i)', eeg1.data(j,:,i)' ) )
	subplot( 1, 2, 2 ), plot( EEG(j,:,i)', eeg2.data(j,:,i)', '.' ), title( corr( EEG(j,:,i)', eeg2.data(j,:,i)' ) )

%}
%%
		
end
