#!/bin/bash
#SBATCH --job-name=aidhs
#SBATCH --output=logs/slurm-%x-%j.out
#SBATCH --error=logs/slurm-%x-%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=general

# Run AID-HS for one subject.
# Usage (from pipeline root): sbatch --job-name=aidhs-sub-XXX jobs/cidur/run_subject.sh sub-XXX

set -euo pipefail

SUBJECT_ID="${1:?Usage: run_subject.sh <subject_id> e.g. sub-example001}"

PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEMO="${PIPELINE_ROOT}/jobs/cidur/demographics_file.csv"

# Optional local config (gitignored): CIDUR_BIDS, etc.
if [[ -f "${PIPELINE_ROOT}/jobs/cidur/config.env" ]]; then
  # shellcheck source=/dev/null
  source "${PIPELINE_ROOT}/jobs/cidur/config.env"
fi

CIDUR_BIDS="${CIDUR_BIDS:-}"

cd "${PIPELINE_ROOT}"

mkdir -p logs input

if [[ -n "${CIDUR_BIDS}" && ! -e "input/${SUBJECT_ID}" ]]; then
  ln -sfn "${CIDUR_BIDS}/${SUBJECT_ID}" "input/${SUBJECT_ID}"
fi

if [[ ! -d "input/${SUBJECT_ID}" ]]; then
  echo "ERROR: input/${SUBJECT_ID} not found. Set CIDUR_BIDS in jobs/cidur/config.env or link BIDS data under input/." >&2
  exit 1
fi

if [[ ! -f "${DEMO}" ]]; then
  echo "ERROR: Missing ${DEMO}. Copy demographics_file.csv.example and edit (file is gitignored)." >&2
  exit 1
fi

if [[ ! -f .aid/config.env ]]; then
  echo "ERROR: AID-HS not installed. Run: ./aid install --runtime apptainer" >&2
  exit 1
fi

echo "=== AID-HS Slurm job ==="
echo "Subject:  ${SUBJECT_ID}"
echo "Host:     $(hostname)"
echo "Start:    $(date)"
echo "Pipeline: ${PIPELINE_ROOT}"
echo "========================"

export AID_EXTRA_BINDS="${CIDUR_BIDS:+${CIDUR_BIDS}:${CIDUR_BIDS}:ro}"
export AID_RUN_LOG="${PIPELINE_ROOT}/logs/run-${SUBJECT_ID}.log"
export PYTHONNOUSERSITE=1
unset PYTHONPATH || true

"${PIPELINE_ROOT}/jobs/cidur/clean_subject.sh" "${SUBJECT_ID}"

./aid start -id "${SUBJECT_ID}" -demos jobs/cidur/demographics_file.csv --foreground
exit_code=$?

echo "Finished: $(date)"
echo "Log:      ${PIPELINE_ROOT}/logs/run-${SUBJECT_ID}.log"
echo "Report:   ${PIPELINE_ROOT}/output/predictions_reports/${SUBJECT_ID}/Report_${SUBJECT_ID}.pdf"
exit "${exit_code}"
