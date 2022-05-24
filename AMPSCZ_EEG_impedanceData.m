function [ Z, Zname, Zrange, Ztime ] = AMPSCZ_EEG_impedanceData( subjectID, sessionDate, impedanceType )
%
% usage:
% >> AMPSCZ_EEG_impedanceData( subjectID, sessionDate, [impedanceType] )
% impedanceType = 'first', 'last', 'best', 'worst', 'mean', or 'median'
%                 default is 'last'

	narginchk( 2, 3 )

	if exist( 'impedanceType', 'var' ) ~= 1 || isempty( impedanceType )
		impedanceType = 'last';
	elseif ~ischar( impedanceType )
		error( 'impedanceType must be char' )
	else
		impedanceType = lower( impedanceType );
		if ~ismember( impedanceType, { 'first', '1st', 'begin', 'last', 'end',...
				'best', 'minimum', 'min', 'worst', 'maximum', 'max', 'mean', 'average', 'avg', 'median', 'med' } )
			error( 'invalid impedanceType %s', impedanceType )
		end
	end
	
	if false
		[ VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns ] = deal( 'all' );
		vhdr = AMPSCZ_EEG_vhdrFiles( subjectID, sessionDate, VODMMNruns, AODruns, ASSRruns, RestEOruns, RestECruns, false );
	else	% faster if you're for sure finding all vhdr files
		bidsDir = fullfile( AMPSCZ_EEG_procSessionDir( subjectID, sessionDate ), 'BIDS' );
		if ~isfolder( bidsDir )
			error( '%s is not a valid directory', bidsDir )
		end
% 		vhdrFmt = '*.vhdr';
		vhdrFmt = [ 'sub-', subjectID, '_ses-', sessionDate, '_task-*_run-*_eeg.vhdr' ];
		vhdr = dir( fullfile( bidsDir, vhdrFmt ) );
	end
	nHdr = numel( vhdr );

	[ Z, Zrange, Ztime ] = deal( cell( 1, nHdr ) );
	for iHdr = 1:nHdr
		[ Z{iHdr}, Zrange{iHdr}, Ztime{iHdr} ] = AMPSCZ_EEG_readBVimpedance( fullfile( vhdr(iHdr).folder, vhdr(iHdr).name ) );
		if iHdr == 1
			Zname = Z{iHdr}(:,1);
		elseif size( Z{iHdr}, 1 ) ~= numel( Zname ) || ~all( strcmp( Z{iHdr}(:,1), Zname ) )
			error( 'Impedance channel mismatch across measures' )
		end
		Z{iHdr} = cell2mat( permute( Z{iHdr}(:,2,:), [ 1, 3, 2 ] ) );		% channels x measurements matrix, drop names
	end
	Z      = cat( 2, Z{:} );
	Zrange = cat( 1, Zrange{:} );
	Ztime  = cat( 1, Ztime{:}  ) * [ 3600; 60; 1 ];
	
	% Get rid of redudant copies of measurements & sort chronologically
	[ Ztime, Iu ] = unique( Ztime, 'sorted' );
	Z      = Z(:,Iu);
	Zrange = Zrange(Iu,:);
	
	% drop ground, not in locs files
	kZ = strcmp( Zname, 'Gnd' );
	Zname(kZ) = [];
	Z(kZ,:)   = [];
	clear kZ

	% drop all-NaN colums
	kNaN = all( isnan( Z ), 1 );
	if all( kNaN )
		warning( 'no impedance data found' )
	else
		Z(:,kNaN) = [];
	end
		
	% Choose measurement - this is done inside AMPSCZ_EEG_plotImpedanceTopo
	switch impedanceType
		case { 'first', '1st', 'begin' }
			Z      = Z(:,1);
			Zrange = Zrange(1,:);
		case { 'last', 'end' }
			Z      = Z(:,end);
			Zrange = Zrange(end,:);
		case { 'best', 'minimum', 'min' }
			Z = min( Z, [], 2 );
			Zrange = min( Zrange, [], 1 );
% 			Zrange = mean( Zrange, 1 );
		case { 'worst', 'maximum', 'max' }
			Z = max( Z, [], 2 );
			Zrange = max( Zrange, [], 1 );
% 			Zrange = mean( Zrange, 1 );
		case { 'mean', 'average', 'avg' }
			Z = mean( Z, 2 );
			Zrange = mean( Zrange, 1 );
		case { 'median', 'med' }
			Z = median( Z, 2 );
% 			Zrange = median( Zrange, 1 );
			Zrange = mean( Zrange, 1 );
	end
	
	if nargout ~= 0
		return
	end

	locsFile = fullfile( fileparts( which( 'pop_dipfit_batch.m' ) ), 'standard_BEM', 'elec', 'standard_1005.ced' );
	chanlocs = readlocs( locsFile, 'importmode', 'eeglab', 'filetype', 'chanedit' );	% nose +X, left +Y
% 	chanlocs = pop_chanedit( chanlocs, 'lookup', Zname );
	[ ~, Iloc ] = ismember( Zname, { chanlocs.labels } );
	if any( Iloc == 0 )
		error( 'Can''t identify channel(s)' )
	end
	chanlocs = chanlocs(Iloc);
	clear Iloc


	figure( 'Position', [ 500, 300, 525, 250 ], 'MenuBar', 'none', 'Tag', mfilename, 'Color', 'w' )		
	hAx = axes( 'Units', 'normalized', 'Position', [ 0, 0.18, 0.55, 0.97-0.18 ] );
	zThresh = 25;				% impedance threshold
	zLimit  = zThresh * 2;
	AMPSCZ_EEG_plotImpedanceTopo( hAx, Zname, Z, chanlocs, Zrange, zThresh, zLimit )

	return
	
end
