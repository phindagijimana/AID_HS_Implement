#!/bin/bash
# Slurm driver for the AID-HS Snakemake workflow.
#
# Usage (from aidhs_py/):
#   sbatch submit_snakemake.sh
#   sbatch submit_snakemake.sh --configfile config/cohorts/cidur.yaml
#
# Requires: snakemake >= 8, snakemake-executor-plugin-slurm

#SBATCH --job-name=aidhs_smk
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=12:00:00
#SBATCH --partition=general
#SBATCH --output=logs/snakemake_driver.%j.out
#SBATCH --error=logs/snakemake_driver.%j.err

set -euo pipefail

AIDHS_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${AIDHS_PY}"

mkdir -p logs .flags

SNAKEMAKE_CMD=()
if [[ -n "${AIDHS_SNAKEMAKE_BIN:-}" ]]; then
  SNAKEMAKE_CMD=("${AIDHS_SNAKEMAKE_BIN}")
elif command -v snakemake &>/dev/null && snakemake --version &>/dev/null; then
  SNAKEMAKE_CMD=(snakemake)
else
  for py in python3.12 python3.11 python3; do
    if command -v "${py}" &>/dev/null \
      && PYTHONNOUSERSITE=0 "${py}" -m snakemake --version &>/dev/null; then
      SNAKEMAKE_CMD=(env PYTHONNOUSERSITE=0 "${py}" -m snakemake)
      break
    fi
  done
fi
if [[ ${#SNAKEMAKE_CMD[@]} -eq 0 ]]; then
  echo "ERROR: snakemake not found. Run: aidhs_py/scripts/setup_env.sh" >&2
  exit 1
fi

# Ensure container image exists
PIPELINE_ROOT="$(python3 - <<'PY'
import yaml
from pathlib import Path
c = yaml.safe_load(open("config/config.yaml"))
print((Path(".") / c["pipeline_root"]).resolve())
PY
)"
if [[ ! -f "${PIPELINE_ROOT}/.aid/aidhs.sif" ]]; then
  echo "ERROR: Missing ${PIPELINE_ROOT}/.aid/aidhs.sif — run: cd ${PIPELINE_ROOT} && ./aid install --runtime apptainer" >&2
  exit 1
fi

EXTRA_ARGS=("$@")
if [[ ${#EXTRA_ARGS[@]} -eq 0 ]]; then
  EXTRA_ARGS=(--configfile config/config.yaml)
fi

echo "=== AID-HS Snakemake driver ==="
echo "Host:     $(hostname)"
echo "Start:    $(date)"
echo "Workdir:  ${AIDHS_PY}"
echo "Pipeline: ${PIPELINE_ROOT}"
echo "Args:     ${EXTRA_ARGS[*]}"
echo "==============================="

"${SNAKEMAKE_CMD[@]}" -s Snakefile \
  --profile profiles/slurm \
  "${EXTRA_ARGS[@]}"

echo "Finished: $(date)"
