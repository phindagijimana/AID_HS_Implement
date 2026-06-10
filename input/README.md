# Input data (BIDS)

Place T1w MRI data here in [BIDS format](https://bids.neuroimaging.io/).

Expected layout:

```text
input/
  bids_config.json
  dataset_description.json
  demographics_file.csv
  sub-<subject_id>/
    anat/
      sub-<subject_id>_T1w.nii.gz
```

Copy the example JSON files and edit `demographics_file.csv` before running `./aid start`.
