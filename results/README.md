# Results

Produced by `trainModel` + `demoPipeline` on the 270-image reference dataset
(see the main README, sections 4 and 12).

**Environment of these reference files: GNU Octave 8.4.0 + statistics 1.7.0
with the test-only shims in `tests/octave_compat/`** — not MATLAB. Running
`trainModel` in MATLAB overwrites the files in this folder with MATLAB results,
which will differ somewhat (different random split, MATLAB's own CLAHE /
adaptive threshold / GLCM implementations).

| File | Content |
|---|---|
| `metrics.txt` / `metrics.csv` | test-set and cross-validation metrics |
| `confusion_matrix.png` | test-set confusion matrix |
| `test_predictions.csv` | per-image prediction, P(Abnormal), SVM score |
| `cv_grid.csv` | hyper-parameter search (5-fold CV balanced accuracy) |
| `failed_images.csv` | images skipped during feature extraction (none) |
| `sample_output/` | step-by-step figures and reports for two test images |
| `source_controlled_actualmed_only/` | same pipeline trained/tested on single-hospital (Actualmed) images only – checks how much of the main result is due to dataset-source differences |

Educational / research use only — not a medical diagnosis.
