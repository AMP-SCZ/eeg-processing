function D = bieegl_readBVdata( H, parentDir )
% Reads BVCDF (BrainVision Core Data Format) data file
%
% USAGE:
% >> DataMatrix = bieegl_readBVdata( HeaderStruct, [parentDir] );
%
% INPUT:
% HeaderStruct = structure returned by bieegl_readBVtxt.m
%                from a .vhdr file input
%
% OUTPUT:
% DataMatrix = a #channels x #samples numeric matrix
%              in the native format, either int16 or float32
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 09/02/2021

% To do:
% variable input options? e.g. a header file string, a data file string + format & #channels

	try
		
		narginchk( 1, 2 )

		% Determine binary format
		switch H.Binary.BinaryFormat
			case 'INT_16'
				dataFmt = '*int16';		% '*' forces output class to match source
			case 'IEEE_FLOAT_32'
				dataFmt = '*float32';
% 			otherwise
		end

		% Open file
		if exist( 'parentDir', 'var' ) == 1 && ~isempty( parentDir )
			if ~ischar( parentDir ) || ~isfolder( parentDir )
				error( 'invalid parentDir input' )
			end
			[ fid, msg ] = fopen( fullfile( parentDir, H.Common.DataFile ), 'r' );
		elseif exist( H.Common.DataFile, 'file' ) == 2
			[ fid, msg ] = fopen( H.Common.DataFile, 'r' );
		else
			[ fid, msg ] = fopen( fullfile( fileparts( H.inputFile ), H.Common.DataFile ), 'r' );
		end
		if fid == -1
			error( msg )
		end

		% Read the whole thing
		D = fread( fid, Inf, dataFmt );		% takes about 3.2 sec for a ProNET file on vhasfcapp21

		% Close file
		if fclose( fid ) == -1
            warning( 'MATLAB:fcloseError', 'fclose error' )
		end

		% Reshape into #channels x #samples matrix
		nD = numel( D );
		if mod( nD, H.Common.NumberOfChannels ) ~= 0
			error( '# data points not divisible by # channels' )
		end
		nSamplePerChan = nD / H.Common.NumberOfChannels;
		switch H.Common.DataOrientation
			case 'MULTIPLEXED'
				D = reshape( D, [ H.Common.NumberOfChannels, nSamplePerChan ] );
% 			otherwise		% 'MULTIPLEXED is only options in BrainVision spec?
% 				D = reshape( D, [ nSamplePerChan, H.Common.NumberOfChannels ] );
		end

		return

	catch ME

		fclose( 'all' )
		rethrow( ME )

	end

end