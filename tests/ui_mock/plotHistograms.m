function plotHistograms(ax, varargin)
% TEST SHIM: records the call instead of drawing (Octave has no uiaxes).
% The real implementation is app/plotHistograms.m (MATLAB graphics only).
ax.LastPlot = 'plotHistograms';
ax.LastArgs = varargin;
end
