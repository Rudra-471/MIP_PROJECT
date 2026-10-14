function csvPath = makeSyntheticNihFolder(folder, numPatients, imageSize)
%MAKESYNTHETICNIHFOLDER Build a SYNTHETIC folder with the NIH ChestX-ray14 layout.
%   csvPath = makeSyntheticNihFolder(folder, numPatients, imageSize) writes
%   phantom images (makeChestPhantom) to folder/images_001/images/ and
%   folder/images_002/images/ and a Data_Entry_2017_v2020.csv describing them.
%   Even patients get "No Finding", odd patients "Effusion" (their phantom
%   contains an opacity blob).
%
%   SOFTWARE INTEGRATION TESTING ONLY. These are not medical images and the
%   labels are not real data. Results computed on this folder only show
%   that the code runs; they are never reported as model performance.

if nargin < 3, imageSize = 512; end
dirs = {fullfile(folder, 'images_001', 'images'), fullfile(folder, 'images_002', 'images')};
for k = 1:2
    if exist(dirs{k}, 'dir') ~= 7
        mkdir(dirs{k});
    end
end
csvPath = fullfile(folder, 'Data_Entry_2017_v2020.csv');
fid = fopen(csvPath, 'w');
fprintf(fid, ['Image Index,Finding Labels,Follow-up #,Patient ID,Patient Age,Patient Gender,' ...
              'View Position,OriginalImage[Width,Height],OriginalImagePixelSpacing[x,y]\n']);
for p = 1:numPatients
    abnormal = mod(p, 2) == 1;
    name = sprintf('%08d_000.png', p);
    img = makeChestPhantom(imageSize, p, abnormal);
    imwrite(im2uint8(img), fullfile(dirs{1 + mod(p, 2)}, name));
    if abnormal
        label = 'Effusion';
    else
        label = 'No Finding';
    end
    fprintf(fid, '%s,%s,0,%d,50,M,PA,%d,%d,0.143,0.143\n', name, label, p, imageSize, imageSize);
end
fclose(fid);
end
