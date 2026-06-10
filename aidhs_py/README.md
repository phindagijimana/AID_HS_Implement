# AID-HS Snakemake workflow (`aidhs_py`)

Cohort-scale orchestration for [AID-HS](https://aid-hs.readthedocs.io/) on HPC. Wraps the
parent [`./aid`](../aid) Apptainer image with a declarative DAG, Slurm executor profile,
and sentinel-based resume.

The legacy bash jobs in [`../jobs/cidur/`](../jobs/cidur/) remain for side-by-side use.

## Directory layout

```text
aidhs_py/
├── Snakefile
├── Makefile
├── submit_snakemake.sh          ← sbatch driver
├── config/
│   ├── config.yaml              ← paths, toggles, per-rule resources
│   ├── subjects.tsv             ← canonical subject list (gitignored)
│   ├── demographics_file.csv    ← gitignored
│   └── cohorts/*.yaml           ← per-cohort overrides (gitignored)
├── profiles/slurm/config.yaml   ← Snakemake 8 Slurm executor
└── workflow/
    ├── rules/
    │   ├── common.smk
    │   ├── validate.smk
    │   ├── harmonisation.smk
    │   └── predict.smk
    └── scripts/
```

## DAG

```text
  BIDS sub-{sid}/ + demographics row
              │
              ▼
     ┌─────────────────┐
     │ validate_inputs │  (optional)
     └────────┬────────┘
              │
     ┌────────┴────────┐     optional cohort rule
     │  harmonisation  │  (≥20 controls, --harmo_only)
     └────────┬────────┘
              ▼
     ┌─────────────────┐
     │ predict         │  apptainer → new_patient_pipeline.py
     │ (serialized)    │  hippunfold_slots=1
     └────────┬────────┘
              ▼
  output/predictions_reports/sub-{sid}/Report_sub-{sid}.pdf
```

With `skip_segmentation: true`, the predict rule calls `run_pipeline_prediction.py` instead.

## Prerequisites

1. Parent pipeline installed:

   ```bash
   cd ..
   cp aidhs_license.txt.example aidhs_license.txt   # or your real license
   ./aid install --runtime apptainer
   ```

2. Snakemake 8 + Slurm executor:

   ```bash
   pip install 'snakemake>=8' snakemake-executor-plugin-slurm
   ```

3. Local config (gitignored):

   ```bash
   cp config/subjects.tsv.example config/subjects.tsv
   cp config/demographics_file.csv.example config/demographics_file.csv
   # Edit demographics with real age/sex per subject
   ```

4. BIDS input under `../input/sub-{sid}/anat/*_T1w.nii.gz`, or set `bids_root` in config
   to symlink external BIDS automatically.

## Quick start

From the pipeline root (recommended):

```bash
./aid cohort setup
./aid cohort subjects          # optional: discover subjects from BIDS
./aid cohort lint
./aid cohort slurm
./aid cohort status
```

Or directly from `aidhs_py/`:

```bash
make subjects && make lint && make slurm
sbatch submit_snakemake.sh --configfile config/cohorts/cidur.yaml
```

## Config highlights (`config/config.yaml`)

| Key | Purpose |
|-----|---------|
| `pipeline_root` | Parent AID-HS dir (`..`) |
| `bids_root` | External BIDS root for symlinks (optional) |
| `demographics` | CSV path (relative to `aidhs_py/`) |
| `subjects_tsv` | One subject ID per line |
| `run_harmonisation` | Cohort harmonisation pass |
| `skip_segmentation` | Re-run prediction only |
| `hippunfold_slots` | Max concurrent predict jobs (default `1`) |
| `resources.*` | Per-rule `mem_mb`, `runtime`, `slurm_partition` |

## Stage toggles

| `run_harmonisation` | `skip_segmentation` | Pipeline |
|---------------------|---------------------|----------|
| false | false | validate → predict |
| false | true | validate → predict_only |
| true | false | harmonisation → validate → predict |
| true | true | harmonisation → validate → predict_only |

## Selective runs

```bash
# One subject report
snakemake -s Snakefile output/predictions_reports/sub-001/Report_sub-001.pdf

# Validation only
snakemake -s Snakefile validate_all

# Force re-predict one subject (keeps other outputs)
snakemake -s Snakefile -R predict --forcerun predict \
  output/predictions_reports/sub-001/Report_sub-001.pdf
```

## Outputs

| Path | Description |
|------|-------------|
| `../output/predictions_reports/<sid>/Report_<sid>.pdf` | Final report |
| `.flags/validate.<sid>.done` | Validation sentinel |
| `.flags/harmonisation.<code>.done` | Harmonisation sentinel |
| `logs/*.log` | Per-rule logs |
| `.snakemake/slurm_logs/` | Slurm executor logs |

## Bash → Snakemake mapping

| Legacy (`jobs/cidur/`) | Snakemake |
|------------------------|-----------|
| `submit.sh` | `submit_snakemake.sh` + Slurm profile |
| `run_subject.sh` | `workflow/rules/predict.smk` |
| `clean_subject.sh` | `snakemake -R predict --forcerun predict` |
| `config.env` | `config/cohorts/*.yaml` |

## Notes

- Predict jobs are **serialized** (`hippunfold_slots: 1`) because HippUnfold uses a
  shared `.snakemake/locks` directory under `output/hippunfold_outputs/`.
- `PYTHONNOUSERSITE=1` is set in every container call (avoids host numpy breaking nnUNet).
- Demographics and subject lists are **gitignored** — use `.example` templates only in git.
