function results = testDataset(nihCsvPath)
%TESTDATASET Tests for metadata parsing, labels, image indexing and
%patient-wise splitting.
%   results = testDataset(nihCsvPath) additionally checks the real NIH
%   Data_Entry_2017_v2020.csv when its path is given (or set in the
%   environment variable CXR_NIH_CSV). Metadata fixtures written by this
%   test are synthetic CSV text used only to test the parser.

if nargin < 1 || isempty(nihCsvPath)
    nihCsvPath = getenv('CXR_NIH_CSV');
end
cfg = appConfig();
results = struct('name', {}, 'status', {}, 'message', {});
tmp = tempname();
mkdir(tmp);
cleaner = onCleanup(@() rmdirQuiet(tmp));

results(end+1) = runCase('missing dataset folder', ...
    @() expectError(@() indexDatasetImages(fullfile(tmp, 'missing'), cfg), 'CXR:missingDataset'));
results(end+1) = runCase('missing metadata CSV', ...
    @() expectError(@() loadDatasetMetadata(fullfile(tmp, 'none.csv'), cfg), 'CXR:missingMetadata'));
results(end+1) = runCase('training workflow without dataset folder', ...
    @() expectError(@() runTrainingWorkflow(fullfile(tmp, 'missing')), 'CXR:missingDataset'));
results(end+1) = runCase('training workflow without metadata CSV', @() checkWorkflowNoCsv(tmp));
results(end+1) = runCase('CSV without required column is rejected', @() checkMissingColumn(tmp, cfg));
results(end+1) = runCase('labels: Normal / Abnormal / invalid rows are reported', @() checkLabels(tmp, cfg));
results(end+1) = runCase('image index searches nested NIH folders', @() checkIndex(tmp, cfg));
results(end+1) = runCase('official split lists are read', @() checkOfficialLists(tmp, cfg));
results(end+1) = runCase('patient-wise split: no patient in two subsets', @checkSplitIntegrity);
results(end+1) = runCase('patient-wise split is reproducible', @checkSplitReproducible);
results(end+1) = runCase('patient-wise split with fixed (official) test set', @checkFixedTest);
results(end+1) = runCase('subset: balanced classes, max images per patient', @() checkSubset(cfg));
results(end+1) = runCase('subset: shortfalls are reported, not hidden', @() checkShortfall(cfg));

if isempty(nihCsvPath) || exist(nihCsvPath, 'file') ~= 2
    results(end+1) = runCase('real NIH metadata CSV', @() skip('set CXR_NIH_CSV to the CSV path to run'));
else
    results(end+1) = runCase('real NIH metadata CSV', @() checkRealCsv(nihCsvPath, cfg));
end
end

% =========================================================================
function checkWorkflowNoCsv(tmp)
folder = fullfile(tmp, 'emptyDataset');
mkdir(folder);
expectError(@() runTrainingWorkflow(folder), 'CXR:missingMetadata');
end

function checkMissingColumn(tmp, cfg)
f = fullfile(tmp, 'bad.csv');
writeText(f, sprintf('Image Index,Labels\n00000001_000.png,No Finding\n'));
expectError(@() loadDatasetMetadata(f, cfg), 'CXR:invalidMetadata');
end

function checkLabels(tmp, cfg)
f = fullfile(tmp, 'labels.csv');
% Columns re-ordered, CRLF line endings, an extra trailing column
text = ['Patient ID,View Position,Image Index,Finding Labels,Extra' char([13 10]) ...
        '1,PA,a.png,No Finding,x' char([13 10]) ...
        '2,AP,b.png,Cardiomegaly|Effusion,x' char([13 10]) ...
        '3,PA,c.png,No Finding|Mass,x' char([13 10]) ...
        '4,PA,d.png,,x' char([13 10]) ...
        '5,PA,e.png,Covid,x' char([13 10]) ...
        ',PA,f.png,No Finding,x' char([13 10]) ...
        '7,PA,a.png,Nodule,x' char([13 10]) ...
        '8,pa,g.png,Pleural_Thickening,x' char([13 10])];
writeText(f, text);
m = loadDatasetMetadata(f, cfg);
assert(numel(m.imageIndex) == 8, 'expected 8 rows, got %d', numel(m.imageIndex));
expected = {'Normal'; 'Abnormal'; ''; ''; ''; ''; ''; 'Abnormal'};
assert(isequal(m.binaryLabel, expected), 'binary labels wrong: %s', strjoin(m.binaryLabel', '/'));
assert(isequal(m.isValid', logical([1 1 0 0 0 0 0 1])), 'validity flags wrong');
assert(~isempty(strfind(m.invalidReason{3}, 'conflicting')), 'conflict not reported');
assert(~isempty(strfind(m.invalidReason{4}, 'empty')), 'empty label not reported');
assert(~isempty(strfind(m.invalidReason{5}, 'unknown')), 'unknown label not reported');
assert(~isempty(strfind(m.invalidReason{6}, 'patient')), 'missing patient not reported');
assert(~isempty(strfind(m.invalidReason{7}, 'duplicate')), 'duplicate not reported');
assert(strcmp(m.viewPosition{8}, 'PA'), 'view position must be upper-cased');
assert(m.report.numInvalid == 5 && numel(m.report.messages) == 6, 'report incomplete');
end

function checkIndex(tmp, cfg)
root = fullfile(tmp, 'nih');
mkdir(fullfile(root, 'images_001', 'images'));
mkdir(fullfile(root, 'images_002', 'images'));
img = uint8(128 * ones(80));
imwrite(img, fullfile(root, 'images_001', 'images', '00000001_000.png'));
imwrite(img, fullfile(root, 'images_002', 'images', '00000002_000.png'));
imwrite(img, fullfile(root, 'images_002', 'images', '00000001_000.png'));   % duplicate name
writeText(fullfile(root, 'images_002', 'images', 'readme.txt'), 'x');
idx = indexDatasetImages(root, cfg);
assert(numel(idx.fileNames) == 2, 'expected 2 unique images, got %d', numel(idx.fileNames));
assert(isequal(idx.duplicates, {'00000001_000.png'}), 'duplicate not reported');
assert(all(cellfun(@(p) exist(p, 'file') == 2, idx.fullPaths)), 'paths must exist');
end

function checkOfficialLists(tmp, cfg)
folder = fullfile(tmp, 'lists');
mkdir(folder);
assert(isempty(loadOfficialSplit(folder, cfg)), 'missing lists must give []');
writeText(fullfile(folder, 'train_val_list.txt'), sprintf('a.png\r\nb.png\r\n'));
writeText(fullfile(folder, 'test_list.txt'), sprintf('c.png\n'));
s = loadOfficialSplit(folder, cfg);
assert(isequal(s.trainVal, {'a.png'; 'b.png'}) && isequal(s.test, {'c.png'}), 'lists parsed wrongly');
end

function checkSplitIntegrity()
patients = repelem((1:200)', randi([1 4], 200, 1));
[split, report] = splitByPatient(patients, [0.2 0.2], 42);
assert(report.patientOverlap == 0, 'patient overlap detected');
for p = unique(patients)'
    assert(numel(unique(split(patients == p))) == 1, 'patient %d is split across subsets', p);
end
assert(abs(report.numPatients(3) - 40) <= 1 && abs(report.numPatients(2) - 40) <= 1, 'fractions wrong');
end

function checkSplitReproducible()
patients = (1:100)';
a = splitByPatient(patients, [0.2 0.2], 7);
b = splitByPatient(patients, [0.2 0.2], 7);
c = splitByPatient(patients, [0.2 0.2], 8);
assert(isequal(a, b), 'same seed must give the same split');
assert(~isequal(a, c), 'different seeds should give different splits');
end

function checkFixedTest()
patients = [1; 1; 2; 3; 3; 4; 5; 6];
fixed = logical([1; 0; 0; 0; 0; 1; 0; 0]);   % patient 1 only partially listed
[split, report] = splitByPatient(patients, [0.25 0], 1, fixed);
assert(all(strcmp(split(patients == 1), 'test')) && all(strcmp(split(patients == 4), 'test')), ...
    'listed test patients must be in the test set');
assert(report.movedToTestPatients == 1 && report.patientOverlap == 0, 'moved patient not reported');
assert(~any(strcmp(split(~ismember(patients, [1 4])), 'test')), 'only listed patients may be test');
end

function checkSubset(cfg)
[meta, index] = syntheticMeta(400);
cfg.dataset.subsetSize = 100;
cfg.dataset.maxImagesPerPatient = 1;
ds = prepareDataset(meta, index, cfg, []);
assert(numel(ds.imageName) == 100, 'expected 100 images, got %d', numel(ds.imageName));
assert(nnz(strcmp(ds.label, 'Normal')) == 50, 'classes must be balanced');
[~, ~, j] = unique(ds.patientId);
assert(max(accumarray(j, 1)) == 1, 'more than one image per patient');
assert(ds.report.patientOverlap == 0, 'patient overlap');
assert(isequal(sum(ds.report.achieved, 2)', [64 16 20]), 'split sizes wrong: %s', mat2str(sum(ds.report.achieved, 2)'));
ds2 = prepareDataset(meta, index, cfg, []);
assert(isequal(ds.imageName, ds2.imageName), 'subset must be reproducible');
end

function checkShortfall(cfg)
[meta, index] = syntheticMeta(60);
cfg.dataset.subsetSize = 1000;
ds = prepareDataset(meta, index, cfg, []);
assert(numel(ds.imageName) < 1000, 'cannot select more images than exist');
msgs = strjoin(ds.report.messages', ' ');
assert(~isempty(strfind(msgs, 'Requested 1000 images in total')), 'total shortfall not reported');
assert(~isempty(strfind(msgs, 'could be selected')), 'per-class shortfall not reported');
end

function [meta, index] = syntheticMeta(numPatients)
% Metadata struct for 'numPatients' patients with 3 images each (synthetic)
n = 3 * numPatients;
names = arrayfun(@(k) sprintf('%08d.png', k), (1:n)', 'UniformOutput', false);
patient = repelem((1:numPatients)', 3);
labels = repmat({'Normal'; 'Abnormal'; 'Normal'}, numPatients, 1);
meta = struct('imageIndex', {names}, 'findingLabels', {labels}, 'patientId', patient, ...
    'viewPosition', {repmat({'PA'}, n, 1)}, 'followUp', zeros(n, 1), 'binaryLabel', {labels}, ...
    'isValid', true(n, 1), 'invalidReason', {repmat({''}, n, 1)});
index = struct('rootDir', '', 'fileNames', {names}, 'fullPaths', {names}, 'duplicates', {{}}, 'numFolders', 1);
end

function checkRealCsv(csvPath, cfg)
m = loadDatasetMetadata(csvPath, cfg);
assert(m.report.numRows == 112120, 'expected 112120 rows, got %d', m.report.numRows);
assert(m.report.numNormal == 60361, 'expected 60361 "No Finding" rows, got %d', m.report.numNormal);
assert(m.report.numPatients == 30805, 'expected 30805 patients, got %d', m.report.numPatients);
index = struct('rootDir', '', 'fileNames', {m.imageIndex}, 'fullPaths', {m.imageIndex}, ...
               'duplicates', {{}}, 'numFolders', 1);
ds = prepareDataset(m, index, cfg, []);   % logic check: pretend every file exists
assert(ds.report.patientOverlap == 0 && numel(ds.imageName) == cfg.dataset.subsetSize, 'subset failed');
end

function writeText(file, text)
fid = fopen(file, 'w');
fwrite(fid, text);
fclose(fid);
end

function skip(message)
error('CXR:testSkipped', '%s', message);
end

function rmdirQuiet(folder)
try
    rmdir(folder, 's');
catch
end
end
