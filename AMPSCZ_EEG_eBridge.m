function [ EB, ED, chanlocs ] = AMPSCZ_EEG_eBridge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )
% https://psychophysiology.cpmc.columbia.edu/software/eBridge/Index.html
% https://psychophysiology.cpmc.columbia.edu/software/eBridge/eBridge.m

	narginchk( 2, 7 )

	if exist( 'VODMMNruns', 'var' ) ~= 1
		VODMMNruns = 0;
	end
	if exist( 'AODruns', 'var' ) ~= 1
		AODruns = 0;
	end
	if exist( 'ASSRruns', 'var' ) ~= 1
		ASSRruns = 0;
	end
	if exist( 'RestEOruns', 'var' ) ~= 1
		RestEOruns = 0;
	end
	if exist( 'RestECruns', 'var' ) ~= 1
		RestECruns = 1;
	end

% 	currentDir = cd;
	if ispc
		eBridgeDir = 'C:\Users\donqu\Downloads\eBridge';
	else
		eBridgeDir = '/PHShome/sn1005/Downloads/eBridge';
	end
	if isempty( which( 'eBridge.m' ) )
		addpath( eBridgeDir, '-begin' )
	end
	locsFile   = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.elc' );

	eeg = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, 50 ], [ -1, 2 ] );

% 	cd( eBridgeDir )
	[ EB, ED ] = eBridge( eeg );
% 	cd( currentDir )

	% 2D channel x channel image matrix, triangular
	img  = sum( ED * EB.Info.EDscale < EB.Info.EDcutoff, 3 );
	% topography vector
	img = sum( img + img', 2 );
	% clip @ bridging threshold?
	cMax = EB.Info.BCT * EB.Info.NumEpochs;
	img = min( img, cMax );

	eeg = pop_chanedit( eeg, 'lookup', locsFile );		% do this on EEG, not chanlocs or topos won't have right orientation

	topoOpts = AMPSCZ_EEG_topoOptions( AMPSCZ_EEG_GYRcmap( 256 ) );

	hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' );
% 	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.9, 0.90-0.18 ] );
	hAx  =   axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.9, 0.97-0.18 ] );
	topoplot( img, eeg.chanlocs, topoOpts{:}, 'maplimits', [ 0, cMax ] );
	set( hAx, 'CLim', [ 0, cMax ], 'XLim', [ -0.55, 0.55 ], 'YLim', [ -0.45, 0.55 ] )
	xlabel( sprintf( '%d Bridged Channels', EB.Bridged.Count ), 'Visible', 'on', 'FontSize', 14, 'FontWeight', 'normal' )
% 	title( sprintf( '%s - %s', subjectID, sessionDate ), 'FontSize', 14 )
% 	colorbar

	chanlocs = eeg.chanlocs;

	return

end

