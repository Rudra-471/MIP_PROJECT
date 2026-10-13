function exportReport(report, filePath)
%EXPORTREPORT Write a single-image analysis report as TXT or CSV.
%   exportReport(report, filePath) - the format follows the file extension
%   (.txt or .csv). report is a struct built by buildAnalysisReport with
%   fields: fileName, enhancementMethod, gamma, noiseMethod, roiType,
%   segmentationStatus, featureNames, featureValues, modelStatus,
%   prediction, predictionNote, datasetLabel.
%
%   The report contains no patient information and is NOT a clinical
%   diagnostic report; the disclaimer is always included.

if nargin < 2 || isempty(filePath)
    error('CXR:exportFailed', 'No output file was specified.');
end
cfg = appConfig();
[~, ~, ext] = fileparts(filePath);
fid = fopen(filePath, 'w');
if fid < 0
    error('CXR:exportFailed', 'Cannot write %s (check folder permissions).', filePath);
end
cleaner = onCleanup(@() fclose(fid));
stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

rows = {
    'Project', cfg.projectName
    'Generated', stamp
    'Input image', report.fileName
    'Noise reduction', report.noiseMethod
    'Enhancement method', report.enhancementMethod
    'Gamma', sprintf('%.2f', report.gamma)
    'Segmentation status', report.segmentationStatus
    'Feature ROI', report.roiType
    'Model status', report.modelStatus
    'Prediction', report.prediction
    'Prediction note', report.predictionNote
    'Dataset label (reference)', report.datasetLabel
    };

switch lower(ext)
    case '.csv'
        fprintf(fid, 'field,value\n');
        for k = 1:size(rows, 1)
            fprintf(fid, '%s,%s\n', csvField(rows{k, 1}), csvField(rows{k, 2}));
        end
        for k = 1:numel(report.featureNames)
            fprintf(fid, '%s,%s\n', csvField(['Feature: ' report.featureNames{k}]), ...
                featureText(report.featureValues, k));
        end
        fprintf(fid, '%s,%s\n', 'Disclaimer', csvField(cfg.disclaimer));
    case '.txt'
        fprintf(fid, '%s\nAnalysis report (educational / research use only)\n%s\n\n', ...
            cfg.projectName, repmat('=', 1, 60));
        for k = 1:size(rows, 1)
            fprintf(fid, '%-27s: %s\n', rows{k, 1}, rows{k, 2});
        end
        fprintf(fid, '\nExtracted features (ROI: %s)\n', report.roiType);
        for k = 1:numel(report.featureNames)
            fprintf(fid, '  %-14s %s\n', report.featureNames{k}, featureText(report.featureValues, k));
        end
        fprintf(fid, '\nDISCLAIMER\n%s\n', cfg.disclaimer);
        fprintf(fid, ['The lung overlay shows an approximate segmented lung region; it does not ' ...
                      'localise any abnormality.\n']);
    otherwise
        error('CXR:exportFailed', 'Unsupported report format "%s" (use .txt or .csv).', ext);
end
end

function t = featureText(values, k)
if isempty(values)
    t = 'not computed';
else
    t = sprintf('%.6g', values(k));
end
end

function t = csvField(v)
v = char(v);
if any(v == ',') || any(v == '"') || any(v == newline)
    t = ['"' strrep(v, '"', '""') '"'];
else
    t = v;
end
end
