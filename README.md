# AID-HS Production Pipeline

Self-contained wrapper for [AID-HS](https://aid-hs.readthedocs.io/en/latest/index.html) with a simple CLI. Works on **Linux with Docker** and on **HPC with Singularity/Apptainer**.

All data, outputs, and the license file live **in this directory** (no external `aidhs_data` path required).

## Quick start

```bash
# 1. Place your license in the pipeline root
cp /path/from/email/aidhs_license.txt ./aidhs_license.txt

# 2. Install (auto-detects Docker vs Singularity)
chmod +x aid lib/*.sh
./aid install

# 3. Prepare input (BIDS + demographics)
cp demographics_file.csv.example input/demographics_file.csv
# Edit CSV and add MRI under input/sub-<id>/anat/

# 4. Run pipeline (background)
./aid start -id sub-patient01 -demos input/demographics_file.csv

# 5. Monitor / stop
./aid logs
./aid stop
```

## CLI

| Command | Description |
|---------|-------------|
| `./aid install` | Pull/build container, download models, run `pytest` |
| `./aid start` | Run prediction or harmonisation (background) |
| `./aid stop` | Stop background job |
| `./aid logs` | Tail `logs/run.log` (or `logs/install.log`) |
| `./aid status` | Install state, runtime, PID |

```bash
./aid install --help
./aid start --help
```

### Install options

```bash
./aid install --runtime singularity    # Force HPC backend
./aid install --runtime docker         # Force Docker
./aid install --no-gpu                 # Mac / CPU-only
./aid install --skip-test              # Skip pytest (faster)
```

On HPC, if the image build runs out of disk space in `$HOME`:

```bash
export SINGULARITY_CACHEDIR=/scratch/$USER/singularity-cache
export SINGULARITY_TMPDIR=/scratch/$USER/singularity-tmp
./aid install --runtime singularity
```

### Start examples

```bash
# Single subject, no harmonisation (Harmo code = noHarmo in CSV)
./aid start -id sub-patient01 -demos input/demographics_file.csv

# With harmonisation code H1
./aid start -id sub-patient01 -demos input/demographics_file.csv -harmo_code H1

# Multiple subjects in parallel
./aid start -ids input/subjects_list.txt -demos input/demographics_file.csv --parallelise

# Harmonisation-only (≥20 controls, same scanner)
./aid start -ids input/controls_list.txt -demos input/demographics_file.csv \
  -harmo_code H1 --harmo_only

# Foreground (e.g. interactive debugging)
./aid start -id sub-test001 -demos input/demographics_file.csv --foreground
```

## Directory layout

```text
AID-HS/                      ← pipeline root (mounted as /data in container)
├── aid                      ← CLI entrypoint
├── aidhs_license.txt        ← required license
├── input/                   ← BIDS MRI, bids_config.json, demographics CSV
├── output/                  ← symlink/target for reports (AID-HS also writes under input/output/)
├── logs/
│   ├── install.log
│   └── run.log
├── .aid/
│   ├── config.env           ← runtime settings after install
│   └── aidhs.sif            ← Singularity image (HPC only)
├── compose.yml              ← generated on install (Docker)
└── lib/                     ← implementation scripts
```

AID-HS writes prediction reports under `output/predictions_reports/<subject>/` (inside the container mount). See [interpret results](https://aid-hs.readthedocs.io/en/latest/interpret_results.html).

## Runtime selection

| Environment | Auto-detect | Force |
|-------------|-------------|--------|
| Linux workstation | Docker (if daemon available) | `./aid install --runtime docker` |
| HPC cluster | Apptainer → Singularity | `./aid install --runtime apptainer` |

Set `AID_RUNTIME` in the environment before `install` to persist in `.aid/config.env`.

## Slurm example (HPC)

```bash
#!/bin/bash
#SBATCH --job-name=aidhs
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00

cd /path/to/AID-HS
export SINGULARITY_CACHEDIR=/scratch/$USER/sing-cache

./aid start -id sub-patient01 -demos input/demographics_file.csv
# Or run install+start in one batch job on a fresh node:
# ./aid install --runtime singularity --skip-test
# ./aid start ...
```

## Requirements

- **License**: [AID-HS registration](https://docs.google.com/forms/d/e/1FAIpQLSdPbtraBZ2s0HD1W8qtF11wr_fYVTWZjraED03Rtl2ZjxeRMA/viewform) → `aidhs_license.txt`
- **Disk**: ~20 GB for container image + ~1 GB for models/data
- **Data**: 3T T1w BIDS; age and sex per subject ([prepare data](https://aid-hs.readthedocs.io/en/latest/prepare_data.html))

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Not installed` | `./aid install` |
| License errors | Ensure `aidhs_license.txt` is in pipeline root |
| HippUnfold killed (~19%) | Increase Docker memory; `./aid stop` then retry |
| Singularity no space | Set `SINGULARITY_CACHEDIR` / `SINGULARITY_TMPDIR` |
| Stale run PID | `./aid stop --force` |

See [AID-HS.md](./AID-HS.md) and [official FAQs](https://aid-hs.readthedocs.io/en/latest/FAQs.html).

## Citation

Ripart et al. 2024, *Annals of Neurology*. https://doi.org/10.1002/ana.27089

## License

This repository (CLI wrapper, Slurm helpers, and documentation) is licensed under the
[Apache License 2.0](LICENSE).

AID-HS itself is a separate software package with its own license terms. Use of AID-HS
requires a valid `aidhs_license.txt` from the AID-HS authors; that file is not
redistributed here.

## Publishing to GitHub

Install git hooks once (removes accidental Cursor co-author trailers):

```bash
./scripts/setup-git-hooks.sh
```

Initial push (or re-push after a clean history rewrite):

```bash
git remote add origin git@github.com:phindagijimana/AID_HS_Implement.git
git branch -M main
git push -u origin main
```

Commits should be authored by you only — do not include `Co-authored-by: Cursor` in messages.
