# Legacy files (previous iteration — not used)

These files are the **previous version** of the project and are kept only for
reference. They are **not on the MATLAB path** and are not called by the current
application (`setupProject` does not add this folder).

The previous version used two GitHub COVID-era datasets organised as
`dataset/Normal` / `dataset/Abnormal` folders, an image-level stratified split,
a Platt-scaled "confidence" output and a light, tab-based GUI. It was replaced
because the current specification requires the NIH ChestX-ray14 dataset,
patient-wise splitting, validation-based model selection, no confidence
percentages without validated calibration, and a new dashboard.

`legacy/results/` contains that version's results. They were produced by a
different pipeline on a different dataset (with GNU Octave) and say nothing
about the current model.

This folder can be deleted safely; it is also preserved in the git history.
