# Results

This folder is empty until you train a model. **No evaluation results are
included in the repository**, because no model has been trained on the NIH
ChestX-ray14 dataset in this repository yet.

Each training run (`runTrainingWorkflow` or *Start Training* in the dashboard)
creates `results/evaluation_<yyyymmdd_HHMMSS>/` with:

| File | Content |
|---|---|
| `metrics.txt` | human-readable summary: model, split, metrics, confusion matrix, notes |
| `metrics.csv` | accuracy, precision, sensitivity, specificity, F1, balanced accuracy, TP/TN/FP/FN |
| `confusion_matrix.csv` | rows = dataset label, columns = prediction |
| `test_predictions.csv` | every held-out test image: patient, dataset label, prediction, uncalibrated SVM score |
| `dataset_split.csv` | every selected image with patient ID, view, split and labels |
| `skipped_images.csv` | images excluded during feature extraction (e.g. failed segmentation) and why |

Analysis reports exported from the Image Analysis page are suggested to be
saved here as well.

All results are for educational and research purposes only and are not a
medical diagnosis.
