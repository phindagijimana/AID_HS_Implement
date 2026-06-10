#!/usr/bin/env bash
# Cohort orchestration via aidhs_py/ Snakemake workflow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

AIDHS_PY="${AID_ROOT}/aidhs_py"
SNAKEFILE="${AIDHS_PY}/Snakefile"
DEFAULT_CONFIG="${AIDHS_PY}/config/config.yaml"

cohort_usage() {
  cat <<EOF
Usage: ./aid cohort <subcommand> [options]

Snakemake-based cohort runs (see aidhs_py/README.md).

Subcommands:
  setup       Copy example config files (subjects, demographics)
  subjects    Regenerate config/subjects.tsv from BIDS under input/
  lint        Dry-run DAG (no execution)
  run         Run locally (debug; 1 core)
  slurm       Submit Slurm driver job (recommended on HPC)
  status      Show per-subject validation flags and report PDFs
  help        Show this help

Options (lint, run, slurm):
  --configfile <path>   Snakemake config (default: aidhs_py/config/config.yaml)
  --config k=v          Override config key (repeatable)

Examples:
  ./aid cohort setup
  ./aid cohort subjects
  ./aid cohort lint
  ./aid cohort slurm
  ./aid cohort slurm --configfile aidhs_py/config/cohorts/cidur.yaml
  ./aid cohort status

Requires: pip install 'snakemake>=8' snakemake-executor-plugin-slurm  (for lint/run/slurm)
EOF
}

require_aidhs_py() {
  [[ -d "${AIDHS_PY}" ]] || die "Missing ${AIDHS_PY}"
  [[ -f "${SNAKEFILE}" ]] || die "Missing ${SNAKEFILE}"
}

require_snakemake() {
  if ! command -v snakemake &>/dev/null; then
    die "snakemake not found. Install: pip install 'snakemake>=8' snakemake-executor-plugin-slurm"
  fi
  if ! snakemake --version &>/dev/null; then
    die "snakemake is installed but broken. Reinstall: pip install --force-reinstall 'snakemake>=8'"
  fi
}

cohort_ensure_installed() {
  ensure_installed
  require_license
}

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ -f "${dst}" ]]; then
    log INFO "Already exists: ${dst}"
  else
    cp "${src}" "${dst}"
    log INFO "Created ${dst} from example"
  fi
}

cmd_cohort_setup() {
  require_aidhs_py
  mkdir -p "${AIDHS_PY}/config/cohorts" "${AIDHS_PY}/logs" "${AIDHS_PY}/.flags"
  copy_if_missing "${AIDHS_PY}/config/subjects.tsv.example" "${AIDHS_PY}/config/subjects.tsv"
  copy_if_missing "${AIDHS_PY}/config/demographics_file.csv.example" "${AIDHS_PY}/config/demographics_file.csv"
  copy_if_missing "${AIDHS_PY}/config/controls.tsv.example" "${AIDHS_PY}/config/controls.tsv"
  if [[ ! -f "${AIDHS_PY}/config/cohorts/cidur.yaml" && -f "${AIDHS_PY}/config/cohorts/cidur.yaml.example" ]]; then
    log INFO "Cohort override template: ${AIDHS_PY}/config/cohorts/cidur.yaml.example"
    log INFO "Copy and edit for your site: cp aidhs_py/config/cohorts/cidur.yaml.example aidhs_py/config/cohorts/cidur.yaml"
  fi
  echo ""
  echo "Next:"
  echo "  1. Edit aidhs_py/config/demographics_file.csv"
  echo "  2. Edit aidhs_py/config/subjects.tsv (or run: ./aid cohort subjects)"
  echo "  3. ./aid install   (if not already done)"
  echo "  4. ./aid cohort lint"
  echo "  5. ./aid cohort slurm"
}

cmd_cohort_subjects() {
  require_aidhs_py
  local out="${AIDHS_PY}/config/subjects.tsv"
  python3 "${AIDHS_PY}/workflow/scripts/list_subjects.py" \
    --pipeline-root "${AID_ROOT}" \
    --out "${out}"
  echo "Wrote ${out}"
}

parse_cohort_snakemake_args() {
  CONFIGFILE="${DEFAULT_CONFIG}"
  SNAKEMAKE_CONFIG_OVERRIDES=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --configfile)
        CONFIGFILE="$2"
        shift 2
        ;;
      --config)
        SNAKEMAKE_CONFIG_OVERRIDES+=(--config "$2")
        shift 2
        ;;
      -h | --help)
        cohort_usage
        exit 0
        ;;
      *)
        die "Unknown option: $1 (try: ./aid cohort help)"
        ;;
    esac
  done
  [[ -f "${CONFIGFILE}" ]] || die "Config not found: ${CONFIGFILE}"
}

cmd_cohort_lint() {
  require_aidhs_py
  require_snakemake
  cohort_ensure_installed
  parse_cohort_snakemake_args "$@"
  (
    cd "${AIDHS_PY}"
    snakemake -s Snakefile -n -p -q \
      --configfile "${CONFIGFILE}" \
      "${SNAKEMAKE_CONFIG_OVERRIDES[@]}"
  )
}

cmd_cohort_run() {
  require_aidhs_py
  require_snakemake
  cohort_ensure_installed
  parse_cohort_snakemake_args "$@"
  log INFO "Running Snakemake locally (1 core). For HPC use: ./aid cohort slurm"
  (
    cd "${AIDHS_PY}"
    snakemake -s Snakefile --cores 1 \
      --configfile "${CONFIGFILE}" \
      "${SNAKEMAKE_CONFIG_OVERRIDES[@]}"
  )
}

cmd_cohort_slurm() {
  require_aidhs_py
  require_snakemake
  cohort_ensure_installed
  parse_cohort_snakemake_args "$@"
  local submit="${AIDHS_PY}/submit_snakemake.sh"
  [[ -x "${submit}" ]] || die "Not executable: ${submit}"
  local cfg_arg="--configfile"
  local cfg_path="${CONFIGFILE}"
  # submit_snakemake.sh expects path relative to aidhs_py when possible
  if [[ "${CONFIGFILE}" == "${AIDHS_PY}/"* ]]; then
    cfg_path="${CONFIGFILE#${AIDHS_PY}/}"
  fi
  log INFO "Submitting Slurm driver with config: ${cfg_path}"
  (
    cd "${AIDHS_PY}"
    sbatch "${submit}" "${cfg_arg}" "${cfg_path}" "${SNAKEMAKE_CONFIG_OVERRIDES[@]}"
  )
}

cmd_cohort_status() {
  require_aidhs_py
  local subjects_file="${AIDHS_PY}/config/subjects.tsv"
  local flags_dir="${AIDHS_PY}/.flags"
  local reports_dir="${AID_ROOT}/output/predictions_reports"

  echo "Cohort status (aidhs_py)"
  echo "  Config:    ${DEFAULT_CONFIG}"
  echo "  Subjects:  ${subjects_file}"
  echo ""

  if [[ ! -f "${subjects_file}" ]]; then
    echo "No subjects file. Run: ./aid cohort setup"
    exit 0
  fi

  printf "%-20s %-10s %-10s %s\n" "SUBJECT" "VALIDATE" "REPORT" "PATH"
  while IFS= read -r sid || [[ -n "${sid}" ]]; do
    [[ -n "${sid}" ]] || continue
    [[ "${sid}" =~ ^# ]] && continue
    local validate="—"
    local report="—"
    local report_path="${reports_dir}/${sid}/Report_${sid}.pdf"
    if [[ -f "${flags_dir}/validate.${sid}.done" ]]; then
      validate="done"
    fi
    if [[ -f "${report_path}" ]]; then
      report="done"
    fi
    printf "%-20s %-10s %-10s %s\n" "${sid}" "${validate}" "${report}" "${report_path}"
  done < "${subjects_file}"
}

cmd_cohort() {
  local sub="${1:-help}"
  shift || true

  case "${sub}" in
    setup)
      cmd_cohort_setup "$@"
      ;;
    subjects)
      cmd_cohort_subjects "$@"
      ;;
    lint | dry-run | dry)
      cmd_cohort_lint "$@"
      ;;
    run)
      cmd_cohort_run "$@"
      ;;
    slurm | submit)
      cmd_cohort_slurm "$@"
      ;;
    status)
      cmd_cohort_status "$@"
      ;;
    help | -h | --help | "")
      cohort_usage
      ;;
    *)
      echo "Unknown cohort subcommand: ${sub}" >&2
      cohort_usage >&2
      exit 1
      ;;
  esac
}
