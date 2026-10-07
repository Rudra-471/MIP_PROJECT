function [A, B] = fitPlattScaling(scores, isPositive)
%FITPLATTSCALING Fit P(positive | s) = 1 / (1 + exp(A*s + B)) to SVM scores.
%   Platt scaling converts raw SVM decision scores into probabilities. It
%   must be fitted on scores the SVM did NOT see during training; trainModel
%   uses out-of-fold cross-validation scores from the training set.
%   Implementation: Newton's method with backtracking from Lin, Lin & Weng,
%   "A note on Platt's probabilistic outputs for support vector machines" (2007),
%   including Platt's smoothed targets to avoid over-confident estimates.

scores = scores(:);
isPositive = logical(isPositive(:));
numPos = nnz(isPositive);
numNeg = numel(isPositive) - numPos;
target = zeros(size(scores));
target(isPositive)  = (numPos + 1) / (numPos + 2);
target(~isPositive) = 1 / (numNeg + 2);

A = 0;
B = log((numNeg + 1) / (numPos + 1));
sigma = 1e-12;
fval = objective(A, B);
for iter = 1:100
    [p, q] = probs(A, B);
    d2 = p .* q;
    h11 = sigma + sum(scores .^ 2 .* d2);
    h22 = sigma + sum(d2);
    h21 = sum(scores .* d2);
    d1 = target - p;
    g1 = sum(scores .* d1);
    g2 = sum(d1);
    if abs(g1) < 1e-5 && abs(g2) < 1e-5
        break;
    end
    detH = h11 * h22 - h21 ^ 2;
    dA = -(h22 * g1 - h21 * g2) / detH;
    dB = -(-h21 * g1 + h11 * g2) / detH;
    gd = g1 * dA + g2 * dB;
    step = 1;
    while step >= 1e-10
        newF = objective(A + step * dA, B + step * dB);
        if newF < fval + 1e-4 * step * gd
            A = A + step * dA;
            B = B + step * dB;
            fval = newF;
            break;
        end
        step = step / 2;
    end
    if step < 1e-10
        break;
    end
end

    function [p, q] = probs(a, b)
        % p = P(positive), q = 1 - p, computed stably
        f = scores * a + b;
        p = zeros(size(f));
        q = zeros(size(f));
        pos = f >= 0;
        p(pos)  = exp(-f(pos)) ./ (1 + exp(-f(pos)));
        q(pos)  = 1 ./ (1 + exp(-f(pos)));
        p(~pos) = 1 ./ (1 + exp(f(~pos)));
        q(~pos) = exp(f(~pos)) ./ (1 + exp(f(~pos)));
    end

    function val = objective(a, b)
        % Negative log-likelihood, numerically stable form
        f = scores * a + b;
        val = sum((target - 1) .* f + max(f, 0) + log1p(exp(-abs(f))));
    end
end
