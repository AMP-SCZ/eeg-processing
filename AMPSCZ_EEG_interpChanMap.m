function AMPSCZ_EEG_interpChanMap( subjectID, sessionDate )
% AMPSCZ_EEG_interpChanMap( subjectID, sessionDate )

	matDir = fullfile( AMPSCZ_EEG_procSessionDir( subjectID, sessionDate ), 'mat' );
	if ~isfolder( matDir )
		error( '%s is not a valid directory', matDir )
	end

% 	filterStr = '[*,*]';
	filterStr = '[0.2,Inf]';
	matFiles = dir( fullfile( matDir, [ subjectID, '_', sessionDate, '_*_', filterStr, '.mat' ] ) );

% 	tasksFound = regexp( { matFiles.name }, [ '^', subjectID, '_', sessionDate, '_([A-Z]+)_\[[\d\.]+,[\d\.Inf]+\].mat$' ], 'tokens', 'once' );
% 	tasksFound = regexp( { matFiles.name }, [ '^', subjectID, '_', sessionDate, '_([A-Z]+)_\[0\.2,Inf\].mat$' ], 'tokens', 'once' );
	tasksFound = regexp( { matFiles.name }, [ '^', subjectID, '_', sessionDate, '_([A-Z]+)_',...
		strrep( strrep( strrep( filterStr, '[', '\[' ), ']', '\]' ), '.', '\.' ),'.mat$' ], 'tokens', 'once' );
	tasksFound = [ tasksFound{:} ];

	taskNames = { 'MMN', 'VOD', 'AOD', 'ASSR' };
	kFound    = ismember( taskNames, tasksFound );
	if ~all( kFound )
		error( 'missing task(s)' )
% 		taskNames(~kFound) = [];
	end

	nRun  =  0;
	nChan = 65;
	nInt  = zeros( nChan, 1 );
	nTask = numel( taskNames );
	for iTask = 1:nTask
		S = load( fullfile( matDir, [ subjectID, '_', sessionDate, '_', taskNames{iTask}, '_', filterStr, '.mat' ] ), 'chanProp' );
		nRep = numel( S.chanProp );
		for iRep = 1:nRep
			if numel( S.chanProp(iRep).channelLocations ) ~= nChan
				error( 'unexpected # channels' )
			end
			nInt(S.chanProp(iRep).interpolatedChannels.all) = nInt(S.chanProp(iRep).interpolatedChannels.all) + 1;
		end
		nRun(:) = nRun + nRep;
	end

	if nRun ~= 12
		warning( 'unexpected # runs' )
	end

	kPlot = ~strcmp( { S.chanProp(iRep).channelLocations.labels }, 'VIS' );

% 	cmap = AMPSCZ_EEG_GYRcmap( 256 );
	cmap = [ 1, 1, 1; jet( nRun ) ];
	
	topoOpts = AMPSCZ_EEG_topoOptions( cmap, [ -0.5, nRun+0.5 ] );
% 	topoOpts{2*find(strcmp(topoOpts(1:2:end),'conv'))} = 'off';
	topoOpts{2*find(strcmp(topoOpts(1:2:end),'shading'))} = 'interp';
% 	[ topoX, topoY ] = bieegl_topoCoords( S.chanProp(iRep).channelLocations(kPlot) );

	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
% 	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.9, 0.90-0.18 ] );
	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.9, 0.97-0.18 ] );
	topoplot( nInt(kPlot), S.chanProp(iRep).channelLocations(kPlot), topoOpts{:} );
	set( hAx, 'CLim', [ -0.5, nRun+0.5 ] )
% 	title( hAx, printf( '%s\n%s', subjectID, sessionDate ) )
	xlabel( hAx, '# interpolated epochs', 'Visible', 'on', 'FontSize', 14, 'FontWeight', 'normal' )
	hBar = colorbar;
	set( hBar, 'YTick', 0:nRun )
% 	ylabel( hBar, '# interpolated runs' )

	return

end

