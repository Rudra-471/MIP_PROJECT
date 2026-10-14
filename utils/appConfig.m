function cfg = appConfig()
%APPCONFIG Central parameter set for the whole application.
%   cfg = appConfig() returns a struct with every tunable parameter of the
%   image-processing pipeline, the dataset preparation and the SVM.
%
%   Training stores the pipeline part of this struct inside
%   models/trainedModel.mat, and prediction always re-uses the stored copy.
%   That guarantees that training images and new images go through exactly
%   the same preprocessing, enhancement, segmentation and feature extraction.
%
%   Pixel-based sizes (filter windows, structuring-element radii) refer to
%   the processing resolution cfg.preprocess.processingSize.

cfg = struct();
cfg.formatVersion = 2;
cfg.projectName   = 'Chest X-Ray Abnormality Detection';
cfg.disclaimer    = ['This project is intended for educational and research purposes only. ' ...
                     'Its predictions are not a medical diagnosis and must not be used for ' ...
                     'clinical decision-making.'];

% ------------------------------------------------------------ Image input
cfg.input.supportedExtensions = {'.png', '.jpg', '.jpeg', '.bmp', '.tif', '.tiff'};
cfg.input.minDimension        = 64;     % smaller images are rejected
cfg.input.maxDimension        = 8192;   % larger images are rejected (memory safety)

% ------------------------------------------------------------ Preprocessing
% The longest image side is resized to processingSize (aspect ratio kept).
cfg.preprocess.processingSize = 512;
cfg.preprocess.noiseMethod    = 'median';   % 'median' | 'gaussian' | 'none'
cfg.preprocess.medianWindow   = [3 3];      % small window keeps fine lung texture
cfg.preprocess.gaussianSigma  = 0.8;        % used only when noiseMethod = 'gaussian'

% ------------------------------------------------------------ Enhancement
cfg.enhance.method           = 'stretch';   % 'stretch' | 'histeq' | 'clahe'
cfg.enhance.stretchTolerance = [0.01 0.99]; % fractions saturated by contrast stretching
cfg.enhance.histeqBins       = 64;
cfg.enhance.claheClipLimit   = 0.01;
cfg.enhance.claheNumTiles    = [8 8];
cfg.enhance.gamma            = 1.0;         % 1.0 = identity
cfg.enhance.gammaRange       = [0.3 3.0];
cfg.enhance.histogramBins    = 64;          % bins used for histogram display

% ------------------------------------------------------------ Lung segmentation
cfg.segment.smoothingSigma     = 2;                     % Gaussian pre-smoothing
cfg.segment.sensitivities      = [0.30 0.40 0.50 0.60]; % adaptive-threshold sweep
cfg.segment.neighborhoodFrac   = 0.25;                  % adaptthresh window / image size
cfg.segment.borderClearRadius  = 5;                     % erosion before removing border air
cfg.segment.minComponentFrac   = 0.01;                  % smallest lung component (area fraction)
cfg.segment.maxComponentFrac   = 0.40;                  % largest single lung (area fraction)
cfg.segment.centralBand        = [0.08 0.92];           % allowed centroid x-range (fraction)
cfg.segment.verticalBand       = [0.10 0.85];           % allowed centroid y-range (fraction)
cfg.segment.targetAreaFrac     = [0.08 0.45];           % plausible total lung area
cfg.segment.minContrast        = 0.02;                  % below: no structure to segment

% ------------------------------------------------------------ Morphology
cfg.morph.openRadius     = 5;      % opening: removes small noise / thin spurs
cfg.morph.minObjectFrac  = 0.005;  % objects smaller than this area fraction are removed
cfg.morph.closeRadius    = 12;     % closing: bridges gaps, smooths concavities
cfg.morph.erodeRadius    = 3;      % erosion + dilation: final boundary smoothing
cfg.morph.dilateRadius   = 3;
cfg.morph.maxLungRegions = 2;      % keep at most one region per side (left/right lung)

% ------------------------------------------------------------ Features
% Fixed, documented order. Training and inference use exactly this order.
cfg.features.names = {'Mean', 'Std', 'Variance', 'Min', 'Max', 'Entropy', ...
                      'Contrast', 'Correlation', 'Energy', 'Homogeneity'};
cfg.features.groups = {'Intensity', 'Intensity', 'Intensity', 'Intensity', 'Intensity', ...
                       'Intensity', 'GLCM texture', 'GLCM texture', 'GLCM texture', 'GLCM texture'};
cfg.features.minRoiPixels = 500;               % smaller ROIs are rejected
cfg.features.glcmNumLevels = 32;               % grey-level quantisation for the GLCM
cfg.features.glcmGrayLimits = [0 1];           % fixed limits -> same quantisation for every image
cfg.features.glcmOffsets = [0 1; -1 1; -1 0; -1 -1];  % 0, 45, 90, 135 degrees, distance 1
cfg.features.glcmSymmetric = true;

% ------------------------------------------------------------ Dataset (NIH ChestX-ray14)
cfg.dataset.metadataFileNames = {'Data_Entry_2017_v2020.csv', 'Data_Entry_2017.csv'};
cfg.dataset.trainValListName  = 'train_val_list.txt';   % official NIH patient-wise split
cfg.dataset.testListName      = 'test_list.txt';
cfg.dataset.normalLabel       = 'No Finding';
cfg.dataset.knownFindings     = {'Atelectasis', 'Cardiomegaly', 'Consolidation', 'Edema', ...
                                 'Effusion', 'Emphysema', 'Fibrosis', 'Hernia', 'Infiltration', ...
                                 'Mass', 'Nodule', 'Pleural_Thickening', 'Pneumonia', 'Pneumothorax'};
cfg.dataset.imageExtensions   = {'.png', '.jpg', '.jpeg'};
cfg.dataset.maxSearchDepth    = 6;      % folder depth searched when indexing images
cfg.dataset.subsetSize        = 1000;   % requested total number of images
cfg.dataset.balanceClasses    = true;   % request equal Normal / Abnormal counts
cfg.dataset.viewPositions     = {'PA'}; % {'PA'} or {'PA','AP'}
cfg.dataset.maxImagesPerPatient = 1;    % Inf = use every image of a patient
cfg.dataset.testFraction      = 0.20;   % used when no official split lists exist
cfg.dataset.validationFraction = 0.20;  % fraction of the training patients
cfg.dataset.randomSeed        = 42;

% ------------------------------------------------------------ SVM
cfg.svm.classNames      = {'Normal', 'Abnormal'};
cfg.svm.positiveClass   = 'Abnormal';   % "positive" for precision / sensitivity
cfg.svm.kernels         = {'linear', 'rbf'};
cfg.svm.boxConstraints  = [0.1 1 10 100];
cfg.svm.kernelScales    = [0.5 1 2 4 8]; % multiplied by sqrt(number of features), rbf only
cfg.svm.balanceWeights  = true;          % 'Prior','uniform': equal total weight per class
cfg.svm.refitOnTrainVal = true;          % final model trained on train + validation
cfg.svm.minTrainPerClass = 10;
cfg.svm.minValidationPerClass = 3;
end
