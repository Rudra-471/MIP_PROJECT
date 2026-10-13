function analysis = createAnalysis(source, cfg)
%CREATEANALYSIS Start a single-image analysis: read + validate the image.
%   analysis = createAnalysis(filePathOrArray, cfg) returns the analysis
%   struct used by runAnalysisStep. Only the acquisition step is done here;
%   every later step is executed explicitly with runAnalysisStep.
%
%   Fields
%     fileName, imageInfo, original      acquisition (validateImage)
%     pre                                preprocessImage output
%     enhancedBase                       image after the enhancement method
%     enhanced                           enhancedBase after gamma correction
%     enhancementMethod, gamma           settings used for 'enhanced'
%     histOriginal, histEnhanced         computeHistogramData outputs
%     seg                                segmentLungs output
%     morph                              morphologicalProcessing output
%     refine, finalMask                  refineLungMask outputs
%     overlay                            enhanced image + lung outline (RGB)
%     roiType                            'lung' | 'wholeImage' | ''
%     features, featureTable, featureDetails
%     done                               struct of logical flags per step
%     cfg                                configuration of the last step run

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
[original, info] = validateImage(source, cfg);

analysis = struct();
analysis.fileName  = info.fileName;
analysis.imageInfo = info;
analysis.original  = original;
analysis.cfg       = cfg;
analysis = clearAnalysisFrom(analysis, 'preprocess');
end
