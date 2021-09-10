%--------------------------------------------------------------------------
% Name : convertBVR2BIDS.m
% 
% Author : Brian Roach
% 
% Creation Date : 4/14/2021
% 
% Purpose : This script is an example instance of converting the brain
% vision recorder formatted continuous EEG files (i.e., vhdr header, vmrk
% marker file, and .eeg data file) output from the neuroSig systems to a
% BIDS-compliant data set with each run, and paradigm separately broken out
% as required by the Brain Imaging Data Structure.
%
% I am exclusively using EEG lab functions, and in particular their BIDS
% plugin, downloaded from https://github.com/sccn/bids-matlab-tools
%
% Usage : convertBVR2BIDS.m
%
% Inputs :
%   None as currently setup, but it would make sense to change this to a
%   function like convertBVR2BIDS(zipped file OR raw files path) so that it
%   can work on data downloaded from various sites.  Also, having the NDAR
%   id would facilitate labeling the BIDS-EEG output with the NDAR GUID
%   that will be linked to other data in the NDA, and it would also
%   anonymize the data (e.g., site, network, and study-specific subject ID
%   will be removed).
%
% Outputs : 
%   BIDS
%
% Last modified:  4/15/2021
%
% Last run : 
%
%--------------------------------------------------------------------------

%pwd = R:\ERP Research\Brian's Research Folder\Research\Studies\ProNET\Data\EEG000020-13042021-1721UTC\Vision\Raw Files

%eventually, you will need to check to see if this subject has any other
%data (e.g., if she has data, this new data file must be a repeat or
%follow-up session, if no data, it is the baseline session).  For this
%example, we assume it is session 1
theSession = 1;

%add the bids plugin for EEGlab to the path as it is not in the default
%path:
addpath('R:\ERP Research\Brian''s Matlab Stuff\eeglab14_1_1b\plugins\bids-matlab-tools-master\')

%load the data into EEG lab 'EEG' structure:
EEG = pop_loadbv(pwd, 'EEG000020-13042021-1721UTC.vhdr')

%find the 'New Segment' boundary events that occur at the start of each run
%in the continuous EEG data, they look like:
%-------------------------------------------
% EEG.event(1)
% 
% ans = 
% 
%   struct with fields:
% 
%      latency: 1
%     duration: NaN
%      channel: 0
%       bvtime: 718064813
%      bvmknum: 1
%         type: 'boundary'
%         code: 'New Segment'
%      urevent: 1

runStartEvents = find(arrayfun(@(E) strcmp(EEG.event(E).type, 'boundary'), 1:length(EEG.event)));

%if the session is complete and all contained in one file, there will be 12
%events, corresponding to these 12 runs (in order):
% (1) Visual oddball + MMN run 1
% (2) Auditory oddball run 1
% (3) Visual oddball + MMN run 2
% (4) Auditory oddball run 2
% (5) Visual oddball + MMN run 3
% (6) Auditory oddball run 3
% (7) Visual oddball + MMN run 4
% (8) Auditory oddball run 4
% (9) Visual oddball + MMN run 5
% (10) Gamma Steady State run 1 (only one run for this task)
% (11) eyes open resting state
% (12) eyes closed resting state

%use a cell array of strings to label output files:
paradigms = {'VisMMN', 'AudODD', 'VisMMN', 'AudODD', 'VisMMN', 'AudODD', 'VisMMN', 'AudODD', 'VisMMN', 'SS40', 'RestEO', 'RestEC'};

%and an equal length vector of run numbers:
runNums = [1 1 2 2 3 3 4 4 5 1 1 1];

%there should be no way for the neuroSig system to allow users to record
%data in any order other than that specified above, however, we can still
%do some error-checking to confirm the paradigm-specific expected triggers
%are present.  The triggers are:
% =======================================
% 
% Auditory Task:
% 
% Standard 1
% Target 2
% Novel 4
% Response 5
% 
% ========================================
% 
% Visual Task:
% 
% Tone1 16
% Tone2 18
% Response 17
% Standard 32
% Target 64
% Novel 128
% 
% ========================================
% 
% ASSR:
% 
% ClickTrain 8
% 
% ========================================
% 
% Resting State, Eyes Open:
% 
% 1second 20
% 
% ========================================
% 
% Resting State, Eyes Closed:
% 
% 1second 24
% 
% ========================================

%store one expected event per run for verification:
eventKey = {'S 32', 'S  1', 'S 32', 'S  1', 'S 32', 'S  1', 'S 32', 'S  1', 'S 32', 'S  8', 'S 20', 'S 24'};

if length(runStartEvents) ~=12
    error('12 runs are expected in the continuous file')
    %this case will need to be updated to be more robust to deviation from
    %expected file size.  For example, if runs were repeated, aborted,
    %skipped, etc.
else
    %assumes a perfect run, but confirm triggers match expectations and
    %write out temp .set files for bids conversion
    
    for r = 1:length(runStartEvents)
        %if it is the last run, you cannot end at r+1, use EEG.pnts instead
        if r == length(runStartEvents)
            mySet = pop_select(EEG, 'point', [EEG.event(runStartEvents(r)).latency EEG.pnts]);
        else
            mySet = pop_select(EEG, 'point', [EEG.event(runStartEvents(r)).latency (EEG.event(runStartEvents(r+1)).latency)-1]);
        end
        
        %now confirm that mySet has the expected triggers from eventKey:
        if any(arrayfun(@(E) strcmp(mySet.event(E).type, eventKey{r}), 1:length(mySet.event)))
            %this means we are OK to proceed, write a data set to local
            %dir:
            mySet = pop_saveset(mySet, 'filename', [paradigms{r} num2str(runNums(r))]);
        else
            fprintf('There are not any of the expected %s events in run %d of the datafile, which should be %s\n\n', eventKey{r}, r, [paradigms{r} num2str(runNums(r))])
            error('Unexpected run order based on event markers in EEG files')
        end
        
        %the BIDS export can then be run by specifying the appropriate .set
        %file, as demonstrated in https://github.com/sccn/bids-matlab-tools/blob/master/bids_export_example.m
        if r==1
            %initialize:
            data(1).file = {fullfile(pwd, [paradigms{r} num2str(runNums(r)) '.set'])};
            data(1).session = theSession;
            data(1).run     = runNums(r);
            data(1).task    = paradigms(r);
        else
            data(1).file = [data(1).file fullfile(pwd, [paradigms{r} num2str(runNums(r)) '.set'])];
            data(1).session = [data(1).session theSession];
            data(1).run     = [data(1).run runNums(r)];
            data(1).task    = [data(1).task paradigms(r)];
        end
    end
    
    %export:
    bids_export(data)
end