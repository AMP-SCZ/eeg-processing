function [ outStruct, options, T ] = bieegl_readBVtxt( bvFile, options )
% Reads BVCDF (BrainVision Core Data Format) .vhdr or .vmrk file and
% checks for compliance with file format specifications, see
% https://www.presentica.com/doc/11351053/description-of-the-brainvision-core-data-format-1-0-pdf-document
%
% Unlike some other tools available on the web, this returns structures that preserve
% the organization and section and key names inherent in the file specification.
%
% USAGE:
% >> [ outStruct, options, textCell ] = bieegl_readBVtxt( BVtextFile, [options] )
%
% INPUTS:
% BVtextFile = full or partial path to BrainVision .vhdr or .vmrk file (char)
% options    = options structure (struct)
%              valid fields are:
%                 convertResolution, convert .vhdr [Channel Infos] Ch# resolution
%                                    from text to numeric format
%                                    default = true
%                 ext,               an extension to check BVtextFile against
%                                    e.g. limit it to .vdhr or .vmrk files
%                                    default = '' for no check
%                 verbose,           a logical scalar possibly useful for debugging
%                                    default = false
%
% OUTPUTS:
% outStruct = output structure
%             1st-level fields are the file sections
%             2nd-level fields are the section key names
% options   = options struct that was actually used
%             missing fields replaced with defaults
%             extra fields removed
% textCell  = #x1 cell array of char
%             all the lines of BVtextFile
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 08/31/2021


% MarkerStruct.Common.Codepage = 'UTF-8'
% MarkerStruct.Common.DataFile = corresponding data file name
%                                .eeg, .avg, or .seg extension
% MarkerStruct.Marker.Mk       = 1 x # struct w/ fields
% MarkerStruct.Marker.Mk.type
% MarkerStruct.Marker.Mk.description
% MarkerStruct.Marker.Mk.position
% MarkerStruct.Marker.Mk.points
% MarkerStruct.Marker.Mk.channel
% MarkerStruct.Marker.Mk.date

% To do:
% validate options input fields? decided to just remove invalid fields

	try

		narginchk( 1, 2 )

		% Validate options structure if input, otherwise use default
		defaultOpts = struct( 'ext', '', 'verbose', false, 'convertResolution', true );
		if exist( 'options', 'var' ) ~= 1 || isempty( options )
			options = defaultOpts;
		elseif isstruct( options )
			fn = setdiff( fieldnames( defaultOpts ), fieldnames( options ) );
			if ~isempty( fn )
				for fn = [ fn(:) ]'
					options.(fn{1}) = defaultOpts.(fn{1});
				end
			end
			fn = setdiff( fieldnames( options ), fieldnames( defaultOpts ) );
			if ~isempty( fn )
				options = rmfield( options, fn );
			end
		else
			error( 'Invalid options input' )
		end

		% Validate bvFile input
		% -- make sure it's char type
		if ~ischar( bvFile )
			help( mfilename )
			error( 'Invalid filename input, non-char' )
		end
		% -- make sure it points to a file that exits
		if exist( bvFile, 'file' ) ~= 2
			error( 'Invalid filename\n%s does not exist', bvFile )
		end
		% -- check extension against options.ext
		[ ~, ~, bvExt ] = fileparts( bvFile );
		if isfield( options, 'ext' )
			if ischar( options.ext )
				if ~isempty( options.ext ) && ~strcmp( bvExt, options.ext )
					error( 'File extension (%s) does not match option (%s)', bvExt, options.ext )
				end
			else
				error( 'Invalid "ext" option - non-char' )
			end
% 		else
% 			options.ext = bvExt;
		end
		% -- check for valid BV extension
		switch bvExt
			case '.vhdr'
				validLine1 = {
					'BrainVision Data Exchange Header File Version 1.0'
					'Brain Vision Data Exchange Header File Version 1.0'    % obsolete, for backward compatibility
					};
				% { section name, mandatory flag, valid keys }
				validSections = {
					'[Common Infos]' ,  true, { 'Codepage', 'DataFile', 'MarkerFile', 'DataFormat', 'DataOrientation', 'DataType', 'NumberOfChannels', 'SamplingInterval', 'Averaged', 'AveragedSegments', 'SegmentDataPoints', 'SegmentationType' }
					'[Binary Infos]' ,  true, { 'BinaryFormat' }
					'[Channel Infos]',  true, { 'Ch*' }
					'[Coordinates]'  , false, { 'Ch*' }
					'[Comment]'      , false, { '*' }
				};
				outStruct = struct(...
					'Common'     , struct( 'Codepage', [], 'DataFile', [], 'MarkerFile', [] ),...
					'Binary'     , struct( 'BinaryFormat', [] ),...
					'Channel'    , struct( 'Ch', [] ),...
					'Coordinates', struct( 'Ch', [] ),...
					'Comment'    , '',...
					'inputFile'  , bvFile );

				% *** put expected values in here too? ***
				% { name, mandatoryFlag, index, value }
				% commonKey = {
				% 	'Codepage',           true
				% 	'DataFile',           true
				% 	'MarkerFile',        false
				% 	'DataFormat',         true
				% 	'DataOrientation',    true
				% 	'DataType',          false
				% 	'NumberOfChannels',   true
				% 	'SamplingInterval',   true
				% 	'Averaged',          false
				% 	'AveragedSegment',   false
				% 	'SegmentDataPoints', false
				% 	'SegmentationType',  false
				% };

			case '.vmrk'
				validLine1 = {
					'BrainVision Data Exchange Marker File Version 1.0'
					'Brain Vision Data Exchange Marker File, Version 1.0'   % obsolete, for backward compatibility
					'Brain Vision Data Exchange Marker File Version 1.0'    % obsolete, for backward compatibility
					};
				validSections = {
					'[Common Infos]', true, { 'Codepage', 'DataFile',  }
					'[Marker Infos]', true, { 'Mk*' }
					};
				outStruct = struct(...
					'Common'   , struct( 'Codepage', [], 'DataFile', [] ),...
					'Marker'   , struct( 'Mk', [] ),...
					'inputFile', bvFile );
			case { '.eeg', '.avg', '.seg' }
				error( 'Invalid filename, this program doesn''t open BV data files' )
			otherwise
				error( 'Invalid filename, unknown extension %s', bvExt )
		end

		% Read file, line by line into cell array
		% -- open
		[ fid, msg ] = fopen( bvFile, 'r' );
		if fid == -1
			error( msg )
		end
		% -- 1st line
		line1 = fgets( fid );
		iEndLine = find( ismember( line1, sprintf( '\r\n' ) ) );    % [ 13, 10 ]
		nEndLine = numel( iEndLine );
		switch nEndLine
			case 1
			case 2
			otherwise
				error( 'Invalid %s file - unknown line termination sequence', bvExt )
		end
		if iEndLine(1) == 1
			error( 'Invalid %s file - empty 1st line', bvExt )
		end
		if ~any( ismember( line1(1:iEndLine(1)-1), validLine1 ) )
			error( 'Invalid %s file - illegal 1st line', bvExt )
		end
        % -- rest of file
        T = textscan( fid, '%s', 'Delimiter', line1(end) );     % T{1} is a #x1 cell array of char
		if fclose( fid ) == -1
            warning( 'MATLAB:fcloseError', 'fclose error' )
		end

		% Remove outermost cell layer for simplicity & put line1 back in the mix
		T = [ { line1(1:iEndLine(1)-1) }; T{1} ];

		% Command window dump?
		if options.verbose
			fprintf( '\n%s %s\n', bvFile, repmat( '-', [ 1, 80-1-numel(bvFile) ] ) )
		end

		% Get rid of extra line termination character? no need
% 		if nEndLine == 2
% 		end

		% Identify section breaks
		Isection = find( ~cellfun( @isempty, regexp( T, '^\[[\w ]+\]$', 'once', 'start' ) ) );
		% -- check that section names found are all valid for given file type
		kValid = ismember( T(Isection), validSections(:,1) );
		if ~all( kValid )
			if options.verbose
				disp( T(Isection(~kValid)) )
			end
			error( 'Invalid %s file - invalid section name', bvExt )
		end
		% -- check that all mandatory sections are present
		if ~all( ismember( validSections([validSections{:,2}],1), T(Isection) ) )
			error( 'Invalid %s file - missing sections', bvExt )
		end
		
		% Add a dummy index @ end for convenience
		nSection = numel( Isection );
		Isection(nSection+1) = numel( T ) + 1;
		
		% Handle [Comment] section, .vhdr only
% 		if strcmp( bvExt, '.vhdr' )
			iSection = find( strcmp( T(Isection(1:nSection)), '[Comment]' ) );
			if ~isempty( iSection )
				Irange = Isection(iSection)+1:Isection(iSection+1)-1;
				outStruct.Comment = T(Irange);
			end
% 		else
% 			iSection = [];
% 		end
		for iSection = setdiff( 1:nSection, iSection )

			% Range of rows of text file
			Irange = Isection(iSection)+1:Isection(iSection+1)-1;
	
			% -- only parse non-empty & non-comment lines
			kParse = cellfun( @(u) ~(isempty(u)) & ~strncmp(u,';',1), T(Irange) );

			switch T{Isection(iSection)}
				case '[Channel Infos]'		% implies .vhdr

					% key#, channel name, reference channel name, resolution, unit
					Ch = regexp( T(Irange(kParse)), '^Ch(\d+)=([^,]+),([^,]*),([\d\.]*),*([^,]*)$', 'tokens', 'once' );
					kBad = cellfun( @isempty, Ch );
					if any( kBad )
						error( 'Invalid %s file - bad Ch# key(s)', options.ext )
% 						Ch(kBad) = [];
					end
					Ch = reshape( [ Ch{:} ], [ 5, numel( Ch ) ] );

					% Channel #s must start with 1 and increase in steps of 1!
					Ch(1,:) = cellfun( @eval, Ch(1,:), 'UniformOutput', false );
					if Ch{1,1} ~= 1 || any( diff( [ Ch{1,:} ] ) ~= 1 )
						error( 'Invalid %s file - bad channel# sequence', options.ext )
					end

					% channel name is mandatory and not empty
					if any( cellfun( @isempty, Ch(2,:) ) )
						error( 'Invalid %s file - missing channel name(s)', options.ext )
					end

					% reference channel name is mandatory and may be empty

					% resolution is mandatory double>0 and may be empty implying resolution=1
					if options.convertResolution
						kFull = ~cellfun( @isempty, Ch(4,:) );
						Ch(4,kFull) = cellfun( @eval, Ch(4,kFull), 'UniformOutput', false );
						if any( [ Ch{4,kFull} ] <= 0 )
							error( 'Invalid %s file - resolution <= 0', options.ext )
						end
						% replace empty resolutions with default value of 1?
%						[ Ch{4,~kFull} ] = deal( 1 );
					end

					% unit is optional and may be empty implying microvolts

					outStruct.Channel.Ch = struct(...
						'name',       Ch(2,:),...
						'reference',  Ch(3,:),...
						'resolution', Ch(4,:),...
						'unit',       Ch(5,:) );

				case '[Coordinates]'		% implies .vhdr

					% key#, radius, theta, phi
					Ch = regexp( T(Irange(kParse)), '^Ch(\d+)=([\d\.]+),([-\d\.]+),([-\d\.]+)$', 'tokens', 'once' );
					kBad = cellfun( @isempty, Ch );
					if any( kBad )
						error( 'Invalid %s file - bad Ch# key(s)', options.ext )
						Ch(kBad) = [];
					end
					Ch = reshape( [ Ch{:} ], [ 4, numel( Ch ) ] );
					% Channel #s must start with 1 and increase in steps of 1!
					Ch(1,:) = cellfun( @eval, Ch(1,:), 'UniformOutput', false );
					if Ch{1,1} ~= 1 || any( diff( [ Ch{1,:} ] ) ~= 1 )
						error( 'Invalid %s file - bad channel# sequence', options.ext )
					end
					% radius mandatory double >= 0
					Ch(2,:) = cellfun( @eval, Ch(2,:), 'UniformOutput', false );
					% theta  mandatory double, what are units & valid range?
					Ch(3,:) = cellfun( @eval, Ch(3,:), 'UniformOutput', false );
					% phi   mandatory double
					Ch(4,:) = cellfun( @eval, Ch(4,:), 'UniformOutput', false );

					outStruct.Coordinates.Ch = struct(...
						'radius', Ch(2,:),...
						'theta',  Ch(3,:),...
						'phi',    Ch(4,:) );

				case '[Marker Infos]'		% implies .vmrk

					% key#, type, description, position, channel number, date
					Mk = regexp( T(Irange(kParse)), '^Mk(\d+)=([^,]+),([^,]*),([1-9]\d*),(\d+),(-1|[\d+]),*(\d*)$', 'tokens', 'once' );
					kBad = cellfun( @isempty, Mk );
					if any( kBad )
						error( 'Invalid %s file - bad Mk# key(s)', options.ext )
% 						Mk(kBad) = [];
					end
					Mk = reshape( [ Mk{:} ], [ 7, numel( Mk ) ] );
					% Marker #s must start with 1 and increase in steps of 1!
					Mk(1,:) = cellfun( @eval, Mk(1,:), 'UniformOutput', false );
					if Mk{1,1} ~= 1 || any( diff( [ Mk{1,:} ] ) ~= 1 )
						error( 'Invalid %s file - bad marker# sequence', options.ext )
					end
					% Position = integer > 0
					Mk(4,:) = cellfun( @eval, Mk(4,:), 'UniformOutput', false );
					% Points   = integer >=  0
					Mk(5,:) = cellfun( @eval, Mk(5,:), 'UniformOutput', false );
					% Channel# = integer >= -1? table says -1=all, but example says 0=all
					Mk(6,:) = cellfun( @eval, Mk(6,:), 'UniformOutput', false );
					% Date is either empty or 20-digit string, YYYYMMDDHHMMSSmmmmmm
					% where mmmmmm are microseconds
					if ~all( ismember( cellfun( @numel, Mk(7,:) ), [ 0, 20 ] ) )
						error( 'Invalid %s file - bad marker date format', options.ext )
					end
					outStruct.Marker.Mk = struct(...
						'type',        Mk(2,:),...
						'description', Mk(3,:),...
						'position',    Mk(4,:),...
						'points',      Mk(5,:),...
						'channel',     Mk(6,:),...
						'date',        Mk(7,:) );

				otherwise

					keyData = regexp( T(Irange(kParse)), '^(\w+)=(.+)$', 'once', 'tokens' );
					if any( cellfun( @isempty, keyData ) )
						error( 'Invalid $s file - invalid key line in section %s', bvExt, T{Isection(iSection)} )
					end
					keyData = reshape( [ keyData{:} ], [ 2, numel( keyData ) ] );
					% test key names
					% check that all keynames found are valid
					kValid = strcmp( validSections(:,1), T{Isection(iSection)} );
					% already verified section names are all valid, this has to be one unless you have duplicates in validSections(:,1)
%					if sum( kValid ) ~= 1
% 						error( 'bug' )
%					end
					if ~all( ismember( keyData(1,:), validSections{kValid,3} ) )
						error( 'Invalid $s file - invalid key name in section %s', bvExt, T{Isection(iSection)} )
					end
					% check that all mandatory key names are present?
					fname = strtok( T{Isection(iSection)}(2:end-1), ' ' );
					outStruct.(fname) = cell2struct( keyData(2,:), keyData(1,:), 2 );
	
			end
		end

		switch bvExt
			case '.vhdr'

				% -- Validate Common Infos
				%    Codepage          = 'UTF-8'                           mandatory
				%    DataFile                                              mandatory
				%    MarkerFile                                            optional
				%    DataFormat        = 'BINARY'                          mandatory
				%    DataOrientation   = 'MULTIPLEXED'                     mandatory
				%    DataType          = 'TIMEDOMAIN'                      optional
				%    NumberOfChannels  = (integer>0)                       mandatory
				%    SamplingInterval  = (double>0 in mircoseconds)        mandatory
				%    Averaged          = 'YES' or 'NO'                     optional
				%    AveragedSegment   = (integer>0)                       mandatory if Averaged='YES', optional otherwise.  Could be 0 if Averaged='NO'
				%    SegmentDataPoints = (integer>0)                       mandatory if SegmentationType!='NOTSEGMENTED', optional otherwise.  Could be 0 if SegmentationType='NOTSEGMENTED'
				%    SegmentationType  = 'NOTSEGMENTED' or 'MARKERBASED'   mandatory if Averaged='YES', optional otherwise.  Must be 'NOTSEGMENTED' if Averaged='YES'
				%
				% MULTIPLEXED means: ch1 t1, ch2 t1, ... chN t1, ch1 t2, ch2 t2, ... chN t2, ...

				testVal = 'UTF-8';
				if ~strcmp( outStruct.Common.Codepage, testVal )
					error( 'Invalid %s file - non-%s character encoding', options.ext, testVal )
				end

				testVal = 'BINARY';
				if ~strcmp( outStruct.Common.DataFormat, testVal )
					error( 'Invalid %s file - non-%s data format', options.ext, testVal )
				end

				testVal = 'MULTIPLEXED';
				if ~strcmp( outStruct.Common.DataOrientation, testVal )
					error( 'Invalid %s file - non-%s data orientation', options.ext, testVal )
				end

				if isfield( outStruct.Common, 'DataType' )
					testVal = 'TIMEDOMAIN';
					if ~strcmp( outStruct.Common.DataType, testVal )
						error( 'Invalid %s file - non-%s data type', options.ext, testVal )
					end
				end

				outStruct.Common.NumberOfChannels = eval( outStruct.Common.NumberOfChannels );
				if mod( outStruct.Common.NumberOfChannels, 1 ) ~= 0 || outStruct.Common.NumberOfChannels <= 0
					error( 'Invalid %s file - #channels <= 0', options.ext )
				end

				outStruct.Common.SamplingInterval = eval( outStruct.Common.SamplingInterval );
				if outStruct.Common.SamplingInterval <= 0
					error( 'Invalid %s file - sampling interval <= 0', options.ext )
				end

				avgYes = false;
				if isfield( outStruct.Common, 'Averaged' )
					if ~ismember( outStruct.Common.Averaged, { 'YES', 'NO' } )
						error( 'Invalid %s file - invalid [Common Infos]Averaged', options.ext )
					end
					avgYes(:) = strcmp( outStruct.Common.Averaged, 'YES' );
				end

				if avgYes

					if ~isfield( outStruct.Common, 'AveragedSegment' )
						error( 'Invalid %s file - [Common Infos] AveragedSegment requried when Averaged=''YES''', options.ext )
					end
					outStruct.Common.AveragedSegment = eval( outStruct.Common.AveragedSegment );
					if outStruct.Common.AveragedSegment <= 0
						error( 'Invalid %s file - AveragedSegment <= 0', options.ext )
					end

					if ~isfield( outStruct.Common, 'SegmentationType' )
						error( 'Invalid %s file - [Common Infos] SegmentationType requried when Averaged=''YES''', options.ext )
					end
					if ~strcmp( outStruct.Common.SegmentationType, 'NOTSEGMENTED' )
						error( 'Invalid %s file - SegmentationType must be ''NOTSEGMENTED'' when Averaged=''YES''', options.ext )
					end

				end

				if isfield( outStruct.Common, 'SegmentationType' ) && ~strcmp( outStruct.Common.SegmentationType, 'NOTSEGMENTED' )
					if ~isfield( outStruct.Common, 'SegmentDataPoints' )
						error( 'Invalid %s file - [Common Infos] SegmentDataPoints requried when SegmentationType~=''NOTSEGMENTED''', options.ext )
					end
					outStruct.Common.SegmentDataPoints = eval( outStruct.Common.SegmentDataPoints );
					if outStruct.Common.SegmentDataPoints <= 0
						error( 'Invalid %s file - SegmentDataPoints <= 0', options.ext )
					end
				end

				if ~ismember( outStruct.Binary.BinaryFormat, { 'IEEE_FLOAT_32', 'INT_16' } )
					error( 'Invalid %s file - unknown binary format', options.ext )
				end

			case '.vmrk'

				testVal = 'UTF-8';
				if ~strcmp( outStruct.Common.Codepage, testVal )
					error( 'Invalid %s file - non-%s character encoding', options.ext, testVal )
				end

		end
		
	catch ME
		rethrow( ME )
	end

	return

end