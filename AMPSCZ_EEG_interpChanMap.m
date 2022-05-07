
clear

subjectID   = 'BI00018';
sessionDate = '20220420';

	matDir      = fullfile( AMPSCZ_EEG_procSessionDir( subjectID, sessionDate ), 'mat' );
	if ~isfolder( matDir )
		error( '%s is not a valid directory', matDir )
	end
	
% 	matFiles = dir( fullfile( matDir, [ subjectID, '_', sessionDate, '_*_[*,*].mat' ] ) );
	matFiles = dir( fullfile( matDir, [ subjectID, '_', sessionDate, '_*_[0.2,Inf].mat' ] ) );
	
% 	tasksFound = regexp( { matFiles.name }, [ '^', subjectID, '_', sessionDate, '_([A-Z]+)_\[[\d\.]+,[\d\.Inf]+\].mat$' ], 'tokens', 'once' );
	tasksFound = regexp( { matFiles.name }, [ '^', subjectID, '_', sessionDate, '_([A-Z]+)_\[0\.2,Inf\].mat$' ], 'tokens', 'once' );
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
		S = load( fullfile( matDir, [ subjectID, '_', sessionDate, '_', taskNames{iTask}, '_[0.2,Inf].mat' ] ), 'chanProp' );
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

	clf
	topoplot( nInt(kPlot), S.chanProp(iRep).channelLocations(kPlot), topoOpts{:} );
	set( gca, 'CLim', [ -0.5, nRun+0.5 ] )
	title( sprintf( '%s\n%s', subjectID, sessionDate ) )
	hBar = colorbar;
	set( hBar, 'YTick', 0:nRun )
	ylabel( hBar, '# interpolated runs' )
	figure( gcf )

