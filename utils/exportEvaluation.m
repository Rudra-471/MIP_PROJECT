function files = exportEvaluation(evaluation, outputDir)
%EXPORTEVALUATION Save held-out test evaluation results to a folder.
%   files = exportEvaluation(evaluation, outputDir) writes
%     metrics.csv           metric name, value (positive class = Abnormal)
%     metrics.txt           human-readable summary with definitions
%     confusion_matrix.csv  rows = true class, columns = predicted class
%     test_predictions.csv  image, patient, true label, predicted label, score
%   evaluation is the struct produced by runTrainingWorkflow (fields
%   metrics, predictions, model summary, dataset summary).

if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end
m = evaluation.metrics;
files = struct();

% ---- metrics.csv --------------------------------------------------------------
files.metricsCsv = fullfile(outputDir, 'metrics.csv');
fid = openForWriting(files.metricsCsv);
fprintf(fid, 'metric,value\n');
fprintf(fid, 'evaluated_samples,%d\n', m.numSamples);
fprintf(fid, 'positive_class,%s\n', m.positiveClass);
rows = {'accuracy', 'precision', 'sensitivity', 'specificity', 'f1', 'balancedAccuracy'};
for k = 1:numel(rows)
    fprintf(fid, '%s,%s\n', rows{k}, numberText(m.(rows{k})));
end
fprintf(fid, 'TP,%d\nTN,%d\nFP,%d\nFN,%d\n', m.TP, m.TN, m.FP, m.FN);
fclose(fid);

% ---- confusion_matrix.csv -----------------------------------------------------
files.confusionCsv = fullfile(outputDir, 'confusion_matrix.csv');
fid = openForWriting(files.confusionCsv);
fprintf(fid, 'true\\predicted,%s\n', strjoin(m.classNames, ','));
for i = 1:numel(m.classNames)
    fprintf(fid, '%s,%d,%d\n', m.classNames{i}, m.confusionMatrix(i, :));
end
fclose(fid);

% ---- test_predictions.csv -----------------------------------------------------
if isfield(evaluation, 'predictions') && ~isempty(evaluation.predictions)
    p = evaluation.predictions;
    files.predictionsCsv = fullfile(outputDir, 'test_predictions.csv');
    fid = openForWriting(files.predictionsCsv);
    fprintf(fid, 'image,patient_id,dataset_label,predicted_label,svm_score_uncalibrated,correct\n');
    for k = 1:numel(p.imageName)
        fprintf(fid, '%s,%d,%s,%s,%.4f,%d\n', p.imageName{k}, p.patientId(k), p.trueLabel{k}, ...
            p.predictedLabel{k}, p.score(k), strcmp(p.trueLabel{k}, p.predictedLabel{k}));
    end
    fclose(fid);
end

% ---- metrics.txt --------------------------------------------------------------
files.metricsTxt = fullfile(outputDir, 'metrics.txt');
fid = openForWriting(files.metricsTxt);
cfg = appConfig();
fprintf(fid, '%s - held-out test evaluation\n', cfg.projectName);
fprintf(fid, '%s\n\n', repmat('=', 1, 60));
fprintf(fid, 'DISCLAIMER: %s\n\n', cfg.disclaimer);
fprintf(fid, 'Generated      : %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
if isfield(evaluation, 'summary')
    s = evaluation.summary;
    fields = fieldnames(s);
    for k = 1:numel(fields)
        fprintf(fid, '%-15s: %s\n', fields{k}, valueText(s.(fields{k})));
    end
end
fprintf(fid, '\nPositive class : %s (TP = correctly predicted %s)\n', m.positiveClass, m.positiveClass);
fprintf(fid, 'Test samples   : %d (%s %d, %s %d)\n\n', m.numSamples, m.classNames{1}, ...
    m.trueClassCounts(1), m.classNames{2}, m.trueClassCounts(2));
labels = {'Accuracy', 'Precision', 'Sensitivity', 'Specificity', 'F1-score', 'Balanced accuracy'};
for k = 1:numel(rows)
    fprintf(fid, '%-18s: %s\n', labels{k}, percentText(m.(rows{k})));
end
fprintf(fid, '\nConfusion matrix (rows = dataset label, columns = prediction)\n');
fprintf(fid, '%14s %10s %10s\n', '', m.classNames{:});
for i = 1:2
    fprintf(fid, '%14s %10d %10d\n', m.classNames{i}, m.confusionMatrix(i, :));
end
fprintf(fid, '\nTP = %d, TN = %d, FP = %d, FN = %d\n', m.TP, m.TN, m.FP, m.FN);
if ~isempty(m.undefined)
    fprintf(fid, 'Undefined (zero denominator): %s\n', strjoin(m.undefined, ', '));
end
fprintf(fid, ['\nNotes\n- Reference labels are NIH ChestX-ray14 labels mined from radiology ' ...
    'reports by NLP;\n  they contain errors and are not clinical ground truth.\n' ...
    '- A good accuracy value alone does not establish clinical usefulness.\n']);
fclose(fid);
end

function fid = openForWriting(file)
fid = fopen(file, 'w');
if fid < 0
    error('CXR:exportFailed', 'Cannot write %s (check folder permissions).', file);
end
end

function t = numberText(v)
if isnan(v)
    t = 'undefined';
else
    t = sprintf('%.6f', v);
end
end

function t = percentText(v)
if isnan(v)
    t = 'undefined (zero denominator)';
else
    t = sprintf('%.2f %%', 100 * v);
end
end

function t = valueText(v)
if ischar(v)
    t = v;
elseif isnumeric(v) || islogical(v)
    t = mat2str(v);
elseif iscellstr(v)
    t = strjoin(v, ', ');
else
    t = '(not shown)';
end
end
