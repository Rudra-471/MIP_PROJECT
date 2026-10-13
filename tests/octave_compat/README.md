# Octave compatibility shims (TEST USE ONLY)

The project targets **MATLAB** (Image Processing Toolbox + Statistics and
Machine Learning Toolbox). These files are *never* used in MATLAB: only
`tests/runAllTests.m` adds this folder to the path, and only under GNU Octave,
so the pipeline can be tested automatically on machines without a MATLAB
licence.

They re-implement MATLAB functions that are missing from (or differ in) Octave's
`image` package, following MATLAB's documented behaviour as closely as practical:

| Shim | MATLAB function | Notes |
|---|---|---|
| `imgaussfilt.m` | `imgaussfilt` | Gaussian kernel of size `2*ceil(2*sigma)+1`, replicate padding |
| `imbinarize.m` | `imbinarize` | global (Otsu) or element-wise threshold |
| `adaptthresh.m` | `adaptthresh` | Bradley local-mean method, `ForegroundPolarity`, `NeighborhoodSize` |
| `adapthisteq.m` | `adapthisteq` | CLAHE, uniform distribution, bilinear tile interpolation |
| `graycomatrix.m` | `graycomatrix` | MATLAB name/value API, NaN pixels ignored |
| `graycoprops.m` | `graycoprops` | Contrast, Correlation, Energy, Homogeneity |

Numerical results in MATLAB will therefore differ slightly from Octave runs.
Two further Octave limitations are handled in the code and documented there:
Octave's `fitcsvm` crashes when predicting a single row (`svmPredict.m`) and
Octave cannot reload a saved classifier object from a `.mat` file (the
corresponding test is reported as SKIPPED under Octave).
