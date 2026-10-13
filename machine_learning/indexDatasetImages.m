function index = indexDatasetImages(rootDir, cfg, progressFcn)
%INDEXDATASETIMAGES Build a file-name -> full-path index of all images below a folder.
%   index = indexDatasetImages(rootDir, cfg) searches rootDir and its
%   sub-folders (up to cfg.dataset.maxSearchDepth levels). The NIH dataset is
%   distributed as images_001 ... images_012 archives, each extracting to
%   images_XXX/images/*.png, so no single image folder is assumed.
%
%   index fields
%     rootDir
%     fileNames  - cellstr of file names (e.g. '00000001_000.png'), unique
%     fullPaths  - matching full paths
%     duplicates - file names found more than once (first occurrence is used)
%     numFolders - number of folders searched
%   progressFcn (optional) is called as progressFcn(numFoldersSearched, currentFolder).

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 3
    progressFcn = [];
end
if nargin < 1 || isempty(rootDir) || exist(char(rootDir), 'dir') ~= 7
    error('CXR:missingDataset', ['Dataset folder not found: %s\nSelect the folder that ' ...
        'contains the NIH images (images_001 ... images_012) and Data_Entry_2017_v2020.csv.'], ...
        char(rootDir));
end
rootDir = char(rootDir);

names = {};
paths = {};
queue = {rootDir};
depths = 0;
numFolders = 0;
while ~isempty(queue)
    folder = queue{1};
    depth = depths(1);
    queue(1) = [];
    depths(1) = [];
    numFolders = numFolders + 1;
    entries = dir(folder);
    for k = 1:numel(entries)
        name = entries(k).name;
        if isempty(name) || name(1) == '.'
            continue;
        end
        if entries(k).isdir
            if depth < cfg.dataset.maxSearchDepth
                queue{end + 1} = fullfile(folder, name); %#ok<AGROW>
                depths(end + 1) = depth + 1; %#ok<AGROW>
            end
        else
            [~, ~, ext] = fileparts(name);
            if any(strcmpi(ext, cfg.dataset.imageExtensions))
                names{end + 1, 1} = name; %#ok<AGROW>
                paths{end + 1, 1} = fullfile(folder, name); %#ok<AGROW>
            end
        end
    end
    if ~isempty(progressFcn)
        progressFcn(numFolders, folder);
    end
end

[uniqueNames, firstIdx] = unique(names, 'first');
duplicates = {};
if numel(uniqueNames) < numel(names)
    isDup = true(numel(names), 1);
    isDup(firstIdx) = false;
    duplicates = unique(names(isDup));
end

index = struct();
index.rootDir    = rootDir;
index.fileNames  = names(firstIdx);
index.fullPaths  = paths(firstIdx);
index.duplicates = duplicates(:);
index.numFolders = numFolders;
end
