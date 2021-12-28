function AMPSCZ_EEG_ERPplot( EEG, epochInfo )
% ERP plots from the output of ProNET_preprocEEG.m
% 
% Usage:
% >> AMPSCZ_EEG_ERPplot( EEG, epochInfo )

% S:\bieegl01\Delta\napls3\matlab or github
% see grandAverage_NAPLS_LTP_ERPs.m loads mat-files for plotting
%     massUnivariateClusterTest_NAPLS_LTP_ERPs.m
%     plotLTPerps.m

			% BJR code
			% VODMMN
			% 	MMN plot Fz for standard & all deviant types
			% 	VOD plot Oz for standard
			% 	         Pz for target
			% 				find pos peak for Pz target [200,600]ms
			% 					topo mean standard w/i 25ms of peak
			% 					topo mean target   w/i 25ms of peak
			% #				find pos peak for Cz novel [200,600]ms
			% #					topo mean novel w/i 25ms of peak
			% AOD
			% 	no plots
			
			% New Spec
			% AOD or VOD
			%	plot Pz & Cz (possibly Fz too?)
			%   get target peak from Pz difference
			%       novel  peak from Cz difference
			% MMN
			%   plot Fz (& Cz?)
			
			% MMN in negative component 100-250 ms after stimulus
			
			% tpk = Peakmm3(nanmean(EEG.data(Pz,:,events==100),3)', EEG.times, 200,600,'pos');


		% From Gregory Light to Everyone:  04:21 PM
		% https://www.frontiersin.org/articles/10.3389/fninf.2015.00016/full			PREP?  bad channels iterative common average
		% https://sccn.ucsd.edu/wiki/Makoto's_preprocessing_pipeline					too ICA based but interesting


	narginchk( 1, 2 )
	% suppress warning about (xmax-xmin)*srate+1 ~= pnts?
% 	if isstruct( EEG ) && all( isfield( EEG, fieldnames( eeg_checkset( eeg_emptyset ) ) ) )
	blank = eeg_emptyset;
	blank.xmin = 1;				% eeg_checkset sets xmax to -1 instead
	blank = eeg_checkset( blank );
	if isstruct( EEG ) && all( isfield( EEG, fieldnames( blank ) ) )
% 		if ~isstruct( epochInfo ) || ~all( isfield( epochInfo, { 'latency', 'kTarget', 'kNovel', 'kCorrect', 'Nstandard', 'respLat' } ) )
		if ~isstruct( epochInfo ) || ~all( isfield( epochInfo, { 'latency', 'kStandard', 'kTarget', 'kNovel', 'kCorrect', 'respLat' } ) )
			error( 'invalid epochInfo structure' )
		end
	elseif ischar( EEG ) && exist( EEG, 'file' ) == 2 && strncmp( flip( EEG, 2 ), 'mat.', 4 )
		EEG = load( EEG );
		if ~isfield( EEG, 'EEG' )
			error( 'invalid mat-file' )
		end
		epochInfo = EEG.epochInfo;
		EEG       = EEG.EEG;
	else
		error( 'invalid EEG structure' )
	end
	
	tWinPlot   = [ -100, 500 ];	% (ms)
% 	tWidthTopo = 0;
	tWidthTopo = 50;
	
	Ichan  = find( strcmp( { EEG.chanlocs.type }, 'EEG' ) );
	nChan  = numel( Ichan );
% 	nSamp  = EEG.pnts;
% 	nEpoch = EEG.trials;

	jTime = EEG.times >= tWinPlot(1) & EEG.times <= tWinPlot(2);
	jT0   = find( jTime, 1, 'first' ) - 1;
	nTime = sum( jTime );

	eventType = cellfun( @(u,v)u{[v{:}]==0}, { EEG.epoch.eventtype }, { EEG.epoch.eventlatency }, 'UniformOutput', false );
	if numel( eventType ) ~= EEG.trials
		error( 'huh?' )
	end
	
% 	chanSet = {
% 		'Cz-centered', { 'Cz', 'FC1',        'FC2', 'C1', 'C2', 'CP1', 'CPz', 'CP2' }
% 		'Pz-centered', { 'Pz', 'CP1', 'CPz', 'CP2', 'P1', 'P2', 'PO3', 'POz', 'PO4' }
% 	};
% 	chanSet = {
% 		'Cz', { 'Cz' }
% 		'Pz', { 'Pz' }
% 	};

	% Get epochName
	% EEG.comments will have VODMMN combined
	% there's got to be a better way to identify task! probably should just make it an input since it's saved in mat-files
	switch eventType{1}
		case { 'S  1', 'S  2', 'S  4', 1, 2, 4 }
			epochName   = 'AOD';
			deviantName = 'Novel';
			% { label, channel members }
			chanSet = {
				'Cz', { 'Cz' }
				'Pz', { 'Pz' }
			};
			% { index into chanSet, waveform, time range } for { standard; target; novel }
			peakInfo = {
				nan,                '',           []
				  2, 'Target-Standard', [ 200, 600 ]
				  1,  'Novel-Standard', [ 200, 600 ]
			};
			figSize  = [ 600, 700 ];
		case { 'S 16', 'S 18', 16, 18 }
			epochName   = 'MMN';
			deviantName = 'Deviant';
			chanSet = {
				'Fz', { 'Fz' }
			};
			peakInfo = {
				nan,               '',          []
				nan,               '',          []
				  1, 'Standard-Novel', [ 80, 200 ]
			};
			figSize  = [ 600, 600 ];
		case { 'S 32', 'S 64', 'S128', 32, 64, 128 }
			epochName   = 'VOD';
			deviantName = 'Novel';
% 			chanSet = {
% 				'Pz', { 'Pz' }		% target & peak detection
% 				'Oz', { 'Oz' }		% standard
% 			};
			chanSet = {
				'Cz', { 'Cz' }		%  novel - standard
				'Pz', { 'Pz' }		% target - standard
			};
			peakInfo = {
				nan,                '',           []
				  2, 'Target-Standard', [ 200, 600 ]
				  1,  'Novel-Standard', [ 200, 600 ]
			};
			figSize  = [ 600, 700 ];
		case { 'S  8', 8 }
			epochName   = 'ASSR';
% 		case { 'S 20 ', 20 }
% 			epochName = 'RestEO';
% 		case { 'S 24', 24 }
% 			epochName = 'RestEC';
		otherwise
			error( 'can''t identify task' )
	end

	% convert cell arrays of channel names to numeric indices
	nSet = size( chanSet, 1 );		% # waveform axes
	for iSet = 1:nSet
%		     chanSet{iSet,2}   = eeg_chaninds( EEG, chanSet{iSet,2} );			% beware: eeg_chaninds.m sorts indices
		[ ~, chanSet{iSet,2} ] = ismember( chanSet{iSet,2}, { EEG.chanlocs(Ichan).labels } );
		if any( chanSet{iSet,2} == 0 )
			error( 'unknown channel(s)' )
		end
	end

% 	[ standardCode, targetCode, novelCode, respCode ] = ProNET_eventCodes( epochName );
	[ doStandard, doTarget, doNovel ] = ProNET_eventCodes( epochName );
	doStandard = ~isempty( doStandard );		% this will always be true, here for future flexibility
	doTarget   = ~isempty( doTarget ); 
	doNovel    = ~isempty( doNovel ); 

	% concatenate epoch info across runs
	for fn = fieldnames( epochInfo )'
		epochInfo(1).(fn{1}) = [ epochInfo.(fn{1}) ];
	end
	epochInfo = epochInfo(1);


		% double-check EEG structure against epochInfo?
%		if ~isempty( [ targetCode, novelCode ] )
%			stimEvents = eventType( ~strcmp( eventType, standardCode ) );
%			if numel( stimEvents ) ~= numel( epochInfo.kTarget )
%				error( 'epoch event type bug' )
%			elseif ~isempty( targetCode ) && ~all( strcmp( stimEvents( epochInfo.kTarget ), targetCode ) )
%				error( 'epoch event type bug' )
%			elseif ~isempty(  novelCode ) && ~all( strcmp( stimEvents( epochInfo.kNovel  ),  novelCode ) )
%				error( 'epoch event type bug' )
%			end
%			clear stimEvents
%		end

	% what's more efficient indexing, logical or double here?
	% e.g. 800 epochs, 640 standard, 80 target, 80 novel
	% with large #s of standards in the mix, logicals win
	%
	% this is the same as find( epochInfo.kStandard ), why was I using strcmp?
	% legacy from when there were no standards in epochInfo?
% 	Kstandard = find( strcmp( eventType, standardCode ) );
	if doStandard
		Kstandard = epochInfo.kStandard;
	end
	if doTarget
% 		Ktarget = find( strcmp( eventType, targetCode ) );
		Ktarget = epochInfo.kTarget;
	end
	if doNovel
% 		Knovel = find( strcmp( eventType, novelCode ) );
		Knovel = epochInfo.kNovel;
	end


	% only analyze correct responses?		don't worry about button presses in MMN task.  DM 12/13/21
	if ismember( epochName, { 'AOD', 'VOD' } )
		% remove standard epochs with any responses in the >0 epoch window?  no, this was before I added standards to epochInfo
% 		Kstandard( cellfun( @(u,v)ismember(respCode,u([v{:}]>0)), { EEG.epoch(Kstandard).eventtype }, { EEG.epoch(Kstandard).eventlatency } ) ) = [];
% 		Kstandard = Kstandard(epochInfo.kCorrect(epochInfo.kStandard));
		if doStandard
			Kstandard(Kstandard) = epochInfo.kCorrect(Kstandard);
		end
		if doTarget
% 			Ktarget = Ktarget(epochInfo.kCorrect(epochInfo.kTarget));
			Ktarget(Ktarget) = epochInfo.kCorrect(Ktarget);
		end
		if doNovel
% 			Knovel = Knovel(epochInfo.kCorrect(epochInfo.kNovel));
			Knovel(Knovel) = epochInfo.kCorrect(Knovel);
		end
	end
	
	% non-rejected epochs
	kEpoch = shiftdim( ~isnan( EEG.data(1,1,:) ), 1 );
% 	kEpoch(:) = true;
	if doStandard
		Kstandard(Kstandard) = kEpoch(Kstandard);
	end
	if doTarget
		Ktarget(Ktarget) = kEpoch(Ktarget);
	end
	if doNovel
		Knovel(Knovel) = kEpoch(Knovel);
	end
	clear kEpoch

	% average across good epochs, all EEG channels
	% #channels(total) x #samples matrices
% 	nanFlag = 'omitnan';
	nanFlag = 'includenan';
	if doStandard
		YmStandard = mean( EEG.data(Ichan,jTime,Kstandard), 3, nanFlag );
%		YmStandard = detrend( YmStandard', 1 )';
	else
		YmStandard = [];
	end
	if doTarget
		YmTarget = mean( EEG.data(Ichan,jTime,Ktarget), 3, nanFlag );
% 		YmTarget = detrend( YmTarget', 1 )';
% 	else
% 		YmTarget = [];
	end
	if doNovel
		YmNovel = mean( EEG.data(Ichan,jTime,Knovel), 3, nanFlag );
% 		YmNovel = detrend( YmNovel', 1 )';
% 	else
% 		YmNovel = [];
	end
	
	
	% average aross channels
	% #sets x #samples matrices
	if doStandard
		ymStandard = zeros( nSet, nTime );
		for iSet = 1:nSet
			ymStandard(iSet,:) = mean( YmStandard(chanSet{iSet,2},:), 1, 'includenan' );
		end
	else
		ymStandard = [];
	end
	if doTarget
		ymTarget = zeros( nSet, nTime );
		for iSet = 1:nSet
			ymTarget(iSet,:) = mean( YmTarget(chanSet{iSet,2},:), 1, 'includenan' );
		end
	end
	if doNovel
		ymNovel = zeros( nSet, nTime );
		for iSet = 1:nSet
			ymNovel(iSet,:)  = mean( YmNovel(chanSet{iSet,2},:), 1, 'includenan' );
		end
	end


	
	estyle = 'pts';
% 	estyle = 'ptslabels';

	% get range of data values
	% want same range of color scale for all channels as y-limits on waveform axes?
	if ~true		% all channels, safe bet to make sure topographs don't clip but waveforms may be squashed
		if doTarget
			if doNovel
				Yall = cat( 3, YmStandard, YmTarget, YmNovel, YmTarget - YmStandard, YmNovel - YmStandard );
			else
				Yall =  cat( 3, YmStandard, YmTarget, YmTarget - YmStandard );
			end
		elseif doNovel
			Yall = cat( 3, YmStandard, YmNovel, YmNovel - YmStandard );
		else
			Yall = YmStandard;
		end
		switch 1
			case 1
				yRange = [ min( Yall, [], 'all' ), max( Yall, [], 'all' ) ];
			case 2
				N = numel( Yall );
				F = 0.99;
				yRange = interp1( 1:N, sort( Yall(:), 1, 'ascend' ), ( 1 + [ -F, F ] )/2 * N, 'pchip' );
			case 3
				N = numel( Yall );
				F = 0.9999;
				yRange = [ 0, interp1( 1:N, sort( abs( Yall(:) ), 1, 'ascend' ), F*N, 'pchip' ) ];
		end
		clear Yall
	else		% risk topograph clipping better good waveform view
		if doTarget
			if doNovel
				Yall = cat( 3, ymStandard, ymTarget, ymNovel, ymTarget - ymStandard, ymNovel - ymStandard );
			else
				Yall =  cat( 3, ymStandard, ymTarget, ymTarget - ymStandard );
			end
		elseif doNovel
			Yall = cat( 3, ymStandard, ymNovel, ymNovel - ymStandard );
		else
			Yall = ymStandard;
		end
		switch 1
			case 1
				yRange = [ min( Yall, [], 'all' ), max( Yall, [], 'all' ) ];
			case 2
				N = numel( Yall );
				F = 0.99;
				yRange = interp1( 1:N, sort( Yall(:), 1, 'ascend' ), ( 1 + [ -F, F ] )/2 * N, 'pchip' );
			case 3
				N = numel( Yall );
				F = 0.9999;
				yRange = [ 0, interp1( 1:N, sort( abs( Yall(:) ), 1, 'ascend' ), F*N, 'pchip' ) ];
		end
		clear Yall
	end
	% make symmetric about zero
	yRange(2) = max( -yRange(1), yRange(2) );
	yRange(1) = -yRange(2);
	% pad a little?
	yRange(:) = yRange + [ -1, 1 ] * diff( yRange ) * 0.125;
	

	[ tmStandardT, tmStandardN, tmTarget, tmNovel ] = deal( nan( nChan, 1 ) );		% initialize for scope, set in getTopoMaps
	jPk = nan( 1, 3 );									% [ standard, target, novel ]
	nPk = sum( ismember( [ peakInfo{:,1} ], 1:nSet ) );

	% stop automatic datatips - they're super annoying!
	set( groot , 'defaultAxesCreateFcn' , 'disableDefaultInteractivity(gca)' )
	
	hFig  = figure( 'Position', [ 600, 150, figSize ] );		% 225% SCN laptop
	hAx   = gobjects( 1, nSet + 3*nPk );
	hLine = gobjects( 5, nSet );
	hTime = gobjects( 3, 1 );
	hTopo = gobjects( 3*nPk, 1 );
	
	% Waveform plots
	for iSet = 1:nSet
		% Get peak indices
		for iPk = find( [ peakInfo{:,1} ] == iSet )
			kPk = EEG.times(jTime) >= peakInfo{iPk,3}(1) & EEG.times(jTime) <= peakInfo{iPk,3}(2);
			switch peakInfo{iPk,2}
				case 'Standard'
					[ ~, jPk(iPk) ] = max( ymStandard(iSet,kPk) );
				case 'Target'
					[ ~, jPk(iPk) ] = max( ymTarget(iSet,kPk) );
				case 'Novel'
					[ ~, jPk(iPk) ] = max( ymNovel(iSet,kPk) );
				case 'Target-Standard'
					[ ~, jPk(iPk) ] = max( ymTarget(iSet,kPk) - ymStandard(iSet,kPk) );
				case 'Novel-Standard'
					[ ~, jPk(iPk) ] = max(  ymNovel(iSet,kPk) - ymStandard(iSet,kPk) );
				case 'Standard-Novel'	% i.e. negative novel minus standard
					[ ~, jPk(iPk) ] = max( ymStandard(iSet,kPk) - ymNovel(iSet,kPk) );
				otherwise
					error( 'unknown peak type' )
			end
			jPk(iPk) = jPk(iPk) + find( kPk, 1, 'first' ) - 1;
		end
		% Plot
		hAx(iSet) = subplot( nSet+nPk, 3, iSet*3 + (-2:0), 'UserData', iSet, 'NextPlot', 'add', 'YLim', yRange, 'CLim', yRange, 'FontSize', 8 );
		if doStandard
			hLine(1,iSet) = plot( EEG.times(jTime), ymStandard(iSet,:), 'k' );
		end
		if doTarget
			hLine(2,iSet) = plot( EEG.times(jTime), ymTarget(iSet,:), 'b' );
			hLine(4,iSet) = plot( EEG.times(jTime), ymTarget(iSet,:) - ymStandard(iSet,:), '--b' );
		end
		if doNovel
			hLine(3,iSet) = plot( EEG.times(jTime), ymNovel(iSet,:), 'r' );
			hLine(5,iSet) = plot( EEG.times(jTime), ymNovel(iSet,:) - ymStandard(iSet,:), '--r' );
		end
		ylabel( [ chanSet{iSet,1}, ' (\muV)' ], 'FontSize', 12 )
		colorbar
	end
	% Add peak marker lines
	for iPk = find( ~isnan( jPk ) )		% [ peakInfo{:,1} ] or jPk
		hTime(iPk) = plot( hAx(peakInfo{iPk,1}), EEG.times(jPk([ iPk, iPk ])+jT0), yRange,...
			'Color', [ 0, 0.75, 0 ], 'UserData', iPk, 'ButtonDownFcn', @sliceClickCB, 'LineStyle', '--' );
		switch iPk
			case 1
				set( hTime(iPk), 'Color', 'k' )
			case 2
				set( hTime(iPk), 'Color', 'b' )
			case 3
				set( hTime(iPk), 'Color', 'r' )
		end
	end
	set( hAx(1:nSet), 'XGrid', 'on', 'YGrid', 'on', 'NextPlot', 'replace' )
	
	subjSess = regexp( EEG.comments, '^Original file: sub-([A-Z]{2}\d{5})_ses-(\d{8})_task-\S+_run-\d+_eeg.eeg$', 'tokens', 'once' );
% 	title( hAx(1), sprintf( '%s \\color[rgb]{0,0.75,0}%0.0f ms', epochName, EEG.times(jPk) ) )
% 	title( hAx(1), epochName )
	title( hAx(1), sprintf( '%s %s %s', subjSess{:}, epochName ) )
% 	xlabel( hAx(nSet), 'Time (ms)' )
% 	xLab = xlabel( hAx(nSet), sprintf( '%0.0f ms', EEG.times(jPk+jT0) ), 'Color', [ 0, 0.75, 0 ] );
% 	legend( hLine(1:3,1), { 'standard', 'target', 'novel' }, 'Location', 'NorthEast' )

	% Topography plots
	getTopoMaps
	topoOpts = { 'style', 'map', 'electrodes', estyle, 'nosedir', '+Y', 'conv', 'on', 'shading', 'interp', 'maplimits', yRange };
	iTopo = 0;
	if ~isnan( jPk(1) )
		error( 'under construction' )
	end
	% target peak
	if ~isnan( jPk(2) )	
		iTopo(:) = iTopo + 1;
		hAx(nSet+iTopo) = subplot( nSet+nPk, 3, nSet*3 + iTopo );
		hTopo(iTopo)    = topoplot( tmStandardT, EEG.chanlocs(Ichan), topoOpts{:} );
		if iTopo == 1
			title( sprintf( 'Standard (%d)', sum( Kstandard ) ) )
		else
			title( 'Standard' )
		end
		ylabT = ylabel( sprintf( '%0.0f ms', EEG.times(jPk(2)+jT0) ), 'Visible', 'on', 'Color', 'b', 'FontSize', 14, 'FontWeight', 'bold' );
		
		iTopo(:) = iTopo + 1;
		hAx(nSet+iTopo) = subplot( nSet+nPk, 3, nSet*3 + iTopo );
		hTopo(iTopo)    = topoplot( tmTarget, EEG.chanlocs(Ichan), topoOpts{:} );
		title( sprintf( 'Target (%d)', sum( Ktarget ) ), 'Color', 'b' )
		
		iTopo(:) = iTopo + 1;
		hAx(nSet+iTopo) = subplot( nSet+nPk, 3, nSet*3 + iTopo );
		hTopo(iTopo)    = topoplot( tmTarget - tmStandardT, EEG.chanlocs(Ichan), topoOpts{:} );
		title( 'Target - Standard' )%, 'Color', 'b' )
	end
	% novel peak
	if ~isnan( jPk(3) )
		iTopo(:) = iTopo + 1;
		hAx(nSet+iTopo) = subplot( nSet+nPk, 3, nSet*3 + iTopo );
		hTopo(iTopo)    = topoplot( tmStandardN, EEG.chanlocs(Ichan), topoOpts{:} );
		if iTopo == 1
			title( sprintf( 'Standard (%d)', sum( Kstandard ) ) )
		else
			title( 'Standard' )
		end
		ylabN = ylabel( sprintf( '%0.0f ms', EEG.times(jPk(3)+jT0) ), 'Visible', 'on', 'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold' );
		
		iTopo(:) = iTopo + 1;
		hAx(nSet+iTopo) = subplot( nSet+nPk, 3, nSet*3 + iTopo );
		hTopo(iTopo)    = topoplot( tmNovel, EEG.chanlocs(Ichan), topoOpts{:} );
		title( sprintf( '%s (%d)', deviantName, sum( Knovel ) ), 'Color', 'r' )

		iTopo(:) = iTopo + 1;
		hAx(nSet+iTopo) = subplot( nSet+nPk, 3, nSet*3 + iTopo );
		hTopo(iTopo)    = topoplot( tmNovel - tmStandardN, EEG.chanlocs(Ichan), topoOpts{:} );
		title( [ deviantName, ' - Standard' ] )%, 'Color', 'r' )
	end
	for iAx = 1:numel( hAx )
		set( get( hAx(iAx), 'Title' ), 'FontSize', 10 )
	end
	
	hMenu = gobjects( 1, 5 );
	hMenu(1) = uimenu( hFig, 'Text', 'Waveforms' );
	hMenu(2) = uimenu( hMenu(1), 'Text', 'Regular' );
	hMenu(3) = uimenu( hMenu(1), 'Text', 'Difference' );
	hMenu(4) = uimenu( hMenu(1), 'Text', 'All' );
	hMenu(5) = uimenu( hMenu(1), 'Text', 'Std+Diff' );
	set( hMenu(2:5), 'Callback', @wavePicker )
	wavePicker( hMenu(2) )
	

	return


	function sliceClickCB( varargin )
		if varargin{2}.Button ~= 3
			return
		end
		g = ginput( 1 );
		if g(1) <= tWinPlot(1) || g(1) >= tWinPlot(2)
			return
		end
		% what peak are you modifying? 1=standard, 2=target, 3=novel
		iiPk = get( varargin{1}, 'UserData' );
		% move the line.  note: hTime(iiPk) is varargin{1}
		[ ~, jPk(iiPk) ] = min( abs( EEG.times(jTime) - g(1) ) );
		set( hTime(iiPk), 'XData', EEG.times(jPk([ iiPk, iiPk ])+jT0) )
		getTopoMaps
		% note: topoplot( ..., 'noplot', 'on' ) was a complete fail.  closes figure.  put a copy in my modification folder.
		switch iiPk
			case 1
			case 2
				[ ~, cdata ] = topoplot( tmStandardT, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(1), 'CData', cdata )
				set( ylabT, 'String', sprintf( '%0.0f ms', EEG.times(jPk(iiPk)+jT0) ) )
				
				[ ~, cdata ] = topoplot( tmTarget, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(2), 'CData', cdata )
				
				[ ~, cdata ] = topoplot( tmTarget - tmStandardT, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(3), 'CData', cdata )
			case 3
				iTopo = 3*doTarget;
				[ ~, cdata ] = topoplot( tmStandardN, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(iTopo+1), 'CData', cdata )
				set( ylabN, 'String', sprintf( '%0.0f ms', EEG.times(jPk(iiPk)+jT0) ) )
				
				[ ~, cdata ] = topoplot( tmNovel, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(iTopo+2), 'CData', cdata )
				
				[ ~, cdata ] = topoplot( tmNovel - tmStandardN, EEG.chanlocs(Ichan), topoOpts{:}, 'noplot', 'on' );
				set( hTopo(iTopo+3), 'CData', cdata )
		end
% 		title( hAx(1), sprintf( '%s \\color[rgb]{0,0.75,0}%0.0f ms', epochName, EEG.times(jPk) ) )
% 		xlabel( hAx(nSet), sprintf( '%0.0f ms', EEG.times(jPk+jT0) ) )
% 		set( xLab, 'String', sprintf( '%0.0f ms', EEG.times(jPk+jT0) ) )

	end

	function getTopoMaps
% 		iiPk = find(~isnan(jPk),1,'first');
		if isnan( jPk(2) )
			tmStandardT(:) = nan;
			tmTarget(:)    = nan;
		elseif tWidthTopo == 0
			tmStandardT(:) = YmStandard(:,jPk(2));
			tmTarget(:)    =   YmTarget(:,jPk(2));
		else
% 			jt   = jPk(iiPk) + jT0;
% 			jAvg = EEG.times(jTime) >= EEG.times(jt) - tWidthTopo/2 & EEG.times(jTime) <= EEG.times(jt) + tWidthTopo/2;
% 			tmStandard   = mean( YmStandard(:,jAvg), 2, 'includenan' );
			jt   = jPk(2) + jT0;
			jAvg = EEG.times(jTime) >= EEG.times(jt) - tWidthTopo/2 & EEG.times(jTime) <= EEG.times(jt) + tWidthTopo/2;
			tmStandardT(:) = mean( YmStandard(:,jAvg), 2, 'includenan' );
			tmTarget(:)    = mean(   YmTarget(:,jAvg), 2, 'includenan' );
		end
		if isnan( jPk(3) )
			tmStandardN(:) = nan;
			tmNovel(:)     = nan;
		elseif tWidthTopo == 0
			tmStandardN(:) = YmStandard(:,jPk(3));
			tmNovel(:)     =    YmNovel(:,jPk(3));
		else
			jt(:)   = jPk(3) + jT0;
			jAvg(:) = EEG.times(jTime) >= EEG.times(jt) - tWidthTopo/2 & EEG.times(jTime) <= EEG.times(jt) + tWidthTopo/2;
			tmStandardN(:) = mean( YmStandard(:,jAvg), 2, 'includenan' );
			tmNovel(:)     = mean(    YmNovel(:,jAvg), 2, 'includenan' );
		end
	end

	function wavePicker( varargin )
		switch get( varargin{1}, 'Text' )
			case 'Regular'
				Ion  = 1:3;
				set( hMenu(2)      , 'Checked', 'on'  )
				set( hMenu([3 4 5]), 'Checked', 'off' )
			case 'Difference'
				Ion  = 4:5;
				set( hMenu(3)      , 'Checked', 'on'  )
				set( hMenu([2 4 5]), 'Checked', 'off' )
			case 'All'
				Ion  = 1:5;
				set( hMenu(4)      , 'Checked', 'on'  )
				set( hMenu([2 3 5]), 'Checked', 'off' )
			case 'Std+Diff'
				Ion  = [ 1, 4:5 ];
				set( hMenu(5)      , 'Checked', 'on'  )
				set( hMenu([2 3 4]), 'Checked', 'off' )
		end
		hOn = hLine(Ion,:);
		hOn = hOn(ishandle(hOn));
		Ioff = setdiff( 1:5, Ion );
		if ~isempty( Ioff )
			hOff = hLine(Ioff,:);
			hOff = hOff(ishandle(hOff));
			set( hOff, 'Visible', 'off' )
		end
		set( hOn, 'Visible', 'on' )
		
	end

end


