# AID-HS User Guide

Complete guide for this repository’s production wrapper around [AID-HS](https://aid-hs.readthedocs.io/en/latest/index.html). For a one-page overview, see [README.md](./README.md).

| Resource | Link |
|----------|------|
| Official AID-HS docs | [aid-hs.readthedocs.io](https://aid-hs.readthedocs.io/en/latest/index.html) |
| Upstream install mirror | [AID-HS.md](./AID-HS.md) |
| Paper | [Ripart et al. 2024](https://doi.org/10.1002/ana.27089) (`reference/` PDF) |
| GitHub (wrapper) | [AID_HS_Implement](https://github.com/phindagijimana/AID_HS_Implement) |

---

## What this pipeline does

AID-HS takes a **3T T1w** scan and:

1. Segments the hippocampus (**HippUnfold**)
2. Extracts volume and surface features (thickness, gyrification, curvature)
3. Compares features to **normative growth charts** and **left–right asymmetry**
4. Runs a **logistic regression classifier** → left HS, right HS, or no asymmetry
5. Writes an **interpretable PDF report** per subject

**Research use only** — not a clinical device. See the paper disclaimer in `reference/`.

---

## Requirements

### Software

| Component | Workstation | HPC (Slurm) |
|-----------|-------------|-------------|
| Container runtime | Docker | Apptainer or Singularity |
| Orchestration (optional) | `./aid start` | `./aid cohort slurm` (Snakemake 8+) |
| Python | — | ≥ 3.11 for Snakemake (`aidhs_py/scripts/setup_env.sh`) |

### Data per subject

| File | Description |
|------|-------------|
| T1w NIfTI | BIDS layout: `input/sub-<id>/anat/sub-<id>_T1w.nii.gz` (or `ses-*` variant) |
| `input/bids_config.json` | Maps T1 entity (copy from `.example`; see [BIDS config](#bids-config-and-sessions)) |
| `input/dataset_description.json` | BIDS dataset metadata |
| Demographics row | Age (years), sex (`male`/`female`), group, scanner (`3T`), Harmo code |

Demographics CSV columns:

```csv
ID,Harmo code,Group,Age at preoperative,Sex,Scanner
sub-example001,noHarmo,patient,45,male,3T
```

Use `noHarmo` when not running harmonisation. Real age and sex matter for normative charts.

### License

1. [Register](https://docs.google.com/forms/d/e/1FAIpQLSdPbtraBZ2s0HD1W8qtF11wr_fYVTWZjraED03Rtl2ZjxeRMA/viewform)
2. Save email attachment as `aidhs_license.txt` in the pipeline root (never commit)

---

## Installation

From the pipeline root:

```bash
chmod +x aid lib/*.sh
./aid install --runtime apptainer    # HPC
./aid install --runtime docker       # workstation
./aid status
```

### Install options

```bash
./aid install --runtime singularity|apptainer|docker|auto
./aid install --no-gpu               # CPU-only (slower HippUnfold)
./aid install --skip-test            # Skip pytest (faster)
```

### HPC disk space

The Apptainer image is ~20 GB. If `$HOME` quota is tight:

```bash
export APPTAINER_CACHEDIR=/scratch/$USER/apptainer-cache
export APPTAINER_TMPDIR=/scratch/$USER/apptainer-tmp
export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"
./aid install --runtime apptainer
```

Cache and tmp default to `.aid/cache` and `.aid/tmp` under the pipeline root.

### Runtime selection

| Environment | Auto-detect | Force |
|-------------|-------------|--------|
| Linux + Docker daemon | Docker | `AID_RUNTIME=docker ./aid install` |
| HPC | Apptainer → Singularity | `AID_RUNTIME=apptainer ./aid install` |

Settings persist in `.aid/config.env` after install.

---

## Directory layout

```text
AID-HS/                          ← mounted as /data in container
├── aid                          ← CLI entrypoint
├── aidhs_license.txt            ← required (gitignored)
├── input/
│   ├── bids_config.json
│   ├── dataset_description.json
│   └── sub-<id>/anat/*_T1w.nii.gz
├── output/
│   ├── predictions_reports/<id>/Report_<id>.pdf
│   ├── hippunfold_outputs/
│   └── …
├── logs/
├── .aid/
│   ├── config.env
│   ├── aidhs.sif                ← Apptainer image
│   ├── cache/ tmp/
├── aidhs_py/                    ← Snakemake cohort workflow
├── jobs/                        ← optional site Slurm scripts
├── lib/                         ← CLI implementation
└── templates/
```

---

## Preparing input

### BIDS layout

```text
input/
  bids_config.json
  dataset_description.json
  sub-<subject_id>/
    anat/
      sub-<subject_id>_T1w.nii.gz
```

Or with sessions:

```text
input/sub-<id>/ses-1/anat/sub-<id>_ses-1_T1w.nii.gz
```

Copy examples:

```bash
cp input/bids_config.json.example input/bids_config.json
cp input/dataset_description.json.example input/dataset_description.json
cp demographics_file.csv.example input/demographics_file.csv
```

### BIDS config and sessions

In `input/bids_config.json`, the `session` field is the **pybids label without the `ses-` prefix**:

| Folder | `"session"` in bids_config |
|--------|---------------------------|
| `sub-001/anat/…` (no ses) | `null` |
| `sub-001/ses-1/anat/…` | `"1"` |

Wrong session values cause “T1 not found” errors inside the container.

### External BIDS (symlinks)

Point to an external dataset instead of copying data:

```bash
ln -sfn /path/to/BIDS/sub-001 input/sub-001
```

On Apptainer, bind the external root (see site configs in `jobs/*/config.env` or `aidhs_py` `bids_root`).

---

## Single-subject runs (`./aid start`)

### Basic

```bash
./aid start -id sub-patient01 -demos input/demographics_file.csv
./aid logs
./aid stop
```

### Options

```bash
# Foreground (Slurm or debugging)
./aid start -id sub-001 -demos input/demographics_file.csv --foreground

# Multiple subjects (same container; HippUnfold may lock on HPC)
./aid start -ids list_subjects.txt -demos input/demographics_file.csv

# Harmonisation code
./aid start -id sub-001 -demos … -harmo_code H1

# Harmonisation-only (≥20 controls, same scanner)
./aid start -ids controls.txt -demos … -harmo_code H1 --harmo_only

# Re-run prediction after segmentation exists
./aid start -id sub-001 -demos … --skip_segmentation
```

### Slurm (single subject)

```bash
#!/bin/bash
#SBATCH --job-name=aidhs
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=general

cd /path/to/AID-HS
export PYTHONNOUSERSITE=1
export AID_PIPELINE_ROOT="$PWD"

./aid start -id sub-patient01 -demos input/demographics_file.csv --foreground
```

Request **64G RAM** for HippUnfold/nnUNet on HPC.

---

## Snakemake cohort runs

Recommended for **multi-subject production** on Slurm. Implemented in `aidhs_py/` and exposed via **`./aid cohort`**.

### Setup

```bash
./aid install --runtime apptainer
./aid cohort setup

# Edit local (gitignored) files:
#   aidhs_py/config/subjects.tsv
#   aidhs_py/config/demographics_file.csv
# Optional cohort override:
#   cp aidhs_py/config/cohorts/cidur.yaml.example aidhs_py/config/cohorts/cidur.yaml
```

### Snakemake install

System Python 3.9 often cannot install Snakemake 8. Use one of:

```bash
# Conda/mamba (recommended)
aidhs_py/scripts/setup_env.sh
conda activate aidhs_py

# Or user Python 3.12
PYTHONNOUSERSITE=0 python3.12 -m pip install --user \
  'snakemake>=8' snakemake-executor-plugin-slurm
```

### Cohort commands

```bash
./aid cohort setup       # copy example configs
./aid cohort subjects    # build subjects.tsv from input/ BIDS
./aid cohort lint        # dry-run DAG
./aid cohort run         # local debug (1 core)
./aid cohort slurm       # submit Slurm driver (production)
./aid cohort status      # validate flags + PDF status
```

With cohort config:

```bash
./aid cohort slurm --configfile aidhs_py/config/cohorts/cidur.yaml
```

### DAG

```text
  BIDS + demographics
         │
         ▼
  validate_inputs (optional)
         │
  harmonisation (optional, ≥20 controls)
         │
         ▼
  predict (serialized: hippunfold_slots=1)
         │
         ▼
  output/predictions_reports/sub-{sid}/Report_sub-{sid}.pdf
```

### Config (`aidhs_py/config/config.yaml`)

| Key | Purpose |
|-----|---------|
| `pipeline_root` | Parent dir (`..`) |
| `bids_root` | External BIDS for symlinks |
| `demographics` | CSV path (under `aidhs_py/config/`) |
| `subjects_tsv` | One subject ID per line |
| `run_harmonisation` | Cohort harmonisation pass |
| `skip_segmentation` | Use `run_pipeline_prediction.py` only |
| `hippunfold_slots` | Max concurrent predict jobs (default `1`) |
| `resources.*` | Per-rule `mem_mb`, `runtime`, `slurm_partition` |

### Stage toggles

| `run_harmonisation` | `skip_segmentation` | Pipeline |
|---------------------|---------------------|----------|
| false | false | validate → predict |
| false | true | validate → predict_only |
| true | false | harmonisation → validate → predict |
| true | true | harmonisation → validate → predict_only |

### Selective reruns

```bash
cd aidhs_py
snakemake -s Snakefile output/predictions_reports/sub-001/Report_sub-001.pdf
snakemake -s Snakefile validate_all
snakemake -s Snakefile -R predict --forcerun predict \
  output/predictions_reports/sub-001/Report_sub-001.pdf
```

### Direct Snakemake (without `./aid cohort`)

```bash
cd aidhs_py
make lint
sbatch submit_snakemake.sh --configfile config/cohorts/cidur.yaml
```

---

## Site-specific jobs

Legacy bash submit scripts coexist with `./aid cohort` for site-specific workflows.

### CIDUR (`jobs/cidur/`)

```bash
cp jobs/cidur/config.env.example jobs/cidur/config.env   # set CIDUR_BIDS
cp jobs/cidur/demographics_file.csv.example jobs/cidur/demographics_file.csv
cp jobs/cidur/subjects_list.txt.example jobs/cidur/subjects_list.txt
./jobs/cidur/submit.sh
```

Uses `input/bids_config.json` with `"session": "1"` for `ses-1` folders.

### URMC Test HS (`jobs/urmc_test/`)

```bash
cp jobs/urmc_test/config.env.example jobs/urmc_test/config.env   # set URMC_HS_ROOT
# Edit jobs/urmc_test/demographics_file.csv
./jobs/urmc_test/submit.sh
```

Uses flat BIDS (`session: null` in `jobs/urmc_test/bids_config.json`). Restores CIDUR session config before re-running CIDUR subjects.

### Slurm spool directory fix

Submit scripts must run with the pipeline as working directory:

```bash
sbatch --chdir="$PWD" --export=ALL,AID_PIPELINE_ROOT="$PWD" \
  --output="$PWD/logs/slurm-%x-%j.out" \
  --error="$PWD/logs/slurm-%x-%j.err" \
  jobs/.../run_subject.sh sub-XXX
```

---

## Harmonisation (optional)

Removes scanner/site bias for normative chart interpretation. Requires **≥20 controls** on the same scanner sequence.

1. Assign a Harmo code (e.g. `H1`) in demographics for all subjects
2. Run harmonisation once per code:

```bash
./aid start -ids controls_list.txt -demos … -harmo_code H1 --harmo_only
```

Or enable `run_harmonisation: true` in `aidhs_py` config.

Detection performance is similar with or without harmonisation; normative plots are more interpretable with harmonisation (see paper).

---

## Outputs and reports

Per subject:

```text
output/predictions_reports/<subject_id>/
├── Report_<subject_id>.pdf          ← main deliverable
├── predictions.csv                  ← features + classifier scores
├── normative_charts.png
├── abnormalities_directions.png
├── predictions_scores.png
├── hippo_segmentation.png
├── hippo_segmentation_dices.png
└── hippo_surfaces.png
```

### `predictions.csv` (key columns)

| Column | Meaning |
|--------|---------|
| `dice segmentation L/R hemi` | HippUnfold QC (≥ 0.7 is acceptable) |
| `score left HS` / `score right HS` / `score no asymmetry` | Classifier probabilities |
| `prediction` | `left HS`, `right HS`, or `no asymmetry` |

Interpret reports with clinical context — see [official guide](https://aid-hs.readthedocs.io/en/latest/interpret_results.html) and the paper (Figure 4).

---

## Reproducibility

Any Slurm user can reproduce the **workflow** by:

1. Cloning this repo
2. Obtaining their own `aidhs_license.txt`
3. Running `./aid install`
4. Configuring local subject/demographics files (from `.example` templates)
5. Running `./aid cohort slurm` or site submit scripts

**Not pinned today (identical outputs across sites):**

| Gap | Mitigation |
|-----|------------|
| Container `meldproject/aidhs:latest` | Pin digest in `.aid/config.env` / future config |
| Site Slurm partition/resources | Edit `aidhs_py/config/config.yaml` |
| Shared NFS `output/` | Use separate pipeline roots per project/user |
| Placeholder demographics | Always use real age/sex |

Sensitive paths and demographics are **gitignored**; only `.example` templates are in git.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Not installed` | No `.aid/config.env` | `./aid install` |
| License errors | Missing/invalid file | `aidhs_license.txt` in root |
| T1 not found | Wrong BIDS layout or session in `bids_config.json` | See [BIDS config](#bids-config-and-sessions) |
| HippUnfold lock / Snakemake LockException | Parallel subjects | Run sequentially (`hippunfold_slots: 1`) |
| nnUNet / numpy dtype error on HPC | Host `~/.local` Python | `export PYTHONNOUSERSITE=1` (set in our scripts) |
| HippUnfold killed ~19% | OOM | 64G RAM, `./aid stop` and retry |
| Apptainer no space | `$HOME` quota | Set `APPTAINER_CACHEDIR` to scratch |
| `mkdir logs: Permission denied` (Slurm) | Wrong job cwd | `--chdir="$PWD"` on sbatch |
| Snakemake not found | Old system Python | `aidhs_py/scripts/setup_env.sh` |
| Stale background PID | Crashed worker | `./aid stop --force` |

Logs:

```text
logs/install.log
logs/run.log
logs/run-<subject>.log
logs/AIDHS_pipeline_*.log
aidhs_py/logs/
```

Official FAQs: [aid-hs.readthedocs.io/FAQs](https://aid-hs.readthedocs.io/en/latest/FAQs.html)

---

## Git and publishing

Install hooks to strip accidental co-author trailers:

```bash
./scripts/setup-git-hooks.sh
```

Never commit: `aidhs_license.txt`, demographics with real IDs, `jobs/*/config.env`, cohort YAMLs, or MRI data (see `.gitignore`).

---

## Citation

> Ripart et al. 2024. “Automated and Interpretable Detection of Hippocampal Sclerosis in Temporal Lobe Epilepsy: AID-HS.” *Annals of Neurology*. https://doi.org/10.1002/ana.27089

## License

| Component | License |
|-----------|---------|
| This wrapper (CLI, Snakemake, docs) | [Apache 2.0](LICENSE) |
| AID-HS software | Separate MELD terms; requires `aidhs_license.txt` |

## Disclaimer

AID-HS is for **research purposes only**. Correlate outputs with clinical, EEG, and histopathology data before any clinical interpretation.
