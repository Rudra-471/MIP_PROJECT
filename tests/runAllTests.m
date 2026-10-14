function results = runAllTests(varargin)
%RUNALLTESTS Run every automated test and print a summary.
%   results = runAllTests()              all tests incl. the ~1 min integration test
%   results = runAllTests('quick')       skip the end-to-end training workflow
%   results = runAllTests(..., 'nihCsv', path)  also check the real NIH CSV
%
%   Works in MATLAB (R2021a+) and in GNU Octave >= 8 with the image and
%   statistics (>= 1.7) packages. Under Octave the test-only shims in
%   tests/octave_compat provide functions the Octave image package lacks.
%
%   Test data: synthetic arrays and phantoms for software tests; the two
%   real NIH sample radiographs in tests/data/nih_samples. No result of
%   these tests is a measure of medical performance.

quick = any(strcmpi(varargin, 'quick'));
nihCsv = '';
k = find(strcmpi(varargin, 'nihCsv'), 1);
if ~isempty(k) && numel(varargin) > k
    nihCsv = varargin{k + 1};
end

testsDir = fileparts(mfilename('fullpath'));
root = fileparts(testsDir);
addpath(root);
setupProject();
addpath(testsDir);
addpath(fullfile(testsDir, 'helpers'));
if isOctaveRuntime()
    warning('off', 'all');
    pkg load image
    pkg load statistics
    addpath(fullfile(testsDir, 'octave_compat'));
end

suites = {
    'Preprocessing & enhancement', @() testPreprocessing()
    'Segmentation & morphology',    @() testSegmentation()
    'Feature extraction',           @() testFeatureExtraction()
    'Evaluation metrics',           @() testMetrics()
    'Dataset & patient-wise split', @() testDataset(nihCsv)
    'SVM, prediction & export',     @() testTraining(~quick)
    'GUI (dashboard workflows)',    @() testGui()
    };
results = struct('name', {}, 'status', {}, 'message', {});
for s = 1:size(suites, 1)
    fprintf('\n== %s ==\n', suites{s, 1});
    try
        r = suites{s, 2}();
    catch err
        r = struct('name', [suites{s, 1} ' (suite crashed)'], 'status', 'FAIL', 'message', err.message);
        fprintf('  FAIL  suite crashed: %s\n', err.message);
    end
    results = [results, r(:)']; %#ok<AGROW>
end

statuses = {results.status};
fprintf('\n%d passed, %d failed, %d skipped (%d total)\n', nnz(strcmp(statuses, 'PASS')), ...
    nnz(strcmp(statuses, 'FAIL')), nnz(strcmp(statuses, 'SKIP')), numel(results));
failed = results(strcmp(statuses, 'FAIL'));
for k = 1:numel(failed)
    fprintf('  FAILED: %s - %s\n', failed(k).name, failed(k).message);
end
end
