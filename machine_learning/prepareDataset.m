function dataset = prepareDataset(meta, index, cfg, officialSplit)
%PREPAREDATASET Select a reproducible, patient-wise split subset of the NIH data.
%   dataset = prepareDataset(meta, index, cfg, officialSplit)
%     meta          - loadDatasetMetadata output
%     index         - indexDatasetImages output (images actually on disk)
%     cfg           - appConfig (cfg.dataset.* controls the subset)
%     officialSplit - optional struct with cellstr fields trainVal and test
%                     (file names from the official NIH train_val_list.txt /
%                     test_list.txt, see loadOfficialSplit). Empty -> a
%                     reproducible random patient-wise split is made.
%
%   Steps
%     1. Eligible images: valid binary label, file present on disk, allowed
%        view position (default PA only), listed in the official split
%        lists when those are used.
%     2. Patient-wise split (splitByPatient): every patient belongs to
%        exactly one of train / validation / test.
%     3. Sampling inside each split: requested total cfg.dataset.subsetSize,
%        test share cfg.dataset.testFraction, validation share
%        cfg.dataset.validationFraction of the rest, equal Normal/Abnormal
%        counts when cfg.dataset.balanceClasses is true, and at most
%        cfg.dataset.maxImagesPerPatient images per patient. The draw uses
%        cfg.dataset.randomSeed, so it is reproducible.
%     4. Shortfalls are reported - the requested size is never assumed.
%
%   dataset fields (one element per selected image)
%     imageName, fullPath, label, findingLabels, viewPosition, split (cellstr),
%     patientId (double)
%   dataset.report: requested/achieved counts (rows train/validation/test,
%     columns Normal/Abnormal), patients per split, patientOverlap,
%     splitSource, eligibility counts and human-readable messages.

if nargin < 3 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 4
    officialSplit = [];
end
d = cfg.dataset;
classNames = cfg.svm.classNames;           % {'Normal','Abnormal'}
splitNames = {'train', 'validation', 'test'};
messages = {};

% ---- 1. Eligibility ---------------------------------------------------------
[onDisk, loc] = ismember(meta.imageIndex, index.fileNames);
viewOk = true(size(meta.imageIndex));
if ~isempty(d.viewPositions)
    viewOk = ismember(upper(meta.viewPosition), upper(d.viewPositions));
end
eligible = meta.isValid & onDisk & viewOk;
numValidOnDisk = nnz(meta.isValid & onDisk);
messages{end + 1} = sprintf('%d of %d labelled images were found on disk.', ...
    numValidOnDisk, nnz(meta.isValid));
if ~isempty(d.viewPositions)
    messages{end + 1} = sprintf('%d image(s) excluded by view position (allowed: %s).', ...
        nnz(meta.isValid & onDisk & ~viewOk), strjoin(d.viewPositions, ', '));
end

fixedTest = [];
splitSource = 'reproducible random patient-wise split';
if ~isempty(officialSplit)
    inTest = ismember(meta.imageIndex, officialSplit.test);
    inTrainVal = ismember(meta.imageIndex, officialSplit.trainVal);
    notListed = eligible & ~inTest & ~inTrainVal;
    if any(notListed)
        messages{end + 1} = sprintf(['%d eligible image(s) are in neither official split ' ...
            'list and were excluded.'], nnz(notListed));
    end
    eligible = eligible & (inTest | inTrainVal);
    fixedTest = inTest(eligible);
    splitSource = 'official NIH patient-wise lists (test_list.txt / train_val_list.txt)';
end
eligibleIdx = find(eligible);
if isempty(eligibleIdx)
    error('CXR:insufficientData', ['No eligible images: none of the labelled images in the ' ...
        'metadata were found in the dataset folder (with the selected view positions).']);
end

% ---- 2. Patient-wise split of all eligible images ----------------------------
[eligibleSplit, splitReport] = splitByPatient(meta.patientId(eligibleIdx), ...
    [d.validationFraction d.testFraction], d.randomSeed, fixedTest);
if splitReport.movedToTestPatients > 0
    messages{end + 1} = sprintf(['%d patient(s) had images in both official lists; all their ' ...
        'images were assigned to the test set.'], splitReport.movedToTestPatients);
end

% ---- 3. Sampling targets -----------------------------------------------------
total = d.subsetSize;
nTest = round(total * d.testFraction);
nVal = round((total - nTest) * d.validationFraction);
nTrain = total - nTest - nVal;
splitTargets = [nTrain nVal nTest];
requested = zeros(3, 2);
for s = 1:3
    if d.balanceClasses
        requested(s, :) = [floor(splitTargets(s) / 2), ceil(splitTargets(s) / 2)];
    else
        requested(s, :) = NaN;     % no per-class target
    end
end

labels = meta.binaryLabel(eligibleIdx);
patients = meta.patientId(eligibleIdx);
[~, ~, patientIdx] = unique(patients);
imagesPerPatient = zeros(max([patientIdx; 0]), 1);
order = seededPermutation(numel(eligibleIdx), d.randomSeed + 1);
selected = false(numel(eligibleIdx), 1);
achieved = zeros(3, 2);
available = zeros(3, 2);

for s = 1:3
    inSplit = strcmp(eligibleSplit(order), splitNames{s});
    if d.balanceClasses
        % Abnormal first: it is usually the class with fewer patients per view
        for c = [2 1]
            candidates = order(inSplit & strcmp(labels(order), classNames{c}));
            available(s, c) = numel(candidates);
            [selected, imagesPerPatient, count] = take(candidates, requested(s, c), ...
                selected, imagesPerPatient, patientIdx, d.maxImagesPerPatient);
            achieved(s, c) = count;
        end
    else
        candidates = order(inSplit);
        [selected, imagesPerPatient] = take(candidates, splitTargets(s), ...
            selected, imagesPerPatient, patientIdx, d.maxImagesPerPatient);
        for c = 1:2
            available(s, c) = nnz(inSplit & strcmp(labels(order), classNames{c}));
            achieved(s, c) = nnz(selected & strcmp(eligibleSplit, splitNames{s}) & ...
                                 strcmp(labels, classNames{c}));
        end
    end
end

% ---- 4. Report shortfalls ----------------------------------------------------
for s = 1:3
    for c = 1:2
        if d.balanceClasses && achieved(s, c) < requested(s, c)
            messages{end + 1} = sprintf(['Requested %d %s images for the %s set, but only %d ' ...
                'could be selected (%d eligible, max %g per patient).'], requested(s, c), ...
                classNames{c}, splitNames{s}, achieved(s, c), available(s, c), d.maxImagesPerPatient); %#ok<AGROW>
        end
    end
end
if sum(achieved(:)) < total
    messages{end + 1} = sprintf('Requested %d images in total; %d were selected.', ...
        total, sum(achieved(:)));
else
    messages{end + 1} = sprintf('Selected %d images as requested.', sum(achieved(:)));
end

% ---- Output ------------------------------------------------------------------
pick = eligibleIdx(selected);
dataset = struct();
dataset.imageName     = meta.imageIndex(pick);
dataset.fullPath      = index.fullPaths(loc(pick));
dataset.label         = meta.binaryLabel(pick);
dataset.findingLabels = meta.findingLabels(pick);
dataset.viewPosition  = meta.viewPosition(pick);
dataset.patientId     = meta.patientId(pick);
dataset.split         = eligibleSplit(selected);

report = struct();
report.splitSource    = splitSource;
report.splitNames     = splitNames;
report.classNames     = classNames;
report.requested      = requested;
report.achieved       = achieved;
report.available      = available;
report.numEligible    = numel(eligibleIdx);
report.numSelected    = numel(pick);
report.patientsPerSplit = zeros(1, 3);
for s = 1:3
    report.patientsPerSplit(s) = numel(unique(dataset.patientId(strcmp(dataset.split, splitNames{s}))));
end
report.patientOverlap = countPatientOverlap(dataset.patientId, dataset.split);
report.messages       = messages(:);
dataset.report = report;

if report.patientOverlap ~= 0
    error('CXR:splitIntegrity', 'Patient-wise split integrity check failed (%d overlapping patients).', ...
        report.patientOverlap);
end
end

% =========================================================================
function [selected, perPatient, count] = take(candidates, target, selected, perPatient, patientIdx, maxPer)
count = 0;
for k = 1:numel(candidates)
    if count >= target
        break;
    end
    i = candidates(k);
    p = patientIdx(i);
    if ~selected(i) && perPatient(p) < maxPer
        selected(i) = true;
        perPatient(p) = perPatient(p) + 1;
        count = count + 1;
    end
end
end

function overlap = countPatientOverlap(patientId, split)
names = {'train', 'validation', 'test'};
sets = cell(1, 3);
for k = 1:3
    sets{k} = unique(patientId(strcmp(split, names{k})));
end
overlap = numel(intersect(sets{1}, sets{2})) + numel(intersect(sets{1}, sets{3})) + ...
          numel(intersect(sets{2}, sets{3}));
end
