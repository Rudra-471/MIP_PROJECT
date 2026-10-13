# NIH ChestX-ray14 sample images (test fixtures)

Two real, de-identified frontal chest radiographs from the **NIH ChestX-ray14**
dataset (Wang et al., CVPR 2017), as redistributed (downsampled from 1024x1024
to 512x512 grayscale PNG) in the test fixtures of the open-source [torchxrayvision](https://github.com/mlmed/torchxrayvision)
project (`tests/` folder). They are used by the automated tests and can be
opened in the application to try the single-image workflow.

| File | Finding Labels (official `Data_Entry_2017_v2020.csv`) | Binary reference label | View |
|---|---|---|---|
| `00000001_000.png` | Cardiomegaly | Abnormal | PA |
| `00027426_000.png` | No Finding | Normal | PA |

The labels are NLP-mined from radiology reports and are not clinical ground
truth. Two images are **not** a dataset: they cannot be used to train or
evaluate the classifier. Download the full dataset for that (see the main
README, "Dataset setup").

Source and citation: NIH Clinical Center, https://nihcc.app.box.com/v/ChestXray-NIHCC —
X. Wang, Y. Peng, L. Lu, Z. Lu, M. Bagheri, R. M. Summers, "ChestX-ray8:
Hospital-scale Chest X-ray Database and Benchmarks on Weakly-Supervised
Classification and Localization of Common Thorax Diseases", IEEE CVPR 2017.
