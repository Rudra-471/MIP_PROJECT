function [X, ok, failures, cancelled] = buildFeatureMatrix(paths, names, cfg, progressFcn, cacheFile)
%BUILDFEATUREMATRIX Run the image pipeline on many images and collect features.
%   [X, ok, failures, cancelled] = buildFeatureMatrix(paths, names, cfg, progressFcn, cacheFile)
%     paths, names - cellstr full paths and file names (names are cache keys)
%     cfg          - pipeline configuration (stored later in the model)
%     progressFcn  - optional @(k, n, name) -> true to request cancellation
%     cacheFile    - optional .mat file; features already computed with an
%                    identical pipeline configuration are re-used
%   X         - N x F features (rows of failed images are NaN)
%   ok        - N x 1 logical, true where features were extracted
%   failures  - struct array: name, identifier, message (images skipped
%               because of read errors, failed segmentation, ...)
%   cancelled - true when the user cancelled; X/ok cover processed rows only
%
%   Every image goes through runImagePipeline - the exact function used for
%   single-image prediction - so training and inference features match.

if nargin < 4
    progressFcn = [];
end
if nargin < 5
    cacheFile = '';
end
n = numel(paths);
numFeatures = numel(cfg.features.names);
X = nan(n, numFeatures);
ok = false(n, 1);
failures = struct('name', {}, 'identifier', {}, 'message', {});
cancelled = false;

cache = loadCache(cacheFile, cfg);
if ~isempty(cache.names)
    [hit, loc] = ismember(names(:), cache.names);
    X(hit, :) = cache.X(loc(hit), :);
    ok(hit) = true;
end

numNew = 0;
for k = 1:n
    if ~isempty(progressFcn)
        if progressFcn(k, n, names{k})
            cancelled = true;
            break;
        end
    end
    if ok(k)
        continue;
    end
    try
        analysis = runImagePipeline(paths{k}, cfg);
        X(k, :) = analysis.features;
        ok(k) = true;
        numNew = numNew + 1;
    catch err
        failures(end + 1) = struct('name', names{k}, 'identifier', err.identifier, ...
                                   'message', err.message); %#ok<AGROW>
        logMessage('WARN', 'Feature extraction skipped %s: %s', names{k}, err.message);
    end
end

if numNew > 0 && ~isempty(cacheFile)
    saveCache(cacheFile, cfg, cache, names(ok), X(ok, :));
end
end

% =========================================================================
function cache = loadCache(cacheFile, cfg)
cache = struct('names', {{}}, 'X', zeros(0, numel(cfg.features.names)));
if isempty(cacheFile) || exist(cacheFile, 'file') ~= 2
    return;
end
try
    loaded = load(cacheFile);
    if isfield(loaded, 'pipelineConfig') && pipelineConfigsMatch(loaded.pipelineConfig, cfg) && ...
            isfield(loaded, 'runtime') && strcmp(loaded.runtime, runtimeName())
        cache.names = loaded.names;
        cache.X = loaded.X;
    end
catch err
    logMessage('WARN', 'Ignoring unreadable feature cache %s: %s', cacheFile, err.message);
end
end

function saveCache(cacheFile, cfg, cache, newNames, newX)
[names, idx] = unique([cache.names(:); newNames(:)], 'last');
allX = [cache.X; newX];
X = allX(idx, :); %#ok<NASGU>
pipelineConfig = cfg; %#ok<NASGU>
runtime = runtimeName(); %#ok<NASGU>
folder = fileparts(cacheFile);
if ~isempty(folder) && exist(folder, 'dir') ~= 7
    mkdir(folder);
end
try
    save(cacheFile, 'names', 'X', 'pipelineConfig', 'runtime', '-v7');
catch err
    logMessage('WARN', 'Could not write feature cache %s: %s', cacheFile, err.message);
end
end

function name = runtimeName()
% Features computed under Octave (test runtime) are never re-used by MATLAB
if isOctaveRuntime()
    name = 'Octave';
else
    name = 'MATLAB';
end
end
