#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=runtime.sh
source "${SCRIPT_DIR}/runtime.sh"

cmd_start() {
  local subject_id=""
  local subjects_file=""
  local demos=""
  local harmo_code=""
  local extra_flags=()
  local foreground=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -id | --id)
        subject_id="$2"
        shift 2
        ;;
      -ids | --ids)
        subjects_file="$2"
        shift 2
        ;;
      -demos | --demos)
        demos="$2"
        shift 2
        ;;
      -harmo_code | --harmo-code)
        harmo_code="$2"
        shift 2
        ;;
      --parallelise | --parallelize)
        extra_flags+=("--parallelise")
        shift
        ;;
      --skip_segmentation)
        extra_flags+=("--skip_segmentation")
        shift
        ;;
      --harmo_only | --harmo-only)
        extra_flags+=("--harmo_only")
        shift
        ;;
      --debug_mode | --debug)
        extra_flags+=("--debug_mode")
        shift
        ;;
      --foreground | -f)
        foreground=1
        shift
        ;;
      -h | --help)
        cat <<'EOF'
Usage: ./aid start [options]

Run the AID-HS prediction (or harmonisation-only) pipeline in the background.

Required (one of):
  -id <subject_id>       Single subject (e.g. sub-test001)
  -ids <file>              Text file with one subject ID per line

Required:
  -demos <csv>             Demographics CSV (relative to pipeline root or input/)

Optional:
  -harmo_code <code>       Harmonisation code (e.g. H1)
  --parallelise            Parallel HippUnfold segmentation
  --skip_segmentation      Skip segmentation (re-run prediction only)
  --harmo_only             Compute harmonisation parameters only
  --debug_mode             Verbose debug output
  --foreground, -f         Run in foreground (default: background)

Examples:
  ./aid start -id sub-patient01 -demos demographics_file.csv
  ./aid start -ids subjects_list.txt -demos demographics_file.csv -harmo_code H1
  ./aid start -ids controls.txt -demos demographics_file.csv -harmo_code H1 --harmo_only
EOF
        exit 0
        ;;
      *)
        die "Unknown start option: $1 (try ./aid start --help)"
        ;;
    esac
  done

  ensure_installed
  ensure_not_running
  require_license

  if [[ -z "${subject_id}" && -z "${subjects_file}" ]]; then
    die "Specify -id or -ids. See: ./aid start --help"
  fi
  if [[ -z "${demos}" ]]; then
    die "Specify -demos <csv>. See: ./aid start --help"
  fi
  if [[ -n "${subject_id}" && -n "${subjects_file}" ]]; then
    die "Use only one of -id or -ids"
  fi

  demos="$(resolve_demographics_path "${demos}")"

  local pipeline_args=""
  if [[ -n "${subject_id}" ]]; then
    pipeline_args="-id ${subject_id}"
  else
    if [[ ! -f "${AID_ROOT}/${subjects_file}" && ! -f "${AID_DATA_DIR}/${subjects_file}" ]]; then
      if [[ -f "${AID_ROOT}/input/${subjects_file}" ]]; then
        subjects_file="input/${subjects_file}"
      else
        die "Subjects list not found: ${subjects_file}"
      fi
    fi
    pipeline_args="-ids ${subjects_file}"
  fi
  pipeline_args="${pipeline_args} -demos ${demos}"
  if [[ -n "${harmo_code}" ]]; then
    pipeline_args="${pipeline_args} -harmo_code ${harmo_code}"
  fi
  if [[ ${#extra_flags[@]} -gt 0 ]]; then
    pipeline_args="${pipeline_args} ${extra_flags[*]}"
  fi

  export AID_LOG_FILE="${AID_RUN_LOG}"
  : >"${AID_RUN_LOG}"

  log INFO "Launching pipeline (log: ${AID_RUN_LOG})"

  if [[ "${foreground}" -eq 1 ]]; then
    run_pipeline "${pipeline_args}" 2>&1 | tee -a "${AID_RUN_LOG}"
    exit "${PIPESTATUS[0]}"
  fi

  # Background worker in its own session so ./aid stop can signal the whole process group
  setsid nohup "${AID_ROOT}/lib/worker.sh" "${pipeline_args}" >>"${AID_RUN_LOG}" 2>&1 &
  local pid=$!
  echo "${pid}" >"${AID_PID_FILE}"
  log INFO "Pipeline started in background (PID ${pid})"
  echo "Monitor with: ./aid logs"
  echo "Stop with:    ./aid stop"
}
