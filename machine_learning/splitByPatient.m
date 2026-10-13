function [split, report] = splitByPatient(patientId, fractions, seed, fixedTest)
%SPLITBYPATIENT Reproducible patient-wise train / validation / test assignment.
%   [split, report] = splitByPatient(patientId, fractions, seed, fixedTest)
%     patientId - N x 1 numeric patient IDs (one per image)
%     fractions - [validationFraction testFraction] of the PATIENTS
%     seed      - random seed (same seed -> same split)
%     fixedTest - optional N x 1 logical: images already assigned to the
%                 test set (e.g. the official NIH test_list.txt). When
%                 given, test patients are taken from it and only the
%                 remaining patients are split into train / validation
%                 (fractions(2) is then ignored).
%   split  - N x 1 cellstr: 'train' | 'validation' | 'test'
%   report - numPatients per split and patientOverlap (must be 0)
%
%   Every patient is assigned as a whole, so all images of one patient end
%   up in the same subset: no patient can appear in both training and test.
%   If fixedTest marks some but not all images of a patient as test, the
%   whole patient is moved to the test set and this is reported.

patientId = patientId(:);
n = numel(patientId);
if nargin < 4 || isempty(fixedTest)
    fixedTest = [];
end
if any(~isfinite(patientId))
    error('CXR:invalidMetadata', 'Patient IDs must be finite numbers for a patient-wise split.');
end
valFraction = fractions(1);
testFraction = fractions(2);
if valFraction < 0 || testFraction < 0 || valFraction + testFraction >= 1
    error('CXR:invalidOption', 'Validation and test fractions must be >= 0 and sum to less than 1.');
end

[patients, ~, pIdx] = unique(patientId);
numPatients = numel(patients);
group = zeros(numPatients, 1);    % 1 = train, 2 = validation, 3 = test
movedPatients = 0;

if isempty(fixedTest)
    order = seededPermutation(numPatients, seed);
    numTest = round(testFraction * numPatients);
    numVal  = round(valFraction * numPatients);
    group(order(1:numTest)) = 3;
    group(order(numTest + 1:numTest + numVal)) = 2;
    group(group == 0) = 1;
else
    fixedTest = logical(fixedTest(:));
    testPatientAny = accumarray(pIdx, double(fixedTest), [numPatients 1]) > 0;
    testPatientAll = accumarray(pIdx, double(fixedTest), [numPatients 1]) == ...
                     accumarray(pIdx, 1, [numPatients 1]);
    movedPatients = nnz(testPatientAny & ~testPatientAll);
    group(testPatientAny) = 3;
    remaining = find(~testPatientAny);
    order = remaining(seededPermutation(numel(remaining), seed));
    numVal = round(valFraction * numel(remaining));
    group(order(1:numVal)) = 2;
    group(group == 0) = 1;
end

names = {'train', 'validation', 'test'};
split = names(group(pIdx)).';
split = split(:);

report = struct();
report.numPatients = [nnz(group == 1), nnz(group == 2), nnz(group == 3)];
report.numImages = [nnz(strcmp(split, 'train')), nnz(strcmp(split, 'validation')), ...
                    nnz(strcmp(split, 'test'))];
report.patientOverlap = countOverlap(patientId, split);
report.movedToTestPatients = movedPatients;
report.usedFixedTest = ~isempty(fixedTest);
if n == 0
    report.patientOverlap = 0;
end
end

function overlap = countOverlap(patientId, split)
% Number of patients that appear in more than one subset (0 by construction)
names = {'train', 'validation', 'test'};
sets = cell(1, 3);
for k = 1:3
    sets{k} = unique(patientId(strcmp(split, names{k})));
end
overlap = numel(intersect(sets{1}, sets{2})) + numel(intersect(sets{1}, sets{3})) + ...
          numel(intersect(sets{2}, sets{3}));
end
