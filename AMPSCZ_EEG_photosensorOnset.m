function Ionset = AMPSCZ_EEG_photosensorOnset( sensorDataMicroVolts )
% get indices of pulse onsets from photosensor channel data
% note: this function expects the input vector is in microVolt units
%       and sampled at 1000Hz
%
% usage:
% >> Ionset = AMPSCZ_EEG_photosensorOnset( sensorDataMicroVolts )

	% pulse duration = 31-32 60Hz refreshes
	% there should be 160 of them
	% interval is ~normally distributed w/ 2000ms mean & 300/2.3 std
	
	narginchk( 1, 1 )
	if ~isnumeric( sensorDataMicroVolts ) || ~isvector( sensorDataMicroVolts )
		error( 'input must be numeric vector' )
	end
	n = numel( sensorDataMicroVolts );
	if ~isa( sensorDataMicroVolts, 'double' )
		sensorDataMicroVolts = double( sensorDataMicroVolts );
	end
	v     = sort( sensorDataMicroVolts, 'ascend' );
	valLo = v( round( 0.7 * n ) );
	valHi = v( round( 0.8 * n ) );	
	if valHi - valLo > 6e4
		nEnd = 10;		% this is assuming 1000 Hz sampling rate, no downsampling!
		nGap = 40;
		v(:) = ( sensorDataMicroVolts > ( valLo + valHi ) / 2 ) * 2 - 1;
		Ionset    = filter( [  ones(1,nEnd), zeros(1,nGap), -ones(1,nEnd) ], 1, v ) == 2*nEnd;
		Ionset(:) = [ false, Ionset(2:n) & ~Ionset(1:n-1) ];
		Ionset    = find( Ionset ) - nEnd;			% these end up 20-21 samples after event markers
%		Ioffset    = filter( [ -ones(1,nEnd), zeros(1,nGap),  ones(1,nEnd) ], 1, sensorDataMicroVolts ) == 2*nEnd;
%		Ioffset(:) = [ false, Ioffset(2:n) & ~Ioffset(1:n-1) ];
%		Ioffset    = find( Ioffset ) - nEnd;
		nOnset = numel( Ionset );
		if nOnset == 0
			return
		end
		% now back up from middle closer to edge of onset wave
		% this should get you 16-17 samples after event markers
		% not any justification in the waveform for going further,
		% this is a single 16.7 ms screen refresh interval
		thresh = valLo + ( valHi + valLo ) * 0.01;
		kThresh = sensorDataMicroVolts(1:Ionset(1)) < thresh;
		if ~any( kThresh )
			error( 'bad threshold' )
		end
		Ionset(1) = find( kThresh, 1, 'last' );
		for iOnset = 2:nOnset
			kThresh = sensorDataMicroVolts(Ionset(iOnset-1)+1:Ionset(iOnset)) < thresh;
			if ~any( kThresh )
				error( 'bad threshold' )
			end
			Ionset(iOnset) = Ionset(iOnset-1) + find( kThresh, 1, 'last' );
		end
	else
		Ionset = [];
	end

end