function [ok, reason] = analysisPrerequisites(analysis, step)
%ANALYSISPREREQUISITES Check whether a pipeline step can run on an analysis.
%   [ok, reason] = analysisPrerequisites(analysis, step). The GUI uses this
%   single definition to enable/disable its buttons, and runAnalysisStep
%   uses it to refuse steps whose inputs are missing.
%
%   preprocess  needs a loaded image
%   enhance     needs preprocessing
%   segment     needs preprocessing (it works on the denoised image)
%   morphology  needs a successful segmentation
%   features    needs enhancement and a finished segmentation step
%               (morphology done, or segmentation failed -> whole-image ROI)

ok = false;
reason = '';
if isempty(analysis) || ~isstruct(analysis) || ~isfield(analysis, 'original') || isempty(analysis.original)
    reason = 'Upload an X-ray image first.';
    return;
end
d = analysis.done;
switch step
    case 'preprocess'
        ok = true;
    case {'enhance', 'segment'}
        ok = d.preprocess;
        reason = 'Run preprocessing first.';
    case 'morphology'
        ok = d.segment && strcmp(analysis.seg.status, 'ok');
        if ~d.segment
            reason = 'Run lung segmentation first.';
        else
            reason = 'Segmentation failed, so there is no mask to refine.';
        end
    case 'features'
        segFailed = d.segment && ~strcmp(analysis.seg.status, 'ok');
        ok = d.enhance && (d.morphology || segFailed);
        if ~d.enhance
            reason = 'Run image enhancement first.';
        else
            reason = 'Run segmentation and morphological processing first.';
        end
    otherwise
        error('CXR:invalidOption', 'Unknown pipeline step "%s".', step);
end
if ok
    reason = '';
end
end
