function RTrange = AMPSCZ_EEG_RTrange
% Range of allowed reaction times in AMPSCZ tasks.
% Created this super-simple function make sure that
% AMPSCZ_EEG_QA.m & AMPSCZ_EEG_preprocEEG.m use the same range
%
% Usage:
% >> RTrange = AMPSCZ_EEG_RTrange;
%
% RTrange = [ 0.1, 1.1 ] ms
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 12/06/2021

	narginchk( 0, 0 )

	% shortest interval bewteen [standars,target,novel] is ~1.1 sec (AOD) & ~1.7 sec (VOD)
	% setting the maximum range <= 1.1 will remove any ambiguity about what was being responded to
	% 100ms should be safely low enough to not throw out anything humanly possible
	%
	% minimum RT for hit?  ( ~0.25 visual, ~0.17 auditory, ~0.15 tactile ) literature has good deal of variability

	RTrange = [ 0.1, 1.1 ];		% (ms)

	return
	
end