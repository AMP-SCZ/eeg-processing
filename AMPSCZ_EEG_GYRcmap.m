function [ cmap, badChanColor ] = AMPSCZ_EEG_GYRcmap( nmap )
% green-yellow-red color map for AMP SCZ QC topography plots
% 
% usage:
% >> cmap = AMPSZC_EEG_GYRcmap( [ nmap ] );
%
% where optional input 
%    nmap = #rows in the color map (default=256)
% and output
%    cmap = nmap x 3 color map
%           of doubles in range [ 0, 1 ]

	narginchk( 0, 1 )
	if nargin == 0
		nmap = 256;
	end

	% [ R, G, B, transition value ]
	mapSpec = [
		0    , 0.625, 0, nan	% green (starts from zero)
		1    , 1    , 0, 3/6	% yellow
		1    , 0.5  , 0, 4/6	% orange
		1    , 0    , 0, 5/6	% bright red
		0.625, 0    , 0, nan	% dark red (ends at one)
	];

	F    = linspace( 0, 1, nmap )';
	cmap = zeros( nmap, 3 );

	% 1st band
	iRow = 1;
		kF = F < mapSpec(iRow+1,4);
		nF = nnz( kF );
		for iCol = 1:3
			cmap(kF,iCol) = linspace( mapSpec(iRow,iCol), mapSpec(iRow+1,iCol), nF );
		end
	% intermediate bands
	for iRow = 2:size( mapSpec, 1 )-2
		kF(:) = F >= mapSpec(iRow,4) & F < mapSpec(iRow+1,4);
		nF(:) = nnz( kF );
		for iCol = 1:3
			cmap(kF,iCol) = linspace( mapSpec(iRow,iCol), mapSpec(iRow+1,iCol), nF );
		end
	end
	% last band
	iRow(:) = iRow + 1;
		kF(:) = F >= mapSpec(iRow,4);
		nF(:) = nnz( kF );
		for iCol = 1:3
			cmap(kF,iCol) = linspace( mapSpec(iRow,iCol), mapSpec(iRow+1,iCol), nF );
		end

	badChanColor = [ 0.875, 1, 1 ];		% something that has reasonable contrast across color map

	return
	
end