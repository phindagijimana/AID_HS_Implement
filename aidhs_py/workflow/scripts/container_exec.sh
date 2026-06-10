#!/usr/bin/env bash
# Run a command inside the AID-HS Apptainer image with standard binds.
# Usage: container_exec.sh <pipeline_root> <license> <sif> [extra_bind] -- <inner_cmd>

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: container_exec.sh <pipeline_root> <license> <sif> [extra_binds] -- <cmd>" >&2
  exit 1
fi

PIPELINE_ROOT="$(cd "$1" && pwd)"
LICENSE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
SIF="$3"
shift 3

EXTRA_BINDS=""
if [[ "${1:-}" != "--" ]]; then
  EXTRA_BINDS="$1"
  shift
fi
[[ "${1:-}" == "--" ]] || { echo "Expected -- before inner command" >&2; exit 1; }
shift
INNER_CMD="$*"

if command -v apptainer &>/dev/null; then
  SRUNTIME=apptainer
elif command -v singularity &>/dev/null; then
  SRUNTIME=singularity
else
  echo "ERROR: apptainer or singularity required" >&2
  exit 1
fi

# HPC: avoid host ~/.local numpy breaking nnUNet inside container
export PYTHONNOUSERSITE=1
unset PYTHONPATH || true
export APPTAINERENV_PYTHONNOUSERSITE=1
export APPTAINERENV_PYTHONPATH=""
export SINGULARITYENV_PYTHONNOUSERSITE=1
export SINGULARITYENV_PYTHONPATH=""

CACHE="${PIPELINE_ROOT}/.aid/cache"
TMP="${PIPELINE_ROOT}/.aid/tmp"
mkdir -p "${CACHE}" "${TMP}"
export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-${CACHE}}"
export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-${CACHE}}"
export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${TMP}}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-${TMP}}"

BINDS="${PIPELINE_ROOT}:/data,${LICENSE}:/aidhs_license.txt:ro"
if [[ -n "${EXTRA_BINDS}" ]]; then
  BINDS="${BINDS},${EXTRA_BINDS}"
fi

export APPTAINERENV_AIDHS_LICENSE="/aidhs_license.txt"
export SINGULARITYENV_AIDHS_LICENSE="/aidhs_license.txt"

exec "${SRUNTIME}" exec --cleanenv -B "${BINDS}" "${SIF}" \
  /bin/bash -c "cd /app && ${INNER_CMD}"
