function showImage(ax, varargin)
% TEST SHIM: records the call instead of drawing (Octave has no uiaxes).
% The real implementation is app/showImage.m (MATLAB graphics only).
ax.LastPlot = 'showImage';
ax.LastArgs = varargin;
end
