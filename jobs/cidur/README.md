# CIDUR Slurm jobs

Per-site batch scripts for AID-HS. For full setup instructions see [USER_GUIDE.md](../../USER_GUIDE.md#site-specific-jobs).

## Setup (local only — gitignored)

```bash
cp jobs/cidur/config.env.example jobs/cidur/config.env
cp jobs/cidur/demographics_file.csv.example jobs/cidur/demographics_file.csv
cp jobs/cidur/subjects_list.txt.example jobs/cidur/subjects_list.txt
# Edit config.env: CIDUR_BIDS, subjects, demographics
```

Session: **ses-1** → `"session": "1"` in `input/bids_config.json`.

## Submit

```bash
./jobs/cidur/submit.sh
# Or one subject:
sbatch --chdir="$PWD" --export=ALL,AID_PIPELINE_ROOT="$PWD" \
  jobs/cidur/run_subject.sh sub-XXX
```

Reports: `output/predictions_reports/<subject_id>/Report_<subject_id>.pdf`

For production cohort runs, prefer `./aid cohort slurm` — see USER_GUIDE.
