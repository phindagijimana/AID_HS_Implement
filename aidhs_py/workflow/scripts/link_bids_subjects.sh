#!/usr/bin/env bash
# Symlink external BIDS subjects into pipeline_root/input/.
set -euo pipefail

PIPELINE_ROOT="$(cd "$1" && pwd)"
BIDS_ROOT="$(cd "$2" && pwd)"
SUBJECTS_FILE="$3"

mkdir -p "${PIPELINE_ROOT}/input"

while IFS= read -r sid || [[ -n "${sid}" ]]; do
  [[ -n "${sid}" ]] || continue
  [[ "${sid}" =~ ^# ]] && continue
  src="${BIDS_ROOT}/${sid}"
  dst="${PIPELINE_ROOT}/input/${sid}"
  if [[ ! -d "${src}" ]]; then
    echo "ERROR: BIDS subject not found: ${src}" >&2
    exit 1
  fi
  if [[ ! -e "${dst}" ]]; then
    ln -sfn "${src}" "${dst}"
    echo "Linked ${dst} -> ${src}"
  fi
done < "${SUBJECTS_FILE}"
