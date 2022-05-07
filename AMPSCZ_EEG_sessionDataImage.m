function img = AMPSCZ_EEG_sessionDataImage( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

	narginchk( 2, 7 )
	
	if exist( 'VODMMNruns', 'var' ) ~= 1
		VODMMNruns = [];
	end
	if exist( 'AODruns', 'var' ) ~= 1
		AODruns = [];
	end
	if exist( 'ASSRruns', 'var' ) ~= 1
		ASSRruns = [];
	end
	if exist( 'RestEOruns', 'var' ) ~= 1
		RestEOruns = [];
	end
	if exist( 'RestECruns', 'var' ) ~= 1
		RestECruns = [];
	end

	eeg = AMPSCZ_EEG_eegMerge( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, [ 0.2, Inf ], [ -1, 2 ] );

	% mean reference, nothing fancy, don't want interpolations here
	eeg.data(:) = bsxfun( @minus, eeg.data, mean( eeg.data, 1 ) );
	
	if nargout
		img = eeg.data;
		return
	end

	tSegment = eeg.times( ceil( [ eeg.event( strcmp( { eeg.event.type }, 'boundary' ) ).latency ] ) ) - 0.5/eeg.srate;

	if ispc || true
		% UCSF images
		figure( 'Position', [ 500, 50, 1200, 900 ], 'Colormap', jet( 256 ), 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' )
		imagesc( eeg.times/60e3, 1:eeg.nbchan, eeg.data, [ -1, 1 ]*75 )
		% continuous segment lines
		if numel( tSegment ) > 1
			line( repmat( tSegment(2:end)/60e3, 2, 1 ), [ 0.5; eeg.nbchan+0.5 ], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 2 )
		end
		set( gca, 'YDir', 'reverse' )
		% channel labels
		set( gca, 'YTick', 1:eeg.nbchan, 'YTickLabel', { eeg.chanlocs.labels } )
		xlabel( 'Time (min)' )
		ylabel( 'Channel' )
		if ispc
			title( sprintf( '%s\n%s', subjectID, sessionDate ) )
		end
		ylabel( colorbar( 'YTick', -70:10:70 ), '(\muV)' )
	else
		% DPACC images
		hFig = figure( 'Position', [ 500, 300, 350, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w', 'Colormap', jet( 256 ) );
		hAx  =   axes( 'Units', 'normalized', 'Position', [ 0.15, 0.2, 0.8, 0.75 ] );
		imagesc( eeg.times/60e3, 1:eeg.nbchan, eeg.data, [ -1, 1 ]*75 )
		% continuous segment lines
		if numel( tSegment ) > 1
			line( repmat( tSegment(2:end)/60e3, 2, 1 ), [ 0.5; eeg.nbchan+0.5 ], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1 )
		end
		set( hAx, 'YDir', 'reverse' )
		xlabel( 'Time (min)' )
		ylabel( 'Channel' )
		ylabel( colorbar( 'YTick', -70:10:70 ), '(\muV)' )
	end

	return

end
