#!/usr/bin/env bash
# Create conda/mamba env for ./aid cohort (Snakemake 8 + Slurm executor).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${AIDHS_CONDA_ENV:-aidhs_py}"

if command -v mamba &>/dev/null; then
  MGR=mamba
elif command -v conda &>/dev/null; then
  MGR=conda
else
  echo "ERROR: mamba or conda required (system Python 3.9 cannot install Snakemake 8)." >&2
  echo "Install Miniforge: https://github.com/conda-forge/miniforge" >&2
  exit 1
fi

"${MGR}" env create -f "${ROOT}/environment.yml" -n "${ENV_NAME}" 2>/dev/null \
  || "${MGR}" env update -f "${ROOT}/environment.yml" -n "${ENV_NAME}" --prune

cat <<EOF

Environment '${ENV_NAME}' ready.

Activate before cohort commands:
  conda activate ${ENV_NAME}
  cd ${ROOT}/..
  ./aid cohort lint
  ./aid cohort slurm --configfile aidhs_py/config/cohorts/cidur.yaml

Or export for non-interactive Slurm:
  export AIDHS_CONDA_ENV=${ENV_NAME}
EOF
