function AMPSCZ_EEG_dpdash( subjectID, sessionNum, replaceFlag )
% AMPSCZ_EEG_dpdash( subjectID, sessionNumber, [replaceFlag=false] )

% to do:
% use evalc to get rid of command window clutter?
% give the core of this a new name, and keep QCdpash as the wrapper per convention?


	narginchk( 2, 3 )
	
	if exist( 'replaceFlag', 'var' ) ~= 1 || isempty( replaceFlag )
		replaceFlag = false;
	end

	siteID = subjectID(1:2);
	siteInfo = AMPSCZ_EEG_siteInfo;
	kSite    = strcmp( siteInfo(:,1), siteID );
	if nnz( kSite ) ~= 1
		error( 'site id bug' )
	end
	networkName = siteInfo{kSite,2};
	procDir = fullfile( AMPSCZ_EEG_paths, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteID ], 'processed', subjectID, 'eeg' );
	rawDir  = fullfile( AMPSCZ_EEG_paths, networkName, 'PHOENIX', 'PROTECTED', [ networkName, siteID ], 'raw'      , subjectID, 'eeg' );
	csvIn   = fullfile(  rawDir, sprintf( '%s.%s.Run_sheet_eeg_%d.csv', subjectID, networkName, sessionNum ) );
	metaIn  = fullfile( AMPSCZ_EEG_paths, networkName, 'PHOENIX', 'GENERAL', [ networkName, siteID ], [ networkName, siteID, '_metadata.csv' ] );
	if exist( metaIn, 'file' ) ~= 2
		error( '%s does not exist', metaIn )
	end
	metaData = readcell( metaIn, 'FileType', 'text', 'Delimiter', ',', 'Range', 'A:C', 'DatetimeType', 'text' );		% Active, Consent, Subject ID
	if ~all( strcmp( metaData(1,2:3), { 'Consent', 'Subject ID' } ) )
		error( 'unexpected columns in %s', metaIn )
	end
	kMeta = strcmp( metaData(:,3), subjectID );
	if nnz( kMeta ) ~= 1
		error( 'can''t find unique %s row in %s', subjectID, metaIn )
	end
	consentDate = datenum( metaData{kMeta,2}, 'yyyy-mm-dd' );

	if exist( csvIn, 'file' ) ~= 2
		error( '%s does not exist', csvIn )
	end
	csv = readcell( csvIn, 'FileType', 'text', 'TextType', 'char', 'DateTimeType', 'text', 'Delimiter', ',', 'NumHeaderLines', 0 );
% 	jFieldName  = strcmp( csv(1,:), 'field_name' );
% 	jFieldValue = strcmp( csv(1,:), 'field_value' );
% 	if nnz( jFieldName ) ~= 1
% 		error( 'Can''t identify field name column in EEG run sheet csv' )
% 	end
% 	if nnz( jFieldValue ) ~= 1
% 		error( 'Can''t identify field value column in EEG run sheet csv' )
% 	end
	% Prescient is organized in rows and doesn't have row names
	if strcmp( networkName, 'Prescient' )
		csv = csv';
	end
	jFieldName  = 1;
	jFieldValue = 2;
	switch networkName
		case 'Pronet'
			kDate = strcmp( csv(:,jFieldName), 'chreeg_interview_date' );		% 'YYYY-MM-DD'
			kTech = strcmp( csv(:,jFieldName), 'chreeg_primaryperson' );		% 'FL#'
			dateFmt = 'yyyy-mm-dd';
		case 'Prescient'
% 			kDate = strcmp( csv(:,jFieldName), 'chreeg_interview_date' );		% 'MM/DD/YYYY'
			kDate = strcmp( csv(:,jFieldName), 'interview_date' );				% 'MM/DD/YYYY'
			kTech = strcmp( csv(:,jFieldName), 'chreeg_raname' );				% 'FL#'
			dateFmt = 'mm/dd/yyyy';
		otherwise
			error( 'Unknown network name %s', networkName )
	end
	if nnz( kDate ) ~= 1
		error( 'Can''t identify interview date row in EEG run sheet csv' )
	end
	eegDate     = datenum( csv{kDate,jFieldValue}, dateFmt );
	sessionDate = datestr( eegDate, 'yyyymmdd' );

% 	csvOut  = fullfile( procDir, sprintf( 'AMPSCZ-%s-EEGqc-day%dto%d.csv', subjectID, sessionNum, sessionNum ) );
% 	csvOut  = fullfile( procDir, sprintf( '%s-%s-EEGqc-day%dto%d.csv', subjectID(1:2), subjectID, sessionNum, sessionNum ) );
	sessionDay = eegDate - consentDate + 1;
	csvOut  = fullfile( procDir, sprintf( '%s-%s-EEGqc-day%dto%d.csv', subjectID(1:2), subjectID, sessionDay, sessionDay ) );
	if exist( csvOut, 'file' ) == 2 && ~replaceFlag
		fprintf( '%s exists.\n', csvOut )
		return
	end

	nVal = 19;
	valName = cell( 1, nVal );
	val     =  nan( 1, nVal );		% OK to have NaNs, or replace w/ empty when writing CSV?
	
	[ Ivodmmn, Iaod, Iassr, Ieo, Iec ] = AMPSCZ_EEG_sessionTaskSegments( subjectID, sessionDate );
	
	% # Events
	% 	'MMNstd' ,  16, 0, 578*5		% 2890
	% 	'MMNdev' ,  18, 0,  62*5		%  310
	% 	'VODstd' ,  32, 0, 128*5		%  640
	% 	'VODtrg' ,  64, 0,  16*5		%   80
	% 	'VODnov' , 128, 0,  16*5		%   80
	% 	'VODrsp' ,  17, 0,  16*5		%   80
	% 	'AODstd' ,   1, 0, 160*4		%  640
	% 	'AODtrg' ,   2, 0,  20*4		%   80
	% 	'AODnov' ,   4, 0,  20*4		%   80
	% 	'AODresp',   5, 0,  20*4		%   80
	% 	'ASSR'   ,   8, 0, 200
	% 	'RestEO' ,  20, 0, 180
	% 	'RestEC' ,  24, 0, 180
	[ nFound, nExpected ] = AMPSCZ_EEG_eventGraph( subjectID, sessionDate, Ivodmmn, Iaod, Iassr, Ieo, Iec );
	Ival = 1:6;
	valName(Ival) = { 'dTrialsMMN', 'dTrialsVOD', 'dTrialsAOD', 'dTrialsASSR', 'dTrialsRestEO' 'dTrialsRestEC' };
	val(Ival) = [...
		sum( nFound(1:2) ) - sum( nExpected(1:2) ),...
		sum( nFound(3:5) ) - sum( nExpected(3:5) ),...
		sum( nFound(7:9) ) - sum( nExpected(7:9) ),...
		nFound(11:13) - nExpected(11:13) ];
	
	% Impedance
	zThresh = 25;
	[ Z, ~, Zrange ] = AMPSCZ_EEG_impedanceData( subjectID, sessionDate, 'last' );
	Ival = 7:9;
	valName(Ival) = { 'dZRangeLo', 'dZRangeHi', 'nHighZChan' };
	val(Ival) = [ Zrange - [ 25, 75 ], sum( Z > zThresh ) ];

	% Line Noise
	meanRef = false;
	pThresh = 10;
	P = AMPSCZ_EEG_lineNoise( subjectID, sessionDate, 'median', meanRef, Ivodmmn, Iaod, Iassr, Ieo, Iec );
	Ival = 10;
	valName{Ival} = 'nHighNoiseChan';
	val(Ival) = sum( P > pThresh );

	% Bridging
	hFigBefore = findobj( 'Type', 'figure' );
	EB = AMPSCZ_EEG_eBridge( subjectID, sessionDate, 0, 0, 0, 0, 1, false );					% this is leaving extra figure open - wasn't before???
	close( setdiff( findobj( 'Type', 'figure' ), hFigBefore ) )
	
	Ival = 11;
	valName{Ival} = 'nBridgedChan';
	val(Ival) = EB.Bridged.Count;

	% Performance
	[ pVOD, pAOD ] = AMPSCZ_EEG_performance( subjectID, sessionDate, Ivodmmn, Iaod );
	Ival = 12:19;
	valName(Ival) = { 'dHitRateVOD', 'dHitRateAOD', 'FARateNovVOD', 'FARateNovAOD', 'FARateStdVOD', 'FARateStdAOD', 'RTmedVOD', 'RTmedAOD' };
	kStdVOD = pVOD(:,1) == 0;
	kStdAOD = pAOD(:,1) == 0;
	kTrgVOD = pVOD(:,1) == 1;
	kTrgAOD = pAOD(:,1) == 1;
	kNovVOD = pVOD(:,1) == 2;
	kNovAOD = pAOD(:,1) == 2;
	kButVOD = ~isnan( pVOD(:,2) );
	kButAOD = ~isnan( pAOD(:,2) );
	val(Ival(1:6)) = [
		nnz( kTrgVOD & kButVOD ) / nnz( kTrgVOD ) * 100 - 100
		nnz( kTrgAOD & kButAOD ) / nnz( kTrgAOD ) * 100 - 100
		nnz( kNovVOD & kButVOD ) / nnz( kNovVOD ) * 100
		nnz( kNovAOD & kButAOD ) / nnz( kNovAOD ) * 100
		nnz( kStdVOD & kButVOD ) / nnz( kStdVOD ) * 100
		nnz( kStdAOD & kButAOD ) / nnz( kStdAOD ) * 100
% 		median( pVOD( kTrgVOD & kButVOD, 2 ) ) * 1e3
% 		median( pAOD( kTrgAOD & kButAOD, 2 ) ) * 1e3
	];
	if any( kTrgVOD & kButVOD )
		val(Ival(7)) = median( pVOD( kTrgVOD & kButVOD, 2 ) ) * 1e3;
	end
	if any( kTrgAOD & kButAOD )
		val(Ival(8)) = median( pAOD( kTrgAOD & kButAOD, 2 ) ) * 1e3;
	end

	% Resting alpha power ratio or difference?
% 	AMPSCZ_EEG_alphaRest( subjectID, sessionDate )

% 	disp( [ valName(:), num2cell( val(:) ) ] )

	% see https://sites.google.com/g.harvard.edu/dpdash/documentation/user_doc?authuser=0
	fid = fopen( csvOut, 'w' );
	fprintf( fid, 'reftime,day,timeofday,weekday' );
	fprintf( fid, ',%s', valName{:} );
	fprintf( fid, '\n,%d,,,%d,%d,%d,%d,%d,%d,%g,%g,%d,%d,%d,%g,%g,%g,%g,%g,%g,%g,%g', sessionNum, val );
	fprintf( fid, '\n' );		% so it displays better in terminal
	fclose( fid );
	fprintf( 'wrote %s\n', csvOut )

	return

end