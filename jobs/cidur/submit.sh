#!/usr/bin/env bash
# Submit AID-HS Slurm jobs (sequential — shared HippUnfold output dir).

set -euo pipefail

PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PIPELINE_ROOT}"

if [[ -f "${PIPELINE_ROOT}/jobs/cidur/config.env" ]]; then
  # shellcheck source=/dev/null
  source "${PIPELINE_ROOT}/jobs/cidur/config.env"
fi

CIDUR_BIDS="${CIDUR_BIDS:-}"

if [[ -f "${PIPELINE_ROOT}/jobs/cidur/subjects_list.txt" ]]; then
  mapfile -t SUBJECTS < "${PIPELINE_ROOT}/jobs/cidur/subjects_list.txt"
elif [[ -n "${AIDHS_SUBJECTS:-}" ]]; then
  read -r -a SUBJECTS <<< "${AIDHS_SUBJECTS}"
else
  echo "ERROR: Define subjects in jobs/cidur/subjects_list.txt (copy from subjects_list.txt.example)" >&2
  echo "       or set AIDHS_SUBJECTS in jobs/cidur/config.env" >&2
  exit 1
fi

mkdir -p logs input

if [[ -n "${CIDUR_BIDS}" ]]; then
  for sub in "${SUBJECTS[@]}"; do
    [[ -n "${sub}" ]] || continue
    if [[ ! -e "input/${sub}" ]]; then
      ln -sfn "${CIDUR_BIDS}/${sub}" "input/${sub}"
    fi
  done
fi

prev_job=""
for sub in "${SUBJECTS[@]}"; do
  [[ -n "${sub}" ]] || continue
  if [[ -n "${prev_job}" ]]; then
    job_id="$(sbatch --parsable --dependency="afterany:${prev_job}" --job-name="aidhs-${sub}" \
      "${PIPELINE_ROOT}/jobs/cidur/run_subject.sh" "${sub}")"
  else
    job_id="$(sbatch --parsable --job-name="aidhs-${sub}" \
      "${PIPELINE_ROOT}/jobs/cidur/run_subject.sh" "${sub}")"
  fi
  echo "Submitted ${job_id}  (${sub})"
  prev_job="${job_id}"
done

echo ""
echo "Jobs run sequentially (HippUnfold lock). Monitor: squeue -u \$USER"
