function [Z, params] = standardizeFeatures(X, params)
%STANDARDIZEFEATURES Z-score standardisation with stored parameters.
%   [Z, params] = standardizeFeatures(X) computes params.mu and params.sigma
%   from X (column-wise) and returns Z = (X - mu) ./ sigma.
%   Z = standardizeFeatures(X, params) applies previously computed
%   parameters (training statistics) to new data - this is what inference
%   must do, never re-estimate them on test data.
%   Columns with zero standard deviation are flagged in params.constant and
%   divided by 1 (they carry no information and become 0 after centring).

if nargin < 2 || isempty(params)
    params = struct();
    params.mu = mean(X, 1);
    sigma = std(X, 0, 1);
    params.constant = ~(sigma > 0);
    sigma(params.constant) = 1;
    params.sigma = sigma;
end
if size(X, 2) ~= numel(params.mu)
    error('CXR:featureDefinition', 'Expected %d features but got %d.', numel(params.mu), size(X, 2));
end
n = size(X, 1);
Z = (X - repmat(params.mu, n, 1)) ./ repmat(params.sigma, n, 1);
end
