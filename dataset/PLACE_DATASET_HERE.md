# Place the NIH ChestX-ray14 dataset here (or anywhere else)

The dataset is **not** included (≈45 GB) and is never downloaded automatically.
You can put it in this folder or in any other folder and select that folder on
the **Dataset & Training** page.

## 1. Download

From the official NIH Clinical Center page
<https://nihcc.app.box.com/v/ChestXray-NIHCC> download:

| File | Needed? | Size |
|---|---|---|
| `Data_Entry_2017_v2020.csv` | **required** (labels, patient IDs, view position) | 9 MB |
| `images_001.tar.gz` … `images_012.tar.gz` | at least one (≈5,000–10,000 images each) | 2–4.5 GB each |
| `train_val_list.txt`, `test_list.txt` | optional – official patient-wise split | < 2 MB |

One archive is enough for the default 1,000-image experiment; `images_001`
contains about 5,000 images of ~1,300 patients. More archives give the
sampler more choice (more patients, better class balance in each split).

## 2. Extract

Extract everything into one folder. The application searches sub-folders, so
the archive layout can stay as it is:

```text
dataset/                       <- select this folder in the app
├── Data_Entry_2017_v2020.csv
├── train_val_list.txt         (optional)
├── test_list.txt              (optional)
├── images_001/
│   └── images/
│       ├── 00000001_000.png
│       └── ...
└── images_002/
    └── images/ ...
```

## 3. Use

`main` → **Dataset & Training** → *Browse* (select the folder) → *Scan &
Validate Dataset* → *Start Training*.

Labels: `No Finding` → Normal, any of the 14 findings → Abnormal. The labels
were mined from radiology reports by NLP; they are imperfect reference labels,
not clinical ground truth.

Citation: X. Wang et al., "ChestX-ray8: Hospital-scale Chest X-ray Database and
Benchmarks on Weakly-Supervised Classification and Localization of Common Thorax
Diseases", IEEE CVPR 2017. Please follow the NIH terms of use.
