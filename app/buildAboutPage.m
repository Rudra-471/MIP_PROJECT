function h = buildAboutPage(parent, theme, ~)
%BUILDABOUTPAGE Project information: objective, methods, evaluation, limitations.

cfg = appConfig();
h = struct();
h.panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.bg, 'Visible', 'off');
h.panel.Layout.Row = 1;
h.panel.Layout.Column = 1;
page = uigridlayout(h.panel, [3 3], 'RowHeight', {'1x', '1x', '1x'}, 'ColumnWidth', {'1x', '1x', '1x'}, ...
                    'Padding', [0 0 0 0], 'RowSpacing', theme.gap, 'ColumnSpacing', theme.gap, ...
                    'BackgroundColor', theme.bg);

sections = {
 'Project objective', {
   'Build a complete MATLAB pipeline that takes a real frontal chest X-ray, processes it with classical image-processing techniques and predicts Normal or Abnormal with a Support Vector Machine trained on NIH ChestX-ray14.'
   ''
   'No deep learning, no pretrained networks and no external AI services are used. Every intermediate result can be inspected in the Image Analysis workspace.'}
 'Image processing workflow', {
   '1. Acquisition: imread + validation (format, size, corruption).'
   '2. Grayscale conversion (rgb2gray) and conversion to double [0,1].'
   '3. Resizing: longest side 512 px, aspect ratio preserved.'
   '4. Noise reduction: 3x3 median filter (medfilt2) - removes impulse noise, keeps edges.'
   '5. Enhancement (one selectable method): contrast stretching (imadjust), histogram equalization (histeq) or CLAHE (adapthisteq).'
   '6. Gamma correction: out = in^gamma (imadjust).'
   '7. Histogram analysis (imhist) before / after enhancement.'}
 'Lung segmentation', {
   'Classical, threshold-based and approximate:'
   '- polarity check (mediastinum should be brighter than the lungs)'
   '- Gaussian smoothing, Otsu threshold (graythresh) and adaptive thresholds (adaptthresh) at several sensitivities'
   '- removal of air outside the body (imclearborder)'
   '- connected components (bwconncomp, regionprops) filtered by area and position; one region per side'
   '- plausibility score; if nothing plausible is found the status is "failed" - no mask is invented.'}
 'Morphological operations', {
   'Opening (imopen, disk r=5): removes small blobs and thin spurs.'
   'Small-object removal (bwareaopen).'
   'Closing (imclose, disk r=12): bridges gaps, smooths concavities.'
   'Hole filling (imfill): fills holes caused by vessels or dense regions.'
   'Erosion + dilation (imerode / imdilate, disk r=3): smooths the contour.'
   ''
   'These operations only make the mask more consistent; they do not detect disease.'}
 'Feature extraction', {
   'Computed inside the final lung mask of the enhanced image, in a fixed order:'
   'Intensity: Mean, Std, Variance, Min, Max, Entropy'
   'GLCM texture (graycomatrix / graycoprops): Contrast, Correlation, Energy, Homogeneity'
   ''
   'GLCM: 32 grey levels over the fixed range [0,1], offsets 0/45/90/135 degrees at distance 1, symmetric, averaged over directions. Pixels outside the lung are ignored (NaN).'}
 'SVM classification', {
   'fitcsvm with z-score standardisation from the training data, inverse class-frequency observation weights, and an explicit kernel choice.'
   'Linear and RBF kernels, BoxConstraint and KernelScale are compared on a patient-wise VALIDATION set (balanced accuracy). The chosen model is refitted on training + validation data.'
   'The model file stores the classifier, feature order, standardisation, class labels and the full pipeline configuration, so new images are processed exactly like the training images.'
   'Only the predicted class is shown: SVM scores are not calibrated probabilities.'}
 'Evaluation methodology', {
   'Dataset-derived labels: "No Finding" -> Normal, any finding -> Abnormal (positive class).'
   'Patient-wise split: the official NIH lists when available, otherwise a reproducible random split by Patient ID. No patient appears in two subsets.'
   'The held-out test set is used once, after training, for: accuracy, precision, sensitivity, specificity, F1-score and the confusion matrix.'
   'A good accuracy value alone does not establish clinical usefulness.'}
 'Limitations', {
   '- NIH labels were mined from radiology reports by NLP and contain errors; they are reference labels, not ground truth.'
   '- Ten hand-crafted intensity/texture features cannot capture many pathologies; performance is expected to be modest.'
   '- Lung segmentation is heuristic and not validated against annotated masks.'
   '- Binary classification does not localise abnormalities: the lung overlay is NOT a lesion map.'
   '- Possible confounders (devices, view position, hospital processing) are not controlled beyond the PA-only default.'}
 'Medical disclaimer', {
   cfg.disclaimer
   ''
   'A "Normal" prediction does not mean the patient is healthy, and an "Abnormal" prediction does not mean a disease is present. The system is not clinically validated.'}
 };

for k = 1:size(sections, 1)
    [card, body] = uiCard(page, theme, sections{k, 1}, [1 1]);
    card.Layout.Row = ceil(k / 3);
    card.Layout.Column = mod(k - 1, 3) + 1;
    color = theme.text;
    if k == size(sections, 1)
        color = theme.warning;
    end
    textArea = uitextarea(body, 'Value', sections{k, 2}, 'Editable', 'off', ...
        'BackgroundColor', theme.card, 'FontColor', color, 'FontName', theme.font, ...
        'FontSize', theme.fontSize.label);
    h.sections{k} = textArea;
end
end
