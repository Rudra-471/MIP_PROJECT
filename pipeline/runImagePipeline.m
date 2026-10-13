function analysis = runImagePipeline(source, cfg)
%RUNIMAGEPIPELINE Run every processing stage on one chest X-ray.
%   analysis = runImagePipeline(filePathOrArray, cfg)
%     acquisition -> preprocessing -> enhancement + gamma -> lung segmentation
%     -> morphological processing -> lung-ROI feature extraction
%   Throws CXR:segmentationFailed when no plausible lung region is found
%   (lung-ROI features are then not defined). Used for dataset feature
%   extraction and for prediction; the GUI runs the same steps one by one.

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
analysis = createAnalysis(source, cfg);
analysis = runAnalysisStep(analysis, 'preprocess', cfg);
analysis = runAnalysisStep(analysis, 'enhance', cfg);
analysis = runAnalysisStep(analysis, 'segment', cfg);
if ~strcmp(analysis.seg.status, 'ok')
    error('CXR:segmentationFailed', 'Lung segmentation failed: %s', analysis.seg.message);
end
analysis = runAnalysisStep(analysis, 'morphology', cfg);
analysis = runAnalysisStep(analysis, 'features', cfg, false);
end
