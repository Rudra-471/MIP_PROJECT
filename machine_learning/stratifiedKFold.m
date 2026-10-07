function foldId = stratifiedKFold(labels, numFolds, seed)
%STRATIFIEDKFOLD Assign each sample to one of numFolds stratified folds.
%   Samples of every class are shuffled and dealt round-robin to the folds,
%   so each fold has approximately the same class proportions.

labels = cellstr(labels);
rng(seed, 'twister');
foldId = zeros(numel(labels), 1);
classes = unique(labels);
for c = 1:numel(classes)
    idx = find(strcmp(labels, classes{c}));
    idx = idx(randperm(numel(idx)));
    foldId(idx) = mod(0:numel(idx) - 1, numFolds) + 1;
end
end
