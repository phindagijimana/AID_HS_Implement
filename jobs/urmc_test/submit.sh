#!/usr/bin/env bash
# Submit URMC Test HS AID-HS job(s).
set -euo pipefail
PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "${PIPELINE_ROOT}"
export AID_PIPELINE_ROOT="${PIPELINE_ROOT}"
sbatch \
  --chdir="${PIPELINE_ROOT}" \
  --export=ALL,AID_PIPELINE_ROOT \
  --output="${PIPELINE_ROOT}/logs/slurm-%x-%j.out" \
  --error="${PIPELINE_ROOT}/logs/slurm-%x-%j.err" \
  --job-name=aidhs-sub-0000CD3C \
  "${PIPELINE_ROOT}/jobs/urmc_test/run_subject.sh" sub-0000CD3C
