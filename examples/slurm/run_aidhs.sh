#!/bin/bash
#SBATCH --job-name=aidhs
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00

# Example Slurm job: run AID-HS via the production CLI on HPC.
# Submit from the pipeline root:
#   sbatch examples/slurm/run_aidhs.sh

set -euo pipefail

PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PIPELINE_ROOT}"

# Use scratch for Singularity cache if $HOME quota is small
# export SINGULARITY_CACHEDIR=/scratch/${USER}/singularity-cache
# export SINGULARITY_TMPDIR=/scratch/${USER}/singularity-tmp

if [[ ! -f .aid/config.env ]]; then
  ./aid install --runtime singularity
fi

./aid start -id sub-REPLACE_ME -demos input/demographics_file.csv

# Wait for background job (optional; remove if you only want to submit and exit)
while ./aid status 2>/dev/null | grep -q RUNNING; do
  sleep 60
done
