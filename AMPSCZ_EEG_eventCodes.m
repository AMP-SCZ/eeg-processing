function [ standardCode, targetCode, novelCode, respCode ] = AMPSCZ_EEG_eventCodes( epochName )
% Event codes associated with different AMP SCZ EEG analyses.
% This is distinct from AMPSCZ_EEG_taskSeq.m because VOD & MMN will get analyzed separately
% from the same set of runs.
%
% USAGE:
% >> [ standardCode, targetCode, novelCode, responseCode ] = AMPSCZ_EEG_eventCodes( epochName )
%
% where:
% epochName is one of 'VOD', 'AOD', 'MMN', 'ASSR', 'RestEO', 'RestEC'
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 10/14/2021

	narginchk( 1, 1 )

	if ~ischar( epochName )	% switch will throw error if input not scalar or char
		error( 'non-char epochName input' )
	end
	switch epochName
		case 'VOD'
			% 128 standard, 16 target, 16 novel
			% spacing: ~1.7 -  2.3 s including standards
			%          ~5   - 15   s excluding standards
			standardCode = 'S 32';
			targetCode   = 'S 64';
			novelCode    = 'S128';
			respCode     = 'S 17';
		case 'MMN'
			% 578 tone1 (90.3%), 62 tone2
			% spacing:  0.501 - 0.503 s including tone1
			%          ~1    - 16     s excluding tone1
			standardCode = 'S 16';		% tone1
			targetCode   =     [];
			novelCode    = 'S 18';		% tone2, not really novel, 'deviant'
			respCode     = 'S 17';		% should be no responses to tones, but they'd get visual codes?
		case 'AOD'
			% 160 standard, 20 target, 20 novel
			% spacing: ~1.1 - 1.4 s including standards
			%          ~3   - 9   s excluding standards
			standardCode = 'S  1';
			targetCode   = 'S  2';
			novelCode    = 'S  4';
			respCode     = 'S  5';
		case 'ASSR'
			% 200 standard
			% Half a second of ~1 ms (44 samples @ 44100 Hz) pulses every ~25 ms (1102 audio samples).  ~40 Hz
			% repeated every 1101 (occasionally 1102) 1000 Hz EEG samples.
			standardCode = 'S  8';
			targetCode   =     [];
			novelCode    =     [];
			respCode     =     [];
		case 'RestEO'
			% 180 standard
			standardCode = 'S 20';
			targetCode   =     [];
			novelCode    =     [];
			respCode     =     [];
		case 'RestEC'
			% 180 standard
			standardCode = 'S 24';
			targetCode   =     [];
			novelCode    =     [];
			respCode     =     [];
		otherwise
			error( 'unknown epoch name %s', epochName )
	end

end
