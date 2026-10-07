function demoPipeline(imagePaths, outputDir, model)
%DEMOPIPELINE Run the whole pipeline on X-ray(s) and save explanatory figures.
%   demoPipeline() picks one Normal and one Abnormal image from the held-out
%   TEST set (results/test_predictions.csv, written by trainModel) so the
%   shown predictions are on images the model never saw during training.
%   demoPipeline({'a.png','b.jpg'}) processes the given files instead.
%   demoPipeline(paths, outputDir, model) uses an in-memory model (e.g. the
%   one returned by trainModel) instead of loading models/trainedModel.mat.
%
%   For every image, <outputDir>/<name>_*.png figures are written:
%     _pipeline.png    original, grayscale, denoised, enhanced, gamma, masks, overlay
%     _histograms.png  histogram before/after enhancement + method comparison
%     _morphology.png  every morphological stage of the lung mask
%   and <name>_report.txt with the feature values and the model prediction.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(projectRoot, 'results', 'sample_output');
end
if nargin < 1 || isempty(imagePaths)
    imagePaths = defaultDemoImages(projectRoot);
end
if ischar(imagePaths)
    imagePaths = {imagePaths};
end
if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

cfg = getConfig();
if nargin < 3 || isempty(model)
    try
        model = loadTrainedModel();
    catch modelError
        model = [];
        fprintf('%s\nFigures will be produced without a prediction.\n', modelError.message);
    end
end
if ~isempty(model)
    cfg = model.cfg;
end

for k = 1:numel(imagePaths)
    [~, name] = fileparts(imagePaths{k});
    fprintf('Processing %s\n', imagePaths{k});
    result = runPipeline(imagePaths{k}, cfg);
    if isempty(model)
        predictionText = 'No trained model - prediction not available';
        prediction = [];
    else
        prediction = classifyFeatures(result.features, model);
        predictionText = sprintf('Model prediction: %s (P(Abnormal) = %.1f%%)', ...
            upper(prediction.label{1}), 100 * prediction.probAbnormal);
    end
    base = fullfile(outputDir, name);
    savePipelineFigure(result, cfg, predictionText, [base '_pipeline.png']);
    saveHistogramFigure(result, cfg, [base '_histograms.png']);
    saveMorphologyFigure(result.morphology, [base '_morphology.png']);
    writeReport(result, prediction, imagePaths{k}, [base '_report.txt']);
end
fprintf('Sample outputs written to %s\n', outputDir);
end

% =========================================================================
function paths = defaultDemoImages(projectRoot)
datasetDir = fullfile(projectRoot, 'dataset');
predictionsFile = fullfile(projectRoot, 'results', 'test_predictions.csv');
paths = {};
classes = {'Normal', 'Abnormal'};
if exist(predictionsFile, 'file') == 2
    fid = fopen(predictionsFile, 'r');
    cols = textscan(fid, '%s %s %s %f %f %d', 'Delimiter', ',', 'HeaderLines', 1);
    fclose(fid);
    for c = 1:numel(classes)
        idx = find(strcmp(cols{2}, classes{c}), 1);
        if ~isempty(idx)
            paths{end+1} = fullfile(datasetDir, cols{1}{idx}); %#ok<AGROW>
        end
    end
end
if isempty(paths)
    for c = 1:numel(classes)
        files = dir(fullfile(datasetDir, classes{c}, '*.*'));
        files = files(~[files.isdir] & ~strncmp({files.name}, '.', 1));
        if ~isempty(files)
            paths{end+1} = fullfile(datasetDir, classes{c}, files(1).name); %#ok<AGROW>
        end
    end
end
if isempty(paths)
    error('CXR:missingDataset', 'No demo images found. Pass image paths or prepare the dataset.');
end
end

function savePipelineFigure(result, cfg, predictionText, fileName)
gammaExample = 0.7;
panels = { ...
    result.original,                        'Original X-ray'; ...
    result.preprocessed.gray,               'Grayscale (resized)'; ...
    result.preprocessed.denoised,           'Normalised + median filter'; ...
    result.enhanced,                        sprintf('Enhanced (%s)', upper(cfg.enhancementMethod)); ...
    gammaCorrection(result.enhanced, gammaExample, cfg), sprintf('Gamma correction (\\gamma = %.1f)', gammaExample); ...
    result.segmentation.mask,               'Lung segmentation (threshold)'; ...
    result.lungMask,                        'After morphology'; ...
    result.overlay,                         'Final overlay'};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 760]);
for p = 1:size(panels, 1)
    ax = subplot(2, 4, p, 'Parent', fig);
    imshow(panels{p, 1}, 'Parent', ax);
    title(ax, panels{p, 2});
end
annotation(fig, 'textbox', [0 0.0 1 0.05], 'String', ...
    [predictionText '   |   Educational/research use only - not a medical diagnosis'], ...
    'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontSize', 11);
print(fig, fileName, '-dpng', '-r90');
close(fig);
end

function saveHistogramFigure(result, cfg, fileName)
comparison = compareEnhancement(result.preprocessed.denoised, cfg);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 700]);
for k = 1:numel(comparison)
    ax = subplot(2, 4, k, 'Parent', fig);
    imshow(comparison(k).image, 'Parent', ax);
    title(ax, sprintf('%s\nstd %.3f | entropy %.2f | edge %.4f', comparison(k).name, ...
        comparison(k).stdDev, comparison(k).entropy, comparison(k).edgeStrength));
    ax = subplot(2, 4, 4 + k, 'Parent', fig);
    [counts, bins] = imhist(comparison(k).image, 64);
    bar(ax, bins, counts, 1, 'FaceColor', [0.2 0.4 0.7], 'EdgeColor', 'none');
    xlim(ax, [0 1]);
    title(ax, ['Histogram: ' comparison(k).name]);
    xlabel(ax, 'Intensity');
    ylabel(ax, 'Pixel count');
end
print(fig, fileName, '-dpng', '-r90');
close(fig);
end

function saveMorphologyFigure(morph, fileName)
stages = {'input', 'Mask before morphology'; 'opened', 'Opening'; ...
          'cleaned', 'Small objects removed'; 'closed', 'Closing'; ...
          'filled', 'Hole filling'; 'eroded', 'Erosion'; ...
          'dilated', 'Dilation'; 'final', 'Final lung mask'};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 760]);
for p = 1:size(stages, 1)
    ax = subplot(2, 4, p, 'Parent', fig);
    imshow(morph.(stages{p, 1}), 'Parent', ax);
    title(ax, sprintf('%s (%d px)', stages{p, 2}, nnz(morph.(stages{p, 1}))));
end
print(fig, fileName, '-dpng', '-r90');
close(fig);
end

function writeReport(result, prediction, imagePath, fileName)
fid = fopen(fileName, 'w');
[~, name, ext] = fileparts(imagePath);
fprintf(fid, 'Image: %s%s\n', name, ext);
fprintf(fid, 'Segmentation: %d region(s), lung area %.1f%% of image, adaptive sensitivity %.2f\n\n', ...
    result.segmentation.info.numRegions, 100 * nnz(result.lungMask) / numel(result.lungMask), ...
    result.segmentation.info.sensitivity);
fprintf(fid, 'Features\n');
for k = 1:numel(result.featureNames)
    fprintf(fid, '  %-14s %10.4f\n', result.featureNames{k}, result.features(k));
end
if isempty(prediction)
    fprintf(fid, '\nNo trained model available - the model still needs to be trained.\n');
else
    fprintf(fid, '\nModel prediction : Predicted %s\n', prediction.label{1});
    fprintf(fid, 'P(Abnormal)      : %.1f%% (Platt-calibrated SVM score)\n', 100 * prediction.probAbnormal);
    fprintf(fid, 'SVM score        : %.3f\n', prediction.svmScore);
end
fprintf(fid, ['\nThis system is intended for educational and research purposes only and does ' ...
    'not provide a medical diagnosis. Results should not be used for clinical decision-making.\n']);
fclose(fid);
end
