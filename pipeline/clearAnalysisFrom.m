function analysis = clearAnalysisFrom(analysis, step)
%CLEARANALYSISFROM Invalidate the results that depend on a pipeline step.
%   analysis = clearAnalysisFrom(analysis, step) removes the outputs of
%   'step' and of every step that depends on it:
%     preprocess -> everything below
%     enhance    -> enhanced images, enhanced histogram, overlay, features
%     segment    -> segmentation, morphology, final mask, overlay, features
%     morphology -> morphology, final mask, overlay, features
%     features   -> features
%   Segmentation uses the denoised image, so a new enhancement setting does
%   not invalidate the lung mask.

steps = {};
switch step
    case 'preprocess', steps = {'preprocess', 'enhance', 'segment', 'morphology', 'features'};
    case 'enhance',    steps = {'enhance', 'features'};
    case 'segment',    steps = {'segment', 'morphology', 'features'};
    case 'morphology', steps = {'morphology', 'features'};
    case 'features',   steps = {'features'};
    otherwise
        error('CXR:invalidOption', 'Unknown pipeline step "%s".', step);
end
if ~isfield(analysis, 'done')
    analysis.done = struct('preprocess', false, 'enhance', false, 'segment', false, ...
                           'morphology', false, 'features', false);
end
for k = 1:numel(steps)
    switch steps{k}
        case 'preprocess'
            analysis.pre = [];
            analysis.histOriginal = [];
        case 'enhance'
            analysis.enhancedBase = [];
            analysis.enhanced = [];
            analysis.enhancementMethod = '';
            analysis.gamma = NaN;
            analysis.histEnhanced = [];
            analysis.overlay = [];
        case 'segment'
            analysis.seg = [];
        case 'morphology'
            analysis.morph = [];
            analysis.refine = [];
            analysis.finalMask = [];
            analysis.overlay = [];
        case 'features'
            analysis.features = [];
            analysis.featureTable = [];
            analysis.featureDetails = [];
            analysis.roiType = '';
    end
    analysis.done.(steps{k}) = false;
end
end
