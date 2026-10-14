function validateModel(model)
%VALIDATEMODEL Throw CXR:invalidModel unless model is a complete trained model.
required = {'classifier', 'featureNames', 'standardization', 'classNames', ...
            'positiveClass', 'pipelineConfig', 'kernel'};
if isempty(model) || ~isstruct(model)
    error('CXR:missingModel', 'No trained model is loaded. Train a model on the Dataset & Training page first.');
end
missing = required(~isfield(model, required));
if ~isempty(missing)
    error('CXR:invalidModel', 'The model is incomplete (missing: %s). Re-train it.', strjoin(missing, ', '));
end
expected = appConfig();
if ~isequal(model.featureNames, model.pipelineConfig.features.names)
    error('CXR:invalidModel', 'The model''s feature list does not match its pipeline configuration.');
end
if ~isequal(model.featureNames, expected.features.names)
    error('CXR:invalidModel', ['The model was trained with a different feature definition ' ...
        '(%s). Re-train it with the current version of the project.'], strjoin(model.featureNames, ', '));
end
end
