function stats = graycoprops(glcm, properties)
% TEST SHIM (Octave only) - MATLAB-style graycoprops.
if nargin < 2, properties = {'Contrast', 'Correlation', 'Energy', 'Homogeneity'}; end
if ischar(properties), properties = {properties}; end
numLevels = size(glcm, 1);
[J, I] = meshgrid(1:numLevels, 1:numLevels);
numGlcm = size(glcm, 3);
stats = struct();
for p = 1:numel(properties)
    stats.(properties{p}) = zeros(1, numGlcm);
end
for k = 1:numGlcm
    P = glcm(:, :, k);
    P = P / max(sum(P(:)), eps);
    muI = sum(I(:) .* P(:)); muJ = sum(J(:) .* P(:));
    sdI = sqrt(sum((I(:) - muI) .^ 2 .* P(:)));
    sdJ = sqrt(sum((J(:) - muJ) .^ 2 .* P(:)));
    for p = 1:numel(properties)
        switch lower(properties{p})
            case 'contrast',    v = sum(abs(I(:) - J(:)) .^ 2 .* P(:));
            case 'correlation'
                if sdI == 0 || sdJ == 0, v = NaN;
                else, v = sum((I(:) - muI) .* (J(:) - muJ) .* P(:)) / (sdI * sdJ); end
            case 'energy',      v = sum(P(:) .^ 2);
            case 'homogeneity', v = sum(P(:) ./ (1 + abs(I(:) - J(:))));
        end
        stats.(properties{p})(k) = v;
    end
end
end
