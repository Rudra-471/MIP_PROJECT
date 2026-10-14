# Requirements

## To run the application (MATLAB)

| Requirement | Version / notes |
|---|---|
| MATLAB | **R2021a or newer** (the dashboard uses `uifigure`, `uigridlayout`, `uilabel` word wrap and edit-field placeholders) |
| Image Processing Toolbox | `rgb2gray`, `medfilt2`, `imgaussfilt`, `imhist`, `imadjust`, `stretchlim`, `histeq`, `adapthisteq`, `graythresh`, `imbinarize`, `adaptthresh`, `strel`, `imerode`, `imdilate`, `imopen`, `imclose`, `imfill`, `bwareaopen`, `imclearborder`, `bwconncomp`, `regionprops`, `graycomatrix`, `graycoprops`, `entropy` |
| Statistics and Machine Learning Toolbox | `fitcsvm`, `predict`, `compact`, `confusionmat`, `confusionchart` |
| Disk space | ~45 GB for the full NIH ChestX-ray14 image set, **or** ~4-5 GB for one image archive (enough for a 1,000-image experiment) |
| RAM | 8 GB is sufficient; images are processed one at a time |

No other toolboxes, no deep-learning frameworks and no internet services are
needed. `checkDependencies` verifies the licences and functions at start-up and
reports anything missing by name.

## To run the automated tests

* **MATLAB** (as above): `cd tests; runAllTests` — all tests, including the
  real-dashboard GUI test.
* **GNU Octave >= 8** with the `image` package (>= 2.14) and the `statistics`
  package (**>= 1.7.0**, which provides `fitcsvm`). Octave lacks a few Image
  Processing Toolbox functions; `tests/octave_compat/` supplies test-only
  equivalents, and `tests/ui_mock/` supplies headless stand-ins for the UI
  components (Octave has no `uifigure`). Octave cannot run the dashboard itself.

## Dataset

NIH ChestX-ray14 (not included, see `dataset/PLACE_DATASET_HERE.md`):
`Data_Entry_2017_v2020.csv` plus one or more `images_XXX` archives from
<https://nihcc.app.box.com/v/ChestXray-NIHCC>. Optional: `train_val_list.txt`
and `test_list.txt` (official patient-wise split).
