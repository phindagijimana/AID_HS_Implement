#!/bin/bash
#SBATCH --job-name=aidhs
#SBATCH --output=logs/slurm-%x-%j.out
#SBATCH --error=logs/slurm-%x-%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=general

# Run AID-HS for URMC Test HS subject(s).
# Usage: sbatch jobs/urmc_test/run_subject.sh sub-0000CD3C

set -euo pipefail

SUBJECT_ID="${1:?Usage: run_subject.sh <subject_id> e.g. sub-0000CD3C}"

PIPELINE_ROOT="${AID_PIPELINE_ROOT:-}"
if [[ -z "${PIPELINE_ROOT}" ]]; then
  PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
PIPELINE_ROOT="$(cd "${PIPELINE_ROOT}" && pwd -P)"
DEMO="${PIPELINE_ROOT}/jobs/urmc_test/demographics_file.csv"

if [[ -f "${PIPELINE_ROOT}/jobs/urmc_test/config.env" ]]; then
  # shellcheck source=/dev/null
  source "${PIPELINE_ROOT}/jobs/urmc_test/config.env"
fi

URMC_HS_ROOT="${URMC_HS_ROOT:-}"

cd "${PIPELINE_ROOT}"
mkdir -p logs input

# Flat BIDS layout (no ses-*); use null session in bids_config
if [[ -f "${PIPELINE_ROOT}/jobs/urmc_test/bids_config.json" ]]; then
  cp "${PIPELINE_ROOT}/jobs/urmc_test/bids_config.json" "${PIPELINE_ROOT}/input/bids_config.json"
fi

# Link T1w: sub-0000CD3C -> 0000CD3C_SAG_T1_MPRAGE_*.nii.gz
T1_SRC=""
if [[ -n "${URMC_HS_ROOT}" && -d "${URMC_HS_ROOT}" ]]; then
  T1_SRC="$(find "${URMC_HS_ROOT}" -maxdepth 1 -name '*T1*MPRAGE*.nii.gz' -o -name '*MP-RAGE*.nii.gz' -o -name '*_T1w.nii.gz' 2>/dev/null | head -1)"
fi
if [[ -z "${T1_SRC}" ]]; then
  echo "ERROR: No T1w NIfTI under URMC_HS_ROOT=${URMC_HS_ROOT}" >&2
  exit 1
fi

mkdir -p "input/${SUBJECT_ID}/anat"
ln -sfn "${T1_SRC}" "input/${SUBJECT_ID}/anat/${SUBJECT_ID}_T1w.nii.gz"

if [[ ! -f .aid/config.env ]]; then
  echo "ERROR: Run ./aid install --runtime apptainer first" >&2
  exit 1
fi

echo "=== AID-HS URMC Test HS ==="
echo "Subject:  ${SUBJECT_ID}"
echo "T1w:      ${T1_SRC}"
echo "Host:     $(hostname)"
echo "Start:    $(date)"
echo "==========================="

export AID_EXTRA_BINDS="$(dirname "${T1_SRC}"):$(dirname "${T1_SRC}"):ro"
export AID_RUN_LOG="${PIPELINE_ROOT}/logs/run-${SUBJECT_ID}.log"
export PYTHONNOUSERSITE=1
unset PYTHONPATH || true

"${PIPELINE_ROOT}/jobs/cidur/clean_subject.sh" "${SUBJECT_ID}"

./aid start -id "${SUBJECT_ID}" -demos jobs/urmc_test/demographics_file.csv --foreground
exit_code=$?

echo "Finished: $(date)"
echo "Report:   ${PIPELINE_ROOT}/output/predictions_reports/${SUBJECT_ID}/Report_${SUBJECT_ID}.pdf"
exit "${exit_code}"
