function cfg = getConfig()
%GETCONFIG Central parameter set for the whole processing pipeline.
%   All tunable values live here so that training (trainModel) and
%   inference (predictImage / ChestXrayApp) are guaranteed to use exactly
%   the same settings. The configuration is stored inside trainedModel.mat
%   and re-used at prediction time.

cfg = struct();
cfg.version = 1;

% ---------------- Input / preprocessing ----------------
cfg.supportedExtensions = {'.jpg', '.jpeg', '.png', '.bmp'};
cfg.imageSize           = [512 512];   % every image is resized to this
cfg.medianFilterSize    = [3 3];       % noise reduction window (see preprocessImage)
cfg.stretchPercentiles  = [0.5 99.5];  % robust intensity normalisation

% ---------------- Contrast enhancement ----------------
cfg.enhancementMethod = 'clahe';       % 'clahe' | 'histeq' | 'imadjust'
cfg.claheClipLimit    = 0.01;
cfg.claheNumTiles     = [8 8];
cfg.defaultGamma      = 1.0;           % 1.0 = no change
cfg.gammaRange        = [0.2 3.0];

% ---------------- Lung segmentation ----------------
cfg.segSmoothingSigma      = 2;                    % Gaussian pre-smoothing
cfg.segSensitivities       = [0.30 0.40 0.50 0.60]; % adaptive threshold sweep
cfg.segNeighborhoodFrac    = 0.25;                 % adaptthresh window (fraction of size)
cfg.segMinComponentFrac    = 0.01;                 % min lung component area (fraction)
cfg.segMaxComponentFrac    = 0.40;                 % max single lung area (fraction)
cfg.segTargetAreaFrac      = [0.08 0.45];          % plausible total lung area
cfg.segCentralBand         = [0.08 0.92];          % allowed centroid x-range (fraction)
cfg.segVerticalBand        = [0.10 0.85];          % allowed centroid y-range (fraction)

% ---------------- Morphology ----------------
cfg.morphOpenRadius   = 5;    % removes thin spurs / small noise
cfg.morphMinObjectFrac = 0.005; % objects smaller than this (fraction) are removed
cfg.morphCloseRadius  = 12;   % bridges broken regions, smooths concavities
cfg.morphErodeRadius  = 3;    % erosion  + dilation = final boundary smoothing
cfg.morphDilateRadius = 3;
cfg.morphMaxLungs     = 2;    % keep the two largest regions (left + right lung)

% ---------------- Features ----------------
cfg.glcmNumLevels = 16;
cfg.glcmOffsets   = [0 1; -1 1; -1 0; -1 -1];  % 0, 45, 90, 135 degrees, distance 1
cfg.featureNames  = {'Mean', 'Std', 'Variance', 'Min', 'Max', 'Entropy', ...
                     'Skewness', 'Kurtosis', ...
                     'Contrast', 'Correlation', 'Energy', 'Homogeneity', ...
                     'LungAreaRatio'};

% ---------------- Machine learning ----------------
cfg.classNames      = {'Normal', 'Abnormal'};
cfg.positiveClass   = 'Abnormal';
cfg.testFraction    = 0.20;
cfg.randomSeed      = 42;
cfg.cvFolds         = 5;
cfg.svmKernel       = 'rbf';
cfg.svmBoxGrid      = [0.1 1 10 100];
cfg.svmScaleGrid    = [0.5 1 2 4 8];   % multiplied by sqrt(#features)
end
