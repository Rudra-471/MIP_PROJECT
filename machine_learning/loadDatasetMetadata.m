function meta = loadDatasetMetadata(csvPath, cfg)
%LOADDATASETMETADATA Read and validate the NIH ChestX-ray14 metadata CSV.
%   meta = loadDatasetMetadata(csvPath, cfg) reads Data_Entry_2017_v2020.csv
%   (or the older Data_Entry_2017.csv). Columns are located by their header
%   names, so column order does not matter. Required columns:
%     "Image Index", "Finding Labels", "Patient ID"
%   Optional: "View Position", "Follow-up #".
%
%   Binary dataset-derived reference labels:
%     "No Finding"                            -> Normal
%     one or more of the 14 NIH findings      -> Abnormal
%   These labels were extracted automatically from radiology reports by the
%   dataset authors (NLP), are imperfect, and are not clinical ground truth.
%
%   Rows that cannot be labelled safely are marked invalid and REPORTED,
%   never silently treated as Normal:
%     empty label, "No Finding" combined with a finding (conflict), unknown
%     label text, missing/invalid patient ID, duplicate image file name.
%
%   meta fields (one element per CSV row)
%     imageIndex, findingLabels, viewPosition (cellstr), patientId, followUp
%     (double), binaryLabel (cellstr: 'Normal' | 'Abnormal' | ''), isValid,
%     invalidReason (cellstr), csvPath, report (counts + messages)

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 1 || isempty(csvPath)
    error('CXR:missingMetadata', 'No metadata CSV file was specified.');
end
csvPath = char(csvPath);
if exist(csvPath, 'file') ~= 2
    error('CXR:missingMetadata', ['Metadata file not found: %s\nDownload ' ...
        'Data_Entry_2017_v2020.csv from https://nihcc.app.box.com/v/ChestXray-NIHCC ' ...
        'and place it in the dataset folder.'], csvPath);
end

fid = fopen(csvPath, 'r');
if fid < 0
    error('CXR:missingMetadata', 'Cannot open metadata file %s.', csvPath);
end
cleaner = onCleanup(@() fclose(fid));
headerLine = fgetl(fid);
if ~ischar(headerLine) || isempty(strtrim(headerLine))
    error('CXR:invalidMetadata', 'The metadata file %s is empty.', csvPath);
end
headerLine = regexprep(headerLine, '^\xEF\xBB\xBF', '');   % UTF-8 byte-order mark
header = strtrim(strrep(strsplit(headerLine, ','), '"', ''));

col = struct();
col.image   = findColumn(header, 'Image Index', true, csvPath);
col.labels  = findColumn(header, 'Finding Labels', true, csvPath);
col.patient = findColumn(header, 'Patient ID', true, csvPath);
col.view    = findColumn(header, 'View Position', false, csvPath);
col.follow  = findColumn(header, 'Follow-up #', false, csvPath);

% Read only the needed columns as text; skip the others and the rest of the line
wanted = [col.image, col.labels, col.patient, col.view, col.follow];
wanted = wanted(wanted > 0);           % optional columns that are absent are 0
lastCol = max(wanted);
format = '';
for c = 1:lastCol
    if any(wanted == c)
        format = [format '%s']; %#ok<AGROW>
    else
        format = [format '%*s']; %#ok<AGROW>
    end
end
format = [format '%*[^\n]'];
% Whitespace '' -> %s reads up to the comma, so "No Finding" stays one field
data = textscan(fid, format, 'Delimiter', ',', 'Whitespace', '', 'EndOfLine', '\n', ...
                'ReturnOnError', false);
clear cleaner;

order = sort(wanted);
getCol = @(c) stripText(data{order == c});
imageIndex    = getCol(col.image);
findingLabels = getCol(col.labels);
patientText   = getCol(col.patient);
n = numel(imageIndex);
if n == 0
    error('CXR:invalidMetadata', 'The metadata file %s contains no data rows.', csvPath);
end
if numel(findingLabels) ~= n || numel(patientText) ~= n
    error('CXR:invalidMetadata', 'The metadata file %s has rows with missing columns.', csvPath);
end
if col.view > 0
    viewPosition = upper(getCol(col.view));
else
    viewPosition = repmat({''}, n, 1);
end
if col.follow > 0
    followUp = str2double(getCol(col.follow));
else
    followUp = nan(n, 1);
end
patientId = str2double(patientText);

% ---- Binary labels (parsed once per unique label string) ------------------
[uniqueLabels, ~, labelIdx] = unique(findingLabels);
uniqueBinary = cell(numel(uniqueLabels), 1);
uniqueReason = cell(numel(uniqueLabels), 1);
for k = 1:numel(uniqueLabels)
    [uniqueBinary{k}, uniqueReason{k}] = mapLabel(uniqueLabels{k}, cfg);
end
binaryLabel = uniqueBinary(labelIdx);
invalidReason = uniqueReason(labelIdx);
binaryLabel = binaryLabel(:);
invalidReason = invalidReason(:);

badPatient = ~isfinite(patientId) | patientId < 0 | patientId ~= round(patientId);
invalidReason(badPatient & cellfun(@isempty, invalidReason)) = {'missing or invalid patient ID'};

emptyName = cellfun(@isempty, imageIndex);
invalidReason(emptyName) = {'missing image file name'};
[~, firstIdx] = unique(imageIndex, 'first');
isDuplicate = true(n, 1);
isDuplicate(firstIdx) = false;
isDuplicate = isDuplicate & ~emptyName;
invalidReason(isDuplicate) = {'duplicate image file name'};

isValid = cellfun(@isempty, invalidReason);
binaryLabel(~isValid) = {''};

meta = struct();
meta.csvPath       = csvPath;
meta.imageIndex    = imageIndex;
meta.findingLabels = findingLabels;
meta.patientId     = patientId;
meta.viewPosition  = viewPosition;
meta.followUp      = followUp;
meta.binaryLabel   = binaryLabel;
meta.isValid       = isValid;
meta.invalidReason = invalidReason;
meta.report        = buildReport(meta);
end

% =========================================================================
function idx = findColumn(header, name, required, csvPath)
idx = find(strcmpi(header, name), 1);
if isempty(idx)
    if required
        error('CXR:invalidMetadata', ['Column "%s" not found in %s. Is this the NIH ' ...
            'ChestX-ray14 Data_Entry CSV?'], name, csvPath);
    end
    idx = 0;
end
end

function c = stripText(c)
c = strtrim(strrep(c(:), '"', ''));
end

function [binary, reason] = mapLabel(labelText, cfg)
binary = '';
reason = '';
labelText = strtrim(labelText);
if isempty(labelText)
    reason = 'empty finding label';
    return;
end
tokens = strtrim(strsplit(labelText, '|'));
tokens = tokens(~cellfun(@isempty, tokens));
isNormalToken = strcmpi(tokens, cfg.dataset.normalLabel);
isKnownFinding = ismember(lower(tokens), lower(cfg.dataset.knownFindings));
if any(~isNormalToken & ~isKnownFinding)
    unknown = tokens(~isNormalToken & ~isKnownFinding);
    reason = sprintf('unknown label "%s"', strjoin(unknown, '|'));
elseif any(isNormalToken) && any(isKnownFinding)
    reason = 'conflicting labels ("No Finding" together with a finding)';
elseif all(isNormalToken)
    binary = 'Normal';
else
    binary = 'Abnormal';
end
end

function r = buildReport(meta)
r = struct();
r.numRows      = numel(meta.imageIndex);
r.numValid     = nnz(meta.isValid);
r.numInvalid   = r.numRows - r.numValid;
r.numNormal    = nnz(strcmp(meta.binaryLabel, 'Normal'));
r.numAbnormal  = nnz(strcmp(meta.binaryLabel, 'Abnormal'));
r.numPatients  = numel(unique(meta.patientId(meta.isValid)));
[reasons, ~, idx] = unique(meta.invalidReason(~meta.isValid));
counts = accumarray(idx(:), 1, [numel(reasons) 1]);
r.invalidReasons = reasons(:);
r.invalidCounts  = counts(:);
messages = {sprintf('%d metadata rows, %d with a valid binary label (%d Normal, %d Abnormal), %d patients.', ...
    r.numRows, r.numValid, r.numNormal, r.numAbnormal, r.numPatients)};
for k = 1:numel(reasons)
    messages{end + 1} = sprintf('Excluded %d row(s): %s.', counts(k), reasons{k}); %#ok<AGROW>
end
r.messages = messages(:);
end
