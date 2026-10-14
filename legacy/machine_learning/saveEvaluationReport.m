function saveEvaluationReport(resultsDir, model, testMetrics, cvMetrics, data, isTest, testPred)
%SAVEEVALUATIONREPORT Write metrics, confusion matrix and predictions to results/.
%   Files written:
%     metrics.txt           - human-readable report with metric explanations
%     metrics.csv           - machine-readable metrics (test + cross-validation)
%     confusion_matrix.png  - test-set confusion matrix figure
%     test_predictions.csv  - per-image prediction for every test image
%     cv_grid.csv           - cross-validation results of the hyper-parameter search
%     failed_images.csv     - images skipped during feature extraction

if exist(resultsDir, 'dir') ~= 7
    mkdir(resultsDir);
end
info = model.trainingInfo;

% ---- metrics.txt ----------------------------------------------------------
fid = fopen(fullfile(resultsDir, 'metrics.txt'), 'w');
fprintf(fid, 'Chest X-Ray Abnormality Detection - model evaluation\n');
fprintf(fid, '====================================================\n');
fprintf(fid, 'EDUCATIONAL / RESEARCH USE ONLY - NOT A MEDICAL DIAGNOSIS.\n\n');
fprintf(fid, 'Trained on : %s\nEnvironment: %s\n', info.trainedOn, info.environment);
fprintf(fid, 'Images     : %d train, %d test (stratified %.0f/%.0f split, seed %d), %d skipped\n', ...
    info.numTrain, info.numTest, 100 * (1 - model.cfg.testFraction), ...
    100 * model.cfg.testFraction, model.cfg.randomSeed, info.numFailedImages);
fprintf(fid, 'Classifier : SVM, %s kernel, BoxConstraint = %g, KernelScale = %.4g\n', ...
    model.cfg.svmKernel, model.hyperparameters.BoxConstraint, model.hyperparameters.KernelScale);
fprintf(fid, 'Features   : %s\n\n', strjoin(model.featureNames, ', '));
writeMetricBlock(fid, sprintf('HELD-OUT TEST SET (%d images)', testMetrics.numSamples), testMetrics);
writeMetricBlock(fid, sprintf('%d-FOLD CROSS-VALIDATION ON TRAINING SET (%d images)', ...
    model.cfg.cvFolds, cvMetrics.numSamples), cvMetrics);
fprintf(fid, ['Metric definitions (positive class = Abnormal)\n' ...
    '  Accuracy    : overall percentage of correct predictions.\n' ...
    '  Precision   : percentage of predicted-Abnormal images that are truly Abnormal.\n' ...
    '  Sensitivity : (recall) ability to correctly identify abnormal cases, TP/(TP+FN).\n' ...
    '  Specificity : ability to correctly identify normal cases, TN/(TN+FP).\n' ...
    '  F1-score    : harmonic mean (balance) of precision and recall.\n' ...
    '  ROC AUC     : probability that a random Abnormal image gets a higher\n' ...
    '                score than a random Normal image (0.5 = chance).\n']);
fclose(fid);

% ---- metrics.csv ------------------------------------------------------------
fid = fopen(fullfile(resultsDir, 'metrics.csv'), 'w');
fprintf(fid, 'split,n,accuracy,precision,sensitivity,specificity,f1,balanced_accuracy,auc,TP,TN,FP,FN\n');
writeMetricRow(fid, 'test', testMetrics);
writeMetricRow(fid, 'cross_validation', cvMetrics);
fclose(fid);

% ---- test_predictions.csv ---------------------------------------------------
testFiles  = data.imageFiles(isTest);
testLabels = data.labels(isTest);
fid = fopen(fullfile(resultsDir, 'test_predictions.csv'), 'w');
fprintf(fid, 'file,true_label,predicted_label,prob_abnormal,svm_score,correct\n');
for k = 1:numel(testFiles)
    fprintf(fid, '%s,%s,%s,%.4f,%.4f,%d\n', testFiles{k}, testLabels{k}, testPred.label{k}, ...
        testPred.probAbnormal(k), testPred.svmScore(k), strcmp(testLabels{k}, testPred.label{k}));
end
fclose(fid);

% ---- cv_grid.csv ------------------------------------------------------------
fid = fopen(fullfile(resultsDir, 'cv_grid.csv'), 'w');
fprintf(fid, 'box_constraint,kernel_scale,cv_balanced_accuracy,cv_accuracy\n');
fprintf(fid, '%g,%.4f,%.4f,%.4f\n', info.cvResults.');
fclose(fid);

% ---- failed_images.csv ------------------------------------------------------
fid = fopen(fullfile(resultsDir, 'failed_images.csv'), 'w');
fprintf(fid, 'file,reason\n');
for k = 1:size(data.failedImages, 1)
    fprintf(fid, '%s,"%s"\n', data.failedImages{k, 1}, strrep(data.failedImages{k, 2}, '"', ''''));
end
fclose(fid);

% ---- confusion_matrix.png ---------------------------------------------------
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 520 460]);
ax = axes('Parent', fig);
plotConfusionMatrix(ax, testMetrics.confusionMatrix, testMetrics.classNames, ...
    sprintf('Test set confusion matrix (n = %d)', testMetrics.numSamples));
print(fig, fullfile(resultsDir, 'confusion_matrix.png'), '-dpng', '-r120');
close(fig);
fprintf('Evaluation report written to %s\n', resultsDir);
end

function writeMetricBlock(fid, heading, m)
fprintf(fid, '%s\n', heading);
fprintf(fid, '  Accuracy    : %6.2f %%\n', 100 * m.accuracy);
fprintf(fid, '  Precision   : %6.2f %%\n', 100 * m.precision);
fprintf(fid, '  Sensitivity : %6.2f %%\n', 100 * m.sensitivity);
fprintf(fid, '  Specificity : %6.2f %%\n', 100 * m.specificity);
fprintf(fid, '  F1-score    : %6.2f %%\n', 100 * m.f1);
fprintf(fid, '  Balanced acc: %6.2f %%\n', 100 * m.balancedAccuracy);
fprintf(fid, '  ROC AUC     : %6.3f\n', m.auc);
fprintf(fid, '  Confusion matrix (rows = true, columns = predicted):\n');
fprintf(fid, '                 %10s %10s\n', m.classNames{:});
for i = 1:numel(m.classNames)
    fprintf(fid, '    %-12s %10d %10d\n', m.classNames{i}, m.confusionMatrix(i, :));
end
fprintf(fid, '  TP = %d, TN = %d, FP = %d, FN = %d\n\n', m.TP, m.TN, m.FP, m.FN);
end

function writeMetricRow(fid, name, m)
fprintf(fid, '%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%d\n', name, m.numSamples, ...
    m.accuracy, m.precision, m.sensitivity, m.specificity, m.f1, m.balancedAccuracy, m.auc, ...
    m.TP, m.TN, m.FP, m.FN);
end
