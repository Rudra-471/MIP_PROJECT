function [tf, differences] = pipelineConfigsMatch(cfgA, cfgB)
%PIPELINECONFIGSMATCH True when two configurations produce identical features.
%   [tf, differences] = pipelineConfigsMatch(cfgA, cfgB) compares every
%   parameter that influences feature values (preprocessing, enhancement
%   incl. gamma, segmentation, morphology, features). differences lists the
%   sections that differ, e.g. {'enhance'}.

sections = {'preprocess', 'enhance', 'segment', 'morph', 'features'};
differences = {};
for k = 1:numel(sections)
    a = cfgA.(sections{k});
    b = cfgB.(sections{k});
    if strcmp(sections{k}, 'enhance')
        % display-only fields do not change features
        a = rmfield(a, intersect(fieldnames(a), {'histogramBins', 'gammaRange'}));
        b = rmfield(b, intersect(fieldnames(b), {'histogramBins', 'gammaRange'}));
    end
    if ~isequal(a, b)
        differences{end + 1} = sections{k}; %#ok<AGROW>
    end
end
tf = isempty(differences);
end
