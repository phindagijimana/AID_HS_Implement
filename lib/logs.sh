#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

cmd_logs() {
  local target="run"
  local follow=1
  local lines=50

  while [[ $# -gt 0 ]]; do
    case "$1" in
      install)
        target="install"
        shift
        ;;
      run | pipeline)
        target="run"
        shift
        ;;
      --no-follow | -n)
        follow=0
        shift
        ;;
      -f | --follow)
        follow=1
        shift
        ;;
      --tail)
        lines="$2"
        shift 2
        ;;
      -h | --help)
        cat <<'EOF'
Usage: ./aid logs [install|run] [options]

View pipeline logs.

Arguments:
  install     Show logs/install.log (installation)
  run         Show logs/run.log (default; prediction pipeline)

Options:
  --tail N        Show last N lines before follow (default: 50)
  -n, --no-follow Print lines and exit (no tail -f)
  -f, --follow    Follow log output (default)
EOF
        exit 0
        ;;
      *)
        die "Unknown logs option: $1"
        ;;
    esac
  done

  local logfile
  case "${target}" in
    install) logfile="${AID_INSTALL_LOG}" ;;
    run) logfile="${AID_RUN_LOG}" ;;
    *) die "Unknown log target: ${target}" ;;
  esac

  if [[ ! -f "${logfile}" ]]; then
    die "Log file not found: ${logfile} (has ./aid ${target} been run?)"
  fi

  if [[ "${follow}" -eq 1 ]]; then
    tail -n "${lines}" -f "${logfile}"
  else
    tail -n "${lines}" "${logfile}"
  fi
}

cmd_status() {
  load_config 2>/dev/null || true
  echo "Pipeline root:  ${AID_ROOT}"
  if [[ -f "${AID_CONFIG}" ]]; then
    echo "Installed:      yes (${AID_RUNTIME})"
    echo "Config:         ${AID_CONFIG}"
  else
    echo "Installed:      no (run ./aid install)"
  fi
  if [[ -f "${AID_LICENSE_FILE}" ]]; then
    echo "License:        ${AID_LICENSE_FILE}"
  else
    echo "License:        MISSING"
  fi
  if is_running; then
    echo "Status:         RUNNING (PID $(cat "${AID_PID_FILE}"))"
  else
    echo "Status:         idle"
  fi
  echo "Data mount:     ${AID_DATA_DIR} -> /data (in container)"
  echo "Input:          ${AID_ROOT}/input/"
  echo "Output:         ${AID_ROOT}/output/ (and input/output/ from AID-HS)"
}
