function officialSplit = loadOfficialSplit(folder, cfg)
%LOADOFFICIALSPLIT Read the official NIH patient-wise split lists if present.
%   officialSplit = loadOfficialSplit(folder, cfg) looks for
%   train_val_list.txt and test_list.txt (one image file name per line) in
%   folder. Returns [] when either file is missing, otherwise a struct with
%   cellstr fields trainVal, test and the two file paths.

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
officialSplit = [];
trainFile = fullfile(folder, cfg.dataset.trainValListName);
testFile  = fullfile(folder, cfg.dataset.testListName);
if exist(trainFile, 'file') ~= 2 || exist(testFile, 'file') ~= 2
    return;
end
officialSplit = struct();
officialSplit.trainVal = readList(trainFile);
officialSplit.test     = readList(testFile);
officialSplit.trainValFile = trainFile;
officialSplit.testFile     = testFile;
if isempty(officialSplit.trainVal) || isempty(officialSplit.test)
    error('CXR:invalidMetadata', 'The official split lists in %s are empty.', folder);
end
end

function names = readList(file)
text = fileread(file);
names = strtrim(regexp(text, '[\r\n]+', 'split'));
names = names(~cellfun(@isempty, names));
names = names(:);
end
