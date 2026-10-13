function showEmptyState(ax, varargin)
% TEST SHIM: records the call instead of drawing (Octave has no uiaxes).
% The real implementation is app/showEmptyState.m (MATLAB graphics only).
ax.LastPlot = 'showEmptyState';
ax.LastArgs = varargin;
end
