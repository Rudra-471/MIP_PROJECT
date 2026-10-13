function plotConfusion(ax, varargin)
% TEST SHIM: records the call instead of drawing (Octave has no uiaxes).
% The real implementation is app/plotConfusion.m (MATLAB graphics only).
ax.LastPlot = 'plotConfusion';
ax.LastArgs = varargin;
end
