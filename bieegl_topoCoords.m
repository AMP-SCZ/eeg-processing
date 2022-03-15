function [ topoX, topoY ] = bieegl_topoCoords( chanlocs )
% Get X & Y coords of electrode markers in 2D flattening 
% from EEGLAB's topoplot function.  This calculation 
% involves a mysterious "squeeze factor" which is derived 
% from an equation that's hard to remember, hence the 
% creation of this function.  It's useful if you want to
% overlay markers over particular channels after running 
% topoplot.m
% 
% note: orientation of nose will depend on chanlocs
%       i.e. if nose @ +X in chanlocs, then 
%       plot( topoY, topoX ) will yield nose up topography
%
% usage:
% >> [ topoX, topoY ] = bieegl_topoCoords( chanlocs );

	topoRadius = [ chanlocs.radius ];
	topoTheta  = [ chanlocs.theta  ];
	fXY        = 0.5 / max( min( 1, max( topoRadius ) * 1.02 ), 0.5 );		% topoplot.m squeeze factor
	topoX      = topoRadius .* cosd( topoTheta ) * fXY;
	topoY      = topoRadius .* sind( topoTheta ) * fXY;
	
end
