function opts = AMPSCZ_EEG_topoOptions( cmap, climits )
% default options for AMP SCZ topography plots using 
% EEGLAB's topoplot function.
%
% usage:
% >> opts = AMPSCZ_EEG_topoOptions( [cmap], [climits] );
%
% where optional inputs
% cmap = #x3 RGB color map in range [0,1]
% climits = data limits for ends of colormap [ min, max ]
%
% output is a 1x(#*2) cell array of name value pairs
%
% e.g.
% >> topoOpts = AMPSCZ_EEG_topoOptions;
% >> topoplot( data, chanlocs, topoOpts{:} );

	narginchk( 0, 2 )

	opts = {...
		'nosedir', '+X',...
		'style', 'map',...
		'shading', 'flat',...
		'conv', 'on',...
		'headrad', 0.5,...
		'electrodes', 'on',...
		'emarker', { '.', 'k', 8, 0.5 },...
		'hcolor', repmat( 0.333, 1, 3 ),...
		'gridscale', 200,...
		'circgrid', 360,...
		'whitebk', 'on' };

	if exist( 'cmap', 'var' ) == 1 && ~isempty( cmap )
		opts = [ opts, { 'colormap', cmap } ];
	end
	if exist( 'climits', 'var' ) == 1 && ~isempty( climits )
		opts = [ opts, { 'maplimits', climits } ];
	end

	return

end

