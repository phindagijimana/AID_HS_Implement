#!/usr/bin/env bash
# Remove partial AID-HS/HippUnfold outputs for a subject before re-run.

set -euo pipefail

SUBJECT_ID="${1:?Usage: clean_subject.sh <subject_id>}"
PIPELINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PIPELINE_ROOT}"

clean_glob() {
  local pattern="$1"
  local path
  shopt -s nullglob
  for path in ${pattern}; do
    rm -rf "${path}"
    echo "Removed: ${path}"
  done
  shopt -u nullglob
}

echo "Cleaning partial outputs for ${SUBJECT_ID}..."

clean_glob "output/hippunfold_outputs/hippunfold/${SUBJECT_ID}"
clean_glob "output/hippunfold_outputs/work/${SUBJECT_ID}"
clean_glob "output/hippunfold_outputs/logs/${SUBJECT_ID}"
clean_glob "output/bids_outputs/${SUBJECT_ID}"
clean_glob "output/fs_outputs/${SUBJECT_ID}"
clean_glob "output/preprocessed_surf_data/*/${SUBJECT_ID}"
clean_glob "output/preprocessed_surf_data/*/*${SUBJECT_ID}*"
clean_glob "output/predictions_reports/${SUBJECT_ID}"

rm -rf output/hippunfold_outputs/.snakemake/locks/* 2>/dev/null || true

echo "Done."
