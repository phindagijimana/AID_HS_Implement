# CIDUR AID-HS Slurm jobs

## Setup (local only — not committed)

```bash
cp jobs/cidur/config.env.example jobs/cidur/config.env
cp jobs/cidur/demographics_file.csv.example jobs/cidur/demographics_file.csv
cp jobs/cidur/subjects_list.txt.example jobs/cidur/subjects_list.txt
# Edit config.env: set CIDUR_BIDS to your BIDS root
# Edit demographics_file.csv with real age/sex per subject
# Edit subjects_list.txt with one subject ID per line
```

`config.env`, `demographics_file.csv`, and `subjects_list.txt` are **gitignored**.

Session used: **ses-1** (T1w). In `input/bids_config.json`, the session entity is `"1"` (pybids label without the `ses-` prefix).

## Submit

From the pipeline root:

```bash
./jobs/cidur/submit.sh
```

Or one subject:

```bash
sbatch --job-name=aidhs-sub-XXX jobs/cidur/run_subject.sh sub-XXX
```

## Outputs

Reports: `output/predictions_reports/<subject_id>/Report_<subject_id>.pdf`
