function [ Ztable, Zrange, Ztime ] = AMPSCZ_EEG_readBVimpedance( vhdr )
% Get impedance table from either .vhdr structure returned by bieegl_readBVtxt.m
% or from .vhdr file itself.  This is a AMPSCZ*.m function because it makes some 
% assumptions about the comments in .vhdr file that are consistent with AMPSCZ 
% actiCHamp data files.
%
% USAGE:
% >> [ impedanceTable, impedanceRange, impedanceTime ] = AMPSCZ_EEG_readBVimpedance( vhdrFile );
% or
% >> impedanceTable = AMPSCZ_EEG_readBVimpedance( hdr );
%
% INPUTS:
% vhdrFile is a char-type path to a Brain Vision .vhdr file
% or
% hdr      is a structure returned by bieegl_readBVtxt( vhdrFile )
%
% OUTPUT:
% impedanceTable = #channels x 2 x #recordings cell array, 
%                  where the 1st column is the channel names, 
%                  and the 2nd column are the integer impedance values in kOhm
% impedanceRange = #recordings x 2 array where each row contains [ low, high ] settings
% impedanceTie   = #recordings x 3 array where each row contains [ hour, minute, second ]
%
% For AMPSCZ ProNET the output will be 65x2.  The 1st 63 channels are the same as in the .vhdr Channel
% section with the exception of the 64th 'VIS' photosensor channel.  The 64th impedance is the 
% reference channel 'FCz', and the 65th is ground 'Gnd'.
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 10/14/2021

% to do: figure out Matlab's string class & support that too?
%        allow for non-integer impedances?

	narginchk( 1, 1 )
	
	if ischar( vhdr )
		vhdr = bieegl_readBVtxt( vhdr );
	elseif ~isstruct( vhdr ) || ~all( ismember( { 'Common', 'Channel', 'Comment', 'inputFile' }, fieldnames( vhdr ) ) )
		help( mfilename )
		error( 'Invalid input' )
	end

	% Find impedance section header line
	iImp = ~cellfun( @isempty, regexp( vhdr.Comment, '^Impedance \[kOhm\] at \d{2}:\d{2|:\d{2} :$', 'once', 'start' ) );
	if sum( iImp ) == 0
		Ztable =  cell( 0, 2, 1 );
		Zrange = zeros( 0, 2 );
		Ztime  = zeros( 0, 3 );
		warning( 'Can''t find Impedance section of %s', vhdr.inputFile )
		return
	end
	iImp = find( iImp );
	nZ   = numel( iImp );

	Zrange = regexp( vhdr.Comment, '^Data/Gnd Electrodes Selected Impedance Measurement Range: (\S+) - (\S+) kOhm$', 'tokens', 'once' );
	Zrange = Zrange( ~cellfun( @isempty, Zrange ) );
	if numel( Zrange ) ~= nZ
		warning( 'impedance: #data sets doesn''t match #ranges' )
	end
	if ~isempty( Zrange )
		Zrange =  str2double( cat( 1, Zrange{:} ) );
	end

	Ztime = regexp( vhdr.Comment(iImp), '^Impedance \[kOhm\] at (\d{2}):(\d{2}):(\d{2}) :$', 'tokens', 'once' );
	Ztime = str2double( cat( 1, Ztime{:} ) );
	
	% Check dimensions
	% note:
	% .Common.NumberOfChannels = 64.  Fp1,...,POz,VIS
	% VIS is not in the impedance table
	% there are the 1st 63 channels, then the reference FCz, then Gnd
	% for a total of 65
% 	nChanEEG = vhdr.Common.NumberOfChannels - 1;		% exclude 'VIS' photosensor channel.  do something more adaptible?
% 	nChanEEG = vhdr.Common.NumberOfChannels - any( strcmp( {vhdr.Channel.Ch.name}, 'VIS' ) );
	nChanEEG = nnz( ~strcmp( {vhdr.Channel.Ch.name}, 'VIS' ) );
	iLast    = iImp + nChanEEG + 2;
	nComment = numel( vhdr.Comment );
	if iLast(end) > nComment
		error( 'impedance table shorter than expected' )	% In actiCHamp data files the impedance table concludes the comments
% 	elseif iLast(end) ~= nComment
% 		warning( 'extra comment lines beyond impedance.  extra channels?' )
	end

	% Read the table
	% there can be 'not connected' or 'Out of Range!' in the # column!
	Ztable = cell( nChanEEG+2, 2, nZ );
	for iZ = 1:nZ
		Ztable(:,1,iZ) = regexp( vhdr.Comment(iImp(iZ)+1:iLast(iZ)), '^(\w+):\s*(\S.*)$', 'once', 'tokens' );
		Ztable(:,:,iZ) = cat( 1, Ztable{:,1,iZ} );
	end
	Ztable(:,2,:) = strrep( Ztable(:,2,:), 'Out of Range!', 'Inf' );
	Ztable(:,2,:) = strrep( Ztable(:,2,:), 'not connected', 'NaN' );
	% convert numbers from char to double
	Ztable(:,2,:) = cellfun( @str2double, Ztable(:,2,:), 'UniformOutput', false );
	% compare names w/ Channel section?  I'm being extra cautious
	if ~all( strcmp( { vhdr.Channel.Ch(1:nChanEEG).name }, Ztable(1:nChanEEG,1,1)' ) )
		warning( 'channel name mismatch' )
	end

	return
	
	% Get impedance range settings
		% Good Level [kOhms]     = 25
		% Bad Level [kOhms]      = 72
		% Data/Gnd Electrodes Selected Impedance Measurement Range: 25 - 75 kOhm
	% iLow = ~cellfun( @isempty, regexp( vhdr.Comment, '^Good Level [kOhms]\s+=', 'once', 'start' ) );
	% iLow = contains( vhdr.Comment, 'Good Level [kOhms]' );
	% iRange = contains( vhdr.Comment, Data/Gnd Electrodes Selected Impedance Measurement Range: ' );



end

