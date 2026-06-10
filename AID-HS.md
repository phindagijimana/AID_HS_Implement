# AID-HS Installation Guide

> **Production CLI:** This repository includes `./aid` for install/start/stop/logs on Docker (Linux) or Singularity (HPC), with all data in one folder. See [README.md](./README.md) and the full [USER_GUIDE.md](./USER_GUIDE.md).

**Automated and Interpretable Detection of Hippocampal Sclerosis**

AID-HS extracts hippocampal volume- and surface-based features from T1w scans using [HippUnfold](https://hippunfold.readthedocs.io/en/latest/), characterizes hippocampal abnormalities, and automates detection and lateralization of hippocampal sclerosis (HS).

| Resource | Link |
|----------|------|
| Full documentation | [aid-hs.readthedocs.io](https://aid-hs.readthedocs.io/en/latest/index.html) |
| GitHub releases | [MELDProject/AID-HS releases](https://github.com/MELDProject/AID-HS/releases/latest) |
| Manuscript | [Ripart et al. 2024, Annals of Neurology](https://doi.org/10.1002/ana.27089) |
| Installation video (Docker/Singularity) | [YouTube tutorial](https://www.youtube.com/watch?v=RRAET7r05ys&t=11s) |

> **Note:** For AID-HS > v1.1.0, follow the online/GitHub guidelines rather than older video steps.

---

## Overview

### What you need before installing

- **License** — Required for v1.1.0 and above ([registration form](https://docs.google.com/forms/d/e/1FAIpQLSdPbtraBZ2s0HD1W8qtF11wr_fYVTWZjraED03Rtl2ZjxeRMA/viewform?usp=header))
- **Disk space** — ~20 GB for the container image (~18 GB image: Miniconda 3, HippUnfold v1.1.0, AID-HS) plus ~1 GB for data/models after setup
- **Patient data (later)** — T1w MRI in BIDS format; age at scan and sex for each subject
- **Scanner** — Developed and evaluated on **3T** T1w; not thoroughly evaluated on 1.5T or 7T

### Installation options

| Method | Best for | HPC support |
|--------|----------|-------------|
| **Docker** (recommended) | Linux, Windows; easiest setup | No — Docker typically unavailable on HPC |
| **Singularity / Apptainer** | HPC clusters (Linux) | Yes |
| **Native** | Ubuntu 18.04 (tested) | **Not supported** |

### Pipeline workflow (after install)

1. [Prepare data](https://aid-hs.readthedocs.io/en/latest/prepare_data.html) (BIDS + demographics)
2. *(Optional)* [Harmonisation](https://aid-hs.readthedocs.io/en/latest/harmonisation.html) — once per scanner/sequence (≥20 controls recommended)
3. [Run prediction](https://aid-hs.readthedocs.io/en/latest/run_prediction_pipeline.html)
4. [Interpret results](https://aid-hs.readthedocs.io/en/latest/interpret_results.html)

**Harmonisation:** Removes scanner-related bias so normative growth curves are interpretable. The pipeline can run **without** harmonisation with no drop in HS detection performance, but feature characterization vs. normative curves may not be interpretable.

---

## License (required for v1.1.0+)

1. Complete the [AID-HS registration form](https://docs.google.com/forms/d/e/1FAIpQLSdPbtraBZ2s0HD1W8qtF11wr_fYVTWZjraED03Rtl2ZjxeRMA/viewform?usp=header).
2. You will receive `aidhs_license.txt` by email after review.
3. Place `aidhs_license.txt` in your extracted AID-HS release folder (same directory as `compose.yml` for Docker).

---

## Common setup (all methods)

1. Download `aidhs.zip` from the [latest GitHub release](https://github.com/MELDProject/AID-HS/releases/latest) and extract it.
2. Copy `aidhs_license.txt` into the extracted folder.
3. Create an **aidhs_data** folder where MRI data and pipeline outputs will live.
4. Download the pretrained model and configure paths (method-specific commands below).

---

## Docker installation (recommended)

Tested on **Linux** and **Windows**. All prerequisites are embedded in the image.

### Prerequisites

**Docker**

```bash
docker --version
```

If not installed: [Docker Engine install guide](https://docs.docker.com/engine/install/).

**GPU (optional but recommended)** — Speeds HippUnfold segmentation.

Install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

### Configure `compose.yml`

Edit `compose.yml` in the AID-HS folder:

1. Set the volume bind to your **aidhs_data** path (keep `:/data` at the end):

```yaml
volumes:
  - /path/to/aidhs-data:/data
```

**Windows** — use forward slashes and quotes:

```yaml
volumes:
  - "C:/Users/John/Desktop/aidhs-data:/data"
```

2. **No GPU** (e.g. Mac laptop) — remove the entire `deploy:` block (lines through `secrets:` under `deploy`). Example minimal service:

```yaml
services:
  aidhs:
    image: meldproject/aidhs:latest
    platform: "linux/amd64"
    volumes:
      - /path/to/aidhs-data:/data
    environment:
      - AIDHS_LICENSE=/run/secrets/aidhs_license.txt
    secrets:
      - aidhs_license.txt
    user: $DOCKER_USER

secrets:
  aidhs_license.txt:
    file: ./aidhs_license.txt
```

3. **Docker Desktop** — set memory to the maximum allowed; default limits often cause HippUnfold/nnUNet to be killed ([Stack Overflow: Docker memory limit](https://stackoverflow.com/questions/43460770/docker-windows-container-memory-limit)).

### Download image and prepare data paths

**Linux:**

```bash
DOCKER_USER="$(id -u):$(id -g)" docker compose run aidhs python scripts/new_patient_pipeline/prepare_aidhs.py
```

**Windows:**

```bash
docker compose run aidhs python scripts/new_patient_pipeline/prepare_aidhs.py
```

### Verify installation

May take up to ~1 hour to pull the image; the test run takes ~1 minute.

**Linux:**

```bash
DOCKER_USER="$(id -u):$(id -g)" docker compose run aidhs pytest
```

**Windows / Mac:**

```bash
docker compose run aidhs pytest
```

**Save test logs on failure:**

```bash
# Linux
DOCKER_USER="$(id -u):$(id -g)" docker compose run aidhs pytest -s | tee pytest_errors.log

# Windows / Mac
docker compose run aidhs pytest -s | tee pytest_errors.log
```

### Enable GPU in Docker

In `compose.yml`, set `count: all` under `deploy.resources.reservations.devices`:

```yaml
deploy:
  resources:
    reservations:
      devices:
        - capabilities: [gpu]
          count: all
```

To disable GPUs, set `count: 0` or remove the `deploy` block entirely.

---

## Singularity / Apptainer installation (HPC)

Use this on **High Performance Computing** systems where Docker is not available. The image is built from the Docker image `meldproject/aidhs:latest`.

### Prerequisites

```bash
singularity --version
# or
apptainer --version
```

If missing: [Singularity installation guide](https://docs.sylabs.io/guides/3.0/user-guide/installation.html).

### Build the image (~20 GB)

```bash
singularity build aidhs.sif docker://meldproject/aidhs:latest
```

**Out of disk space during build?** Set cache/temp to a location with space ([FAQ](https://aid-hs.readthedocs.io/en/latest/FAQs.html#issue-with-singularity-not-enough-space-when-with-creating-the-sif)):

```bash
export SINGULARITY_CACHEDIR=/path/with/space/cache
export SINGULARITY_TMPDIR=/path/with/space/tmp
# Apptainer:
export APPTAINER_CACHEDIR=/path/with/space/cache
export APPTAINER_TMPDIR=/path/with/space/tmp
```

### Bind paths and license

Replace `/path/to/aidhs-data` and `/path/to/aidhs_license.txt` with your actual paths.

**Singularity:**

```bash
export SINGULARITY_BINDPATH=/path/to/aidhs-data:/data,/path/to/aidhs_license.txt:/aidhs_license.txt:ro
export SINGULARITYENV_AIDHS_LICENSE=/aidhs_license.txt
```

**Apptainer:**

```bash
export APPTAINER_BINDPATH=/path/to/aidhs-data:/data,/path/to/aidhs_license.txt:/aidhs_license.txt:ro
export APPTAINERENV_AIDHS_LICENSE=/aidhs_license.txt
```

Add these to `~/.bashrc` to persist across sessions.

### Prepare data paths and download model

```bash
singularity exec aidhs.sif /bin/bash -c "cd /app && python scripts/new_patient_pipeline/prepare_aidhs.py"
```

### Verify installation

```bash
singularity exec aidhs.sif /bin/bash -c "cd /app && pytest"
```

**Save test logs:**

```bash
singularity exec aidhs.sif /bin/bash -c "cd /app && pytest -s | tee pytest_errors.log"
```

### Run pipeline on HPC (example)

Mount data before each run:

```bash
export APPTAINER_BINDPATH=/path/to/aidhs-data:/data
singularity exec aidhs.sif /bin/bash -c "cd /app && python scripts/new_patient_pipeline/new_patient_pipeline.py -id sub-test001 -demos demographics_file.csv"
```

---

## Native installation (not supported)

Tested on **Ubuntu 18.04** only. The team recommends Docker if you hit issues.

### Prerequisites

- [Anaconda](https://docs.anaconda.com/anaconda/install)
- [HippUnfold v1.1.0](https://github.com/khanlab/hippunfold/releases/tag/v1.1.0)
- [Connectome Workbench](https://www.humanconnectome.org/software/get-connectome-workbench)

### Install

```bash
cd aidhs
conda env create -f environment.yml
conda activate aidhs
pip install -e .
```

### Prepare paths and model

```bash
python prepare_aidhs.py
```

Answer `y` when asked to change the data folder path, then provide your **aidhs_data** directory.

### Verify

```bash
cd aidhs
pytest
```

For license issues on native installs, export manually:

```bash
export AIDHS_LICENSE=/path/to/aidhs_license.txt
```

---

## Post-installation: quick reference

### Prepare data (summary)

- Organize MRI in **BIDS** format under `aidhs_data/input/`
- Required JSON files in `input/`: `bids_config.json`, `dataset_description.json`
- Template and examples: [figshare aidhs_data](https://figshare.com/s/48c92b1b53f8f0c67dec)
- `demographics_file.csv` columns: `ID`, `Harmo code`, `Group`, `Age at preoperative`, `Sex` (and `Scanner` for prediction: `3T` or `15T`)
- Use `noHarmo` in `Harmo code` if not harmonising

See [prepare data guidelines](https://aid-hs.readthedocs.io/en/latest/prepare_data.html).

### Run prediction (Docker Linux example)

```bash
cd /path/to/extracted/aidhs
DOCKER_USER="$(id -u):$(id -g)" docker compose run aidhs \
  python scripts/new_patient_pipeline/new_patient_pipeline.py \
  -id sub-test001 -demos demographics_file.csv
```

With harmonisation code `H1`:

```bash
DOCKER_USER="$(id -u):$(id -g)" docker compose run aidhs \
  python scripts/new_patient_pipeline/new_patient_pipeline.py \
  -id sub-test001 -harmo_code H1 -demos demographics_file.csv
```

Reports are written to `output/predictions_reports/<subject>/`.

### Harmonisation (optional, once per scanner)

- ≥20 controls (or patients without hippocampal abnormalities), same scanner and T1 sequence
- Do not use HS patients for harmonisation
- Choose a code starting with `H` (e.g. `H1`; avoid underscores)
- Non-zero age variance required (Combat will fail otherwise)

```bash
# Docker Linux example
DOCKER_USER="$(id -u):$(id -g)" docker compose run aidhs \
  python scripts/new_patient_pipeline/new_patient_pipeline.py \
  -harmo_code H1 -ids subjects_list.txt -demos demographics_file.csv --harmo_only
```

Parameters are saved as `AIDHS_combat_parameters.hdf5` under `output/preprocessed_surf_data/AIDHS/<harmo_code>/`.

---

## Troubleshooting

| Issue | Likely cause | Action |
|-------|----------------|--------|
| `AIDHS_LICENSE` not set | Env var missing | Docker: check `compose.yml` secrets; Native/Singularity: export `AIDHS_LICENSE` |
| `aidhs_license.txt` does not exist | Missing or wrong path | Register and place file in aidhs folder |
| License ID incorrect | Wrong file | Re-request via [registration form](https://docs.google.com/forms/d/e/1FAIpQLSdPbtraBZ2s0HD1W8qtF11wr_fYVTWZjraED03Rtl2ZjxeRMA/viewform?usp=header) |
| Singularity build: no space | Default cache in `$HOME` | Set `SINGULARITY_CACHEDIR` / `SINGULARITY_TMPDIR` |
| HippUnfold killed ~19% | Memory limit | Increase Docker Desktop memory; delete `output/hippunfold_outputs/` and rerun |
| Orphan containers warning | Old compose runs | `docker compose down --remove-orphans` |

Full list: [FAQs](https://aid-hs.readthedocs.io/en/latest/FAQs.html).

### Updating to v1.1.0+

- Register for license; copy `compose.yml`, `config.ini`, and `aidhs_license.txt` to new release
- **Docker:** `docker pull meldproject/aidhs:latest`
- **Singularity:** rebuild from `docker://meldproject/aidhs:latest`
- **Native:** `pip install -e .` in new directory after `conda activate aidhs`
- Re-run `pytest` to verify

---

## Disclaimer

AID-HS is for **research purposes only**. It has not been reviewed or approved by MHRA, EMA, or other regulatory agencies. Clinical use is at the user's sole risk. There is no warranty that the software will produce useful results.

---

## Citation

If you use AID-HS, please cite:

> Ripart et al. 2024. “Automated and Interpretable Detection of Hippocampal Sclerosis in Temporal Lobe Epilepsy: AID-HS.” *Annals of Neurology*. https://doi.org/10.1002/ana.27089

---

## Contact

| | |
|--|--|
| MELD project | meld.study@gmail.com |
| Mathilde Ripart, PhD (UCL) | m.ripart@ucl.ac.uk |

For installation errors, email with your OS, install method, and `pytest_errors.log` if available.
