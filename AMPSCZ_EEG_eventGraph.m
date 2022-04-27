function AMPSCZ_EEG_eventGraph( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns )

% separate out redundant code in AMPSCZ_EEG_eegMerge.m, AMPSCZ_EEG_checkRuns.m, AMPSCZ_EEG_eventGraph.m

	narginchk( 2, 7 )

	[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( [] );
	sortFlag = false;
	vhdr     = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, sortFlag );
	nHdr     = numel( vhdr );
	
	codeTotals = {
		'MMNstd' ,  16, 0, 578*5		% 2890
		'MMNdev' ,  18, 0,  62*5		%  310
		'VODstd' ,  32, 0, 128*5		%  640
		'VODtrg' ,  64, 0,  16*5		%   80
		'VODnov' , 128, 0,  16*5		%   80
		'VODrsp' ,  17, 0,  16*5		%   80
		'AODstd' ,   1, 0, 160*4		%  640
		'AODtrg' ,   2, 0,  20*4		%   80
		'AODnov' ,   4, 0,  20*4		%   80
		'AODresp',   5, 0,  20*4		%   80
		'ASSR'   ,   8, 0, 200
		'RestEO' ,  20, 0, 180
		'RestEC' ,  24, 0, 180
	};
	% response code totals will be all button codes, not just those in allowable reaction time range
% 	RTrange = AMPSCZ_EEG_RTrange;
	% concatenate into a single eeg structure
	nSensor = 0;
	for iHdr = 1:nHdr
		eeg = pop_loadbv( vhdr(iHdr).folder, vhdr(iHdr).name );
		for iCode = 1:size( codeTotals, 1 )
			codeTotals{iCode,3} = codeTotals{iCode,3} + nnz( strcmp( { eeg.event.type }, sprintf( 'S%3d', codeTotals{iCode,2} ) ) );
		end
		if strcmp( vhdr(iHdr).name(31:36), 'VODMMN' )
			vis       = double( sort( eeg.data(64,:), 2, 'ascend' ) );		% eeg is single
			visLo     = vis( round( 0.7 * eeg.pnts ) );		% 70% cdf
			visHi     = vis( round( 0.8 * eeg.pnts ) );		% 80% cdf
			if visHi - visLo > 200000*0.0488		% 0.0488 in conversion to muV.  same for all sites?
				nEnd      = 10;
				nGap      = 40;
				vis(:)    = ( eeg.data(64,:) > ( ( visLo + visHi ) / 2 ) ) * 2 - 1;		% -1 or 1
				visOn     = filter( [ ones(1,nEnd), zeros(1,nGap), -ones(1,nEnd) ], 1, vis ) == 2*nEnd;
				visOn(:)  = [ false, visOn(2:eeg.pnts) & ~visOn(1:eeg.pnts-1) ];
				visOn     = find( visOn ) - nEnd;
				nSensor(:)  = nSensor + numel( visOn );
			end
		end
	end
	nVisStim = sum( [ codeTotals{3:5,4} ] );
	
% 	[ nSensor, nVisStim ]

	pe = [ codeTotals{:,3}, nSensor ] ./ [ codeTotals{:,4}, nVisStim ] * 100;
	clf
	hBar = bar( [ 1 4 10 15 ], pe([ 1 3 7 11 ]), 1/3 );		% standard (blue)
	hold on
	hBar = [
		hBar
		bar( [ 2 5 11 ], pe([ 2 5  9 ]), 1/3 )				% deviant/novel (red)
		bar( [   6 12 ], pe([   4  8 ]), 1/6 )				% target (orange)
		bar( [  17 18 ], pe([  12 13 ]), 1   )				% rest (purple)
		bar( [   7 13 ], pe([   6 10 ]), 1/6 )				% response (green)
		bar( [      8 ], pe(      14  ), 1   )				% photosensor (cyan)
	];
	hold off
	set( gca, 'XTick', [ 1.5, 6, 11.5, 15, 17.5 ], 'XTickLabel', { 'MMN', 'VOD', 'AOD', 'ASSR', 'Rest' },...
		'XLim', [ -1, 19 ], 'YGrid', 'on', 'XTickLabelRotation', 45 )
	ylabel( 'Events (%)' )
	title( sprintf( '%s\n%s', subjectID, sessionDate ) )
	legend( hBar([1:3,5:6]), { 'Std', 'Dev/Nov', 'Trg', 'Resp', 'Sensor' }, 'Location', 'NorthEastOutside' )
	
end