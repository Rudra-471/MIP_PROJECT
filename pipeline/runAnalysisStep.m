function analysis = runAnalysisStep(analysis, step, cfg, allowWholeImageROI)
%RUNANALYSISSTEP Execute one stage of the single-image pipeline.
%   analysis = runAnalysisStep(analysis, step, cfg) with step one of
%     'preprocess' | 'enhance' | 'segment' | 'morphology' | 'features'
%   cfg carries every parameter, including the enhancement method
%   (cfg.enhance.method) and gamma (cfg.enhance.gamma).
%
%   allowWholeImageROI (default false): when segmentation failed, the
%   'features' step normally throws CXR:segmentationFailed. With true it
%   computes the features on the whole image and sets roiType =
%   'wholeImage'. The GUI uses this for exploration only; such features are
%   never used for classification because the model was trained on
%   lung-ROI features.
%
%   The same function is used by the GUI buttons, by "Run Full Analysis",
%   by dataset feature extraction during training, and by prediction, so
%   all of them process images identically.

if nargin < 3 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 4
    allowWholeImageROI = false;
end
[ok, reason] = analysisPrerequisites(analysis, step);
if ~ok
    error('CXR:stepOrder', 'Cannot run "%s": %s', step, reason);
end
analysis = clearAnalysisFrom(analysis, step);
analysis.cfg = cfg;

switch step
    case 'preprocess'
        analysis.pre = preprocessImage(analysis.original, cfg);
        analysis.histOriginal = computeHistogramData(analysis.pre.resized, cfg.enhance.histogramBins);

    case 'enhance'
        base = enhanceImage(analysis.pre.denoised, cfg.enhance.method, cfg);
        analysis.enhancedBase = base;
        analysis.enhanced = applyGammaCorrection(base, cfg.enhance.gamma, cfg);
        analysis.enhancementMethod = cfg.enhance.method;
        analysis.gamma = cfg.enhance.gamma;
        analysis.histEnhanced = computeHistogramData(analysis.enhanced, cfg.enhance.histogramBins);
        analysis = updateOverlay(analysis);

    case 'segment'
        analysis.seg = segmentLungs(analysis.pre.denoised, cfg);

    case 'morphology'
        analysis.morph = morphologicalProcessing(analysis.seg.initialMask, cfg);
        [analysis.finalMask, analysis.refine] = refineLungMask(analysis.morph.output, cfg);
        analysis = updateOverlay(analysis);

    case 'features'
        hasLungMask = analysis.done.morphology && ~strcmp(analysis.refine.status, 'failed');
        if hasLungMask
            roi = analysis.finalMask;
            analysis.roiType = 'lung';
        elseif allowWholeImageROI
            roi = [];
            analysis.roiType = 'wholeImage';
        else
            error('CXR:segmentationFailed', ['Lung segmentation failed for this image, so ' ...
                'lung-region features cannot be computed. %s'], segmentationMessage(analysis));
        end
        [analysis.features, analysis.featureTable, analysis.featureDetails] = ...
            extractFeatures(analysis.enhanced, roi, cfg);
end
analysis.done.(step) = true;
end

function analysis = updateOverlay(analysis)
% The final processed image = enhanced image + approximate lung outline.
% It needs both inputs; whichever step finishes second creates it.
if ~isempty(analysis.enhanced) && ~isempty(analysis.finalMask) && any(analysis.finalMask(:))
    analysis.overlay = createMaskOverlay(analysis.enhanced, analysis.finalMask);
else
    analysis.overlay = [];
end
end

function msg = segmentationMessage(analysis)
msg = '';
if isfield(analysis, 'refine') && isstruct(analysis.refine) && ~isempty(analysis.refine.message)
    msg = analysis.refine.message;
elseif isfield(analysis, 'seg') && isstruct(analysis.seg)
    msg = analysis.seg.message;
end
end
