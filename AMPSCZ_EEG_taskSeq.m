function [ taskInfo, taskSeq ] = AMPSCZ_EEG_taskSeq
% AMP SCZ task info and sequence
%
% USAGE:
% >> [ taskInfo, taskSeq ] = AMPSCZ_EEG_taskSeq
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 09/27/2021


	% AMP SCZ EEG task sequence:        run #
	% ( 1) Visual oddball + MMN             1
	% ( 2) Auditory oddball                 1
	% ( 3) Visual oddball + MMN             2
	% ( 4) Auditory oddball                 2
	% ( 5) Visual oddball + MMN             3
	% ( 6) Auditory oddball                 3
	% ( 7) Visual oddball + MMN             4
	% ( 8) Auditory oddball                 4
	% ( 9) Visual oddball + MMN             5
	% (10) Auditory steady-state response   1
	% (11) Resting state, eyes open         1
	% (12) Resting state, eyes closed       1


% 	narginchk( 0, 0 )

	% sequence# 1  2  3  4  5  6  7  8  9 10 11 12
	% run#      1  1  2  2  3  3  4  4  5  1  1  1
	taskSeq = [ 1, 2, 1, 2, 1, 2, 1, 2, 1, 3, 4, 5 ];
	
	% { name, valid event codes, descriptions }
	% event codes are { S#, description, expected # in run }
	% note: there can be VOD response codes in AOD runs
	%       if the participant pushed button too late
	taskInfo = { 
		'VODMMN', {
			 32, 'Standard', 128
			 64, 'Target'  ,  16
			128, 'Novel'   ,  16
			 17, 'Response',  []
			 16, 'MMNstd'   , 578
			 18, 'MMNdev'   ,  62 }, 'Visual Oddball + Mismatch Negativity'
		'AOD', {
			  1, 'Standard', 160
			  2, 'Target'  ,  20
			  4, 'Novel'   ,  20
		 [5,17], 'Response',  [] }, 'Auditory Oddball'
		'ASSR',   {  8, 'ClickTrain', 200 }, 'Auditory Steady-State Response'		% 'ClickTrain' label came from BJR
		'RestEO', { 20, '1second'   , 180 }, 'Resting State, Eyes Open'				% '1second' labels came from BJR
		'RestEC', { 24, '1second'   , 180 }, 'Resting State, Eyes Closed'
	};

	return

%{

	% how to identify which task a code is from, check which row of taskInfo has the code in it's 1st column of taskInfo{i,2}
		code = 1;
		kTask = cellfun( @(u) ismember( code, cellfun( @(v) v(1), u(:,1) ) ), taskInfo(:,2)  );

	% how to identify a task from a full sequence of codes, look for the primary code of each task in the sequence
		sequence = [ 1 2 4 5 ];
		sequence = sequence( ceil( rand( 1, 100 ) * numel( sequence ) ) );
		kTask = cellfun( @(u) ismember( u{1,1}, sequence ), taskInfo(:,2) );

%}


end


