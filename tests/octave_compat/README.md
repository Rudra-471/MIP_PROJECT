# Octave compatibility shims (TEST USE ONLY)

The project targets **MATLAB** (Image Processing Toolbox + Statistics and
Machine Learning Toolbox). These files are *not* used when the project runs in
MATLAB — they are added to the path only by `tests/runOctaveValidation.m` so the
pipeline can be exercised automatically with GNU Octave on machines without a
MATLAB licence.

They re-implement the following MATLAB functions that are missing (or have a
different signature) in Octave's `image` package, following MATLAB's documented
behaviour as closely as practical:

| Shim | MATLAB function | Notes |
|---|---|---|
| `imgaussfilt.m` | `imgaussfilt` | Gaussian kernel of size `2*ceil(2*sigma)+1`, replicate padding |
| `imbinarize.m` | `imbinarize` | global (Otsu) or element-wise threshold |
| `adaptthresh.m` | `adaptthresh` | Bradley local-mean method, `ForegroundPolarity`, `NeighborhoodSize` |
| `adapthisteq.m` | `adapthisteq` | CLAHE, uniform distribution, bilinear tile interpolation |
| `graycomatrix.m` | `graycomatrix` | MATLAB name/value API, NaN pixels ignored |
| `graycoprops.m` | `graycoprops` | Contrast, Correlation, Energy, Homogeneity |

Numerical results in MATLAB will therefore differ slightly from the reference
results produced with Octave (see `results/README.md`).
