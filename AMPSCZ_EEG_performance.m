function [ pVOD, pAOD ] = AMPSCZ_EEG_performance( subjectID, sessionDate, VODMMNruns, AODruns )
% [ pVOD, pAOD ] = AMPSCZ_EEG_performance( subjectID, sessionDate, [VODMMNruns], [AODruns] )
% pVOD, pAOD: 1st column is code for stimulus type, 0=standard, 1=target, 2=novel
%             2nd column in reaction time (s), NaN if no response

	narginchk( 2, 4 )

	if exist( 'VODMMNruns', 'var' ) ~= 1
		VODMMNruns = AMPSCZ_EEG_sessionTaskSegments( subjectID, sessionDate );
	end
	if exist( 'AODruns', 'var' ) ~= 1
		[ ~, AODruns ] = AMPSCZ_EEG_sessionTaskSegments( subjectID, sessionDate );
	end
	
	vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, 0, 0, 0, false );

	taskInfo = AMPSCZ_EEG_taskSeq;
	RTrange  = AMPSCZ_EEG_RTrange;

	[ pVOD, pAOD ] = deal( [] );

	for iHdr = 1:numel( vhdr )
	
		% load metadata only
		eeg = pop_loadbv( vhdr(iHdr).folder, vhdr(iHdr).name, [], [], true );
		
		% identify AMPSCZ task
		kStim = strcmp( { eeg.event.code }, 'Stimulus' );		% note: even reponse events have 'Stimulus' code
		kTask = cellfun( @(u) ismember( u{1,1}, cellfun( @(u)str2double(u(2:end)), { eeg.event(kStim).type } ) ), taskInfo(:,2) );
		if nnz( kTask ) ~= 1
			error( 'Can''t identify task type' )
		end

		% get standard, target, novel types
		if ~ismember( taskInfo{kTask,1}, { 'VODMMN', 'AOD' } )
			error( 'no performance data for %s task', taskInfo{kTask,1} )
		end
		[ typeStd, typeTrg, typeNvl, typeResp ] = AMPSCZ_EEG_eventCodes( taskInfo{kTask,1}(1:3) );
		kStd  = strcmp( { eeg.event.type }, typeStd  );
		kTrg  = strcmp( { eeg.event.type }, typeTrg  );
		kNvl  = strcmp( { eeg.event.type }, typeNvl  );
		kResp = strcmp( { eeg.event.type }, typeResp );
		% reuse kStim for true stimuli now
		kStim(:) = kStd | kTrg | kNvl;

		% get rid of stimuli that are too close to bounds to epoch?
% 		kStim(kStim) = [ eeg.event(kStim).latency ] >=            eeg.srate * 1;
% 		kStim(kStim) = [ eeg.event(kStim).latency ] <= eeg.pnts - eeg.srate * 2;
		kStim(kStim) = [ eeg.event(kStim).latency ] <= eeg.pnts - eeg.srate * RTrange(2);

		tStim = [ eeg.event(kStim).latency ] / eeg.srate;
		tResp = [ eeg.event(kResp).latency ] / eeg.srate;
		
		nStim   = nnz( kStim );
		RT      = nan( nStim, 2 );
		RT(kStd(kStim),1) = 0;
		RT(kTrg(kStim),1) = 1;
		RT(kNvl(kStim),1) = 2;
		for iStim = 1:nStim-1
% 			k = tResp >= tStim(iStim)+RTrange(1) & tResp <=      tStim(iStim)+RTrange(2);
			k = tResp >= tStim(iStim)+RTrange(1) & tResp <= min( tStim(iStim)+RTrange(2), tStim(iStim+1) );
			if any( k )
				RT(iStim,2) = tResp(find( k, 1, 'first' )) - tStim(iStim);
			end
		end
			k = tResp >= tStim(nStim)+RTrange(1) & tResp <=      tStim(nStim)+RTrange(2);
			if any( k )
				RT(nStim,2) = tResp(find( k, 1, 'first' )) - tStim(nStim);
			end

% 		kStd = kStd(kStim);
% 		kTrg = kTrg(kStim);
% 		kNvl = kNvl(kStim);
% 		kCorrect = false( 1, nStim );
% 		kCorrect(kStd) =  isnan( RT(kStd) );
% 		kCorrect(kTrg) = ~isnan( RT(kTrg) );
% 		kCorrect(kNvl) =  isnan( RT(kNvl) );
% 		[ median( RT(kTrg&kCorrect) ), nnz( kCorrect ), nStim ]
		
		switch vhdr(iHdr).name(31:33)
			case 'VOD'
				pVOD = cat( 1, pVOD, RT );
			case 'AOD'
				pAOD = cat( 1, pAOD, RT );
			otherwise
				error( 'bug' )
		end
	
	end

	if nargout ~= 0
		return
	end

	rHFA  = nan( 3, 2 );
	kStd  = pVOD(:,1) == 0;
	kTrg  = pVOD(:,1) == 1;
	kNvl  = pVOD(:,1) == 2;
	RTvod = pVOD(kTrg,2) * 1e3;
	rHFA(1,1) = nnz( ~isnan( pVOD(kTrg,2) ) ) / nnz( kTrg );
	rHFA(2,1) = nnz( ~isnan( pVOD(kNvl,2) ) ) / nnz( kNvl );
	rHFA(3,1) = nnz( ~isnan( pVOD(kStd,2) ) ) / nnz( kStd );
	kStd  = pAOD(:,1) == 0;
	kTrg  = pAOD(:,1) == 1;
	kNvl  = pAOD(:,1) == 2;
	RTaod = pAOD(kTrg,2) * 1e3;
	rHFA(1,2) = nnz( ~isnan( pAOD(kTrg,2) ) ) / nnz( kTrg );
	rHFA(2,2) = nnz( ~isnan( pAOD(kNvl,2) ) ) / nnz( kNvl );
	rHFA(3,2) = nnz( ~isnan( pAOD(kStd,2) ) ) / nnz( kStd );
	rHFA(:) = rHFA * 100;	% (%)

	RTvod(isnan( RTvod )) = [];
	RTaod(isnan( RTaod )) = [];

	% bar graph: hit rates, novel false alarms, standard false alarms (%) visual & auditory
	% box plot: reaction times for hits (ms) visual & auditory

	cOrder = get( 0, 'defaultaxescolororder' );
	fontSize   = 14;
	fontWeight = 'normal';

% 	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );

	% super crazy glitch, at least on my laptop
	% this results in double axes on last figure!!!
%{
	hFig = [
		figure( 'Position', [ 500, 300, 350, 250 ], 'Tag', [ mfilename, '-rate' ] )
		figure( 'Position', [ 900, 300, 350, 250 ], 'Tag', [ mfilename, '-RT'   ] ) ];
	set( hFig, 'MenuBar', 'none', 'Color', 'w' )
	hAx = [ axes( hFig(1) ), axes( hFig(2) ) ];
	set( hAx, 'Units', 'normalized', 'Position', [ 0.2, 0.2, 0.75, 0.75 ] )			% this is when the extra axis appears
%}
	hFig = gobjects( 1, 2 );
	hAx  = gobjects( 1, 2 );
	hFig(1) = figure( 'Position', [ 500, 300, 350, 250 ], 'Tag', [ mfilename, '-rate' ] );
	hAx(1)  = gca;
	hFig(2) = figure( 'Position', [ 900, 300, 350, 250 ], 'Tag', [ mfilename, '-RT'   ] );
	hAx(2)  = gca;
	set( hAx, 'Units', 'normalized', 'Position', [ 0.2, 0.2, 0.75, 0.75 ] )
	set( hFig, 'MenuBar', 'none', 'Color', 'w' )

	bar(  hAx(1), 1:3, rHFA, 1 )
	set(  hAx(1), 'XLim', [ 0.5, 3.5 ], 'XTick', 1:3, 'XTickLabel', { 'Target Hit', 'Novel FA', 'Stnd FA' }, 'YLim', [ -10, 110 ] )
	text( hAx(1),	'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Position', [ 0.95, 0.95 ],...
					'String', sprintf( '\\color[rgb]{%g,%g,%g}Visual\n\\color[rgb]{%g,%g,%g}Auditory', cOrder(1,:), cOrder(2,:) ),...
					'FontSize', fontSize+2, 'FontWeight', fontWeight )

	boxplot( hAx(2), [ RTvod; RTaod ], [ repmat({'Visual'},numel(RTvod),1); repmat({'Auditory'},numel(RTaod),1) ],...
		'BoxStyle', 'outline', 'MedianStyle', 'line', 'Notch', 'on', 'PlotStyle', 'traditional',...
		'Symbol', 'o', 'OutlierSize', 6, 'Widths', 0.5, 'ExtremeMode', 'compress', 'Jitter', 0.1, 'Whisker', 1.5,...
		'LabelOrientation', 'horizontal', 'LabelVerbosity', 'all', 'Orientation', 'horizontal',...
		'Positions', [ ones(1,~isempty(RTvod)), repmat(2,1,~isempty(RTaod)) ] )
	set( hAx(2), 'PositionConstraint', 'innerposition' )
	set( hAx(2), 'YDir', 'reverse', 'XLim', [ 0, max( [ RTvod; RTaod ] )*1.1 ] )
	set( hAx(2), 'YTickLabelRotation', 90 )

	set( [
		ylabel( hAx(1), 'Response Rate (%)' )
		xlabel( hAx(2), 'Target Reaction Time (ms)' )
	], 'FontSize', fontSize, 'FontWeight', fontWeight )
	set( hAx, 'FontSize', 12 )			% this is changing x & y labels too! not just tick labels
	set( hAx(1), 'YGrid', 'on' )
	set( hAx(2), 'XGrid', 'on' )

end
