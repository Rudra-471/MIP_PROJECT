% RUNOCTAVEVALIDATION  Automated end-to-end validation with GNU Octave.
%   Run from the project root:  octave --no-gui tests/runOctaveValidation.m
%   Requires Octave >= 8 with the "image" package and "statistics" >= 1.7.0
%   (for fitcsvm). Adds the test-only shims in tests/octave_compat (see the
%   README there), then trains + evaluates the model exactly like MATLAB
%   users would with trainModel, and produces the sample figures.
if ~exist('OCTAVE_VERSION', 'builtin')
    error('This script is for GNU Octave. In MATLAB just run trainModel / demoPipeline.');
end
pkg load image
pkg load statistics
warning('off', 'all');
projectRoot = fileparts(fileparts(mfilename('fullpath')));
if isempty(projectRoot), projectRoot = pwd; end
cd(projectRoot);
setupProject();
addpath(fullfile(projectRoot, 'tests', 'octave_compat'));
graphics_toolkit('gnuplot');

trainModel();
demoPipeline();
