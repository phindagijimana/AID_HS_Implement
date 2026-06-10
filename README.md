# AID-HS Production Pipeline

Self-contained wrapper for [AID-HS](https://aid-hs.readthedocs.io/en/latest/index.html) — automated hippocampal sclerosis detection from **3T T1w** MRI. Runs on **Docker** (workstation) or **Apptainer/Singularity** (HPC).

Everything lives in one directory: license, input, output, container image, and logs.

**Full documentation:** [USER_GUIDE.md](./USER_GUIDE.md) · Official upstream: [AID-HS.md](./AID-HS.md)

---

## Requirements

| Item | Details |
|------|---------|
| **License** | [Register with MELD](https://docs.google.com/forms/d/e/1FAIpQLSdPbtraBZ2s0HD1W8qtF11wr_fYVTWZjraED03Rtl2ZjxeRMA/viewform) → save as `aidhs_license.txt` |
| **Disk** | ~20 GB (container) + ~1 GB (models) |
| **Data** | BIDS T1w + demographics CSV (age, sex per subject) |
| **HPC cohort runs** | Snakemake 8+ (Python ≥ 3.11) — see [USER_GUIDE.md](./USER_GUIDE.md#snakemake-cohort-runs) |

---

## Quick start

```bash
git clone git@github.com:phindagijimana/AID_HS_Implement.git
cd AID_HS_Implement

# 1. License + install
cp /path/from/email/aidhs_license.txt ./aidhs_license.txt
chmod +x aid lib/*.sh jobs/**/*.sh 2>/dev/null || true
./aid install --runtime apptainer    # HPC; use --runtime docker on workstation

# 2. One subject (interactive / debug)
cp demographics_file.csv.example input/demographics_file.csv
# Add MRI: input/sub-<id>/anat/sub-<id>_T1w.nii.gz
./aid start -id sub-patient01 -demos input/demographics_file.csv --foreground

# 3. Cohort on Slurm (recommended for multi-subject HPC)
./aid cohort setup
# Edit aidhs_py/config/subjects.tsv and demographics_file.csv
./aid cohort lint
./aid cohort slurm
./aid cohort status
```

---

## CLI

| Command | Purpose |
|---------|---------|
| `./aid install` | Build/pull container, download models, run pytest |
| `./aid start` | Run one or more subjects (background by default) |
| `./aid stop` | Stop background job |
| `./aid logs` | Tail run or install log |
| `./aid status` | Install state, license, runtime |
| `./aid cohort` | Snakemake cohort workflow (setup, lint, slurm, status) |

```bash
./aid install --help
./aid start --help
./aid cohort help
```

---

## Which command to use

| Goal | Command |
|------|---------|
| Test one subject locally | `./aid start -id sub-XXX -demos … --foreground` |
| Production cohort on Slurm | `./aid cohort slurm` |
| Per-site batch scripts | `jobs/<site>/submit.sh` — see [USER_GUIDE.md](./USER_GUIDE.md#site-specific-jobs) |

---

## Outputs

Reports and figures are written to:

```text
output/predictions_reports/<subject_id>/Report_<subject_id>.pdf
```

See [official interpret-results docs](https://aid-hs.readthedocs.io/en/latest/interpret_results.html) and [USER_GUIDE.md — Outputs](./USER_GUIDE.md#outputs-and-reports).

---

## Layout (minimal)

```text
AID-HS/
├── aid                    CLI
├── aidhs_license.txt      required (gitignored)
├── input/                 BIDS + demographics
├── output/                reports + intermediates
├── aidhs_py/              Snakemake cohort workflow
├── jobs/                  optional per-site Slurm helpers
├── .aid/aidhs.sif         container (after install)
└── logs/
```

---

## Troubleshooting (common)

| Problem | Fix |
|---------|-----|
| Not installed | `./aid install` |
| License error | `aidhs_license.txt` in pipeline root |
| Out of disk on HPC | `export APPTAINER_CACHEDIR=/scratch/$USER/apptainer-cache` then reinstall |
| HippUnfold fails ~19% | Request more RAM (64G); see USER_GUIDE |
| Snakemake not found | `aidhs_py/scripts/setup_env.sh` or Python 3.12 — see USER_GUIDE |

More: [USER_GUIDE.md — Troubleshooting](./USER_GUIDE.md#troubleshooting)

---

## Citation

Ripart et al. 2024, *Annals of Neurology*. https://doi.org/10.1002/ana.27089

## License

This wrapper is [Apache 2.0](LICENSE). AID-HS itself requires a separate [MELD license](https://aid-hs.readthedocs.io/en/latest/index.html) (`aidhs_license.txt`).
