function isTest = stratifiedSplit(labels, testFraction, seed)
%STRATIFIEDSPLIT Reproducible stratified hold-out split.
%   isTest = stratifiedSplit(labels, testFraction, seed) returns a logical
%   vector marking test samples. Each class contributes the same fraction
%   of its samples to the test set, so both classes are fairly represented.

labels = cellstr(labels);
rng(seed, 'twister');
isTest = false(numel(labels), 1);
classes = unique(labels);
for c = 1:numel(classes)
    idx = find(strcmp(labels, classes{c}));
    numTest = round(testFraction * numel(idx));
    idx = idx(randperm(numel(idx)));
    isTest(idx(1:numTest)) = true;
end
end
