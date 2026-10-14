function result = runPipeline(imgOrPath, cfg)
%RUNPIPELINE Run every processing stage on one chest X-ray.
%   result = runPipeline(imgOrPath, cfg) accepts a file path or an image
%   array and returns a struct with all intermediate results:
%     original, preprocessed (struct), enhanced, segmentation (mask + info),
%     morphology (struct of stages), lungMask, overlay, features, featureNames
%
%   This single function is shared by dataset feature extraction
%   (buildFeatureDataset), prediction (predictImage) and the demo script, so
%   training and inference are guaranteed to use identical processing.
%   Fixed training settings are used: cfg.enhancementMethod and gamma = 1
%   (the GUI's gamma slider is for visual exploration only).

if nargin < 2
    cfg = getConfig();
end
if ischar(imgOrPath) || isstring(imgOrPath)
    original = readXrayImage(imgOrPath, cfg);
else
    original = imgOrPath;
end

result = struct();
result.original     = original;
result.preprocessed = preprocessImage(original, cfg);
result.enhanced     = enhanceImage(result.preprocessed.denoised, cfg.enhancementMethod, cfg);

[rawMask, segInfo]  = segmentLung(result.preprocessed.denoised, cfg);
result.segmentation = struct('mask', rawMask, 'info', segInfo);
if segInfo.isEmpty
    error('CXR:emptySegmentation', ...
        ['Lung segmentation failed: no lung-like region was found. The image ' ...
         'may not be a frontal chest X-ray, or its contrast is unusual.']);
end

result.morphology = morphologicalProcessing(rawMask, cfg);
if result.morphology.isEmpty
    error('CXR:emptySegmentation', ...
        'Lung mask became empty after morphological processing.');
end
result.lungMask = result.morphology.final;
result.overlay  = createOverlay(result.preprocessed.gray, result.lungMask);

[result.features, result.featureNames] = extractFeatures( ...
    result.preprocessed.denoised, result.enhanced, result.lungMask, cfg);
end
