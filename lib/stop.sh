#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

cmd_stop() {
  local force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force | -f)
        force=1
        shift
        ;;
      -h | --help)
        echo "Usage: ./aid stop [--force]"
        echo "Stop the background pipeline started with ./aid start"
        exit 0
        ;;
      *)
        die "Unknown stop option: $1"
        ;;
    esac
  done

  if ! is_running; then
    rm -f "${AID_PID_FILE}"
    log INFO "No running pipeline found."
    exit 0
  fi

  local pid
  pid="$(cat "${AID_PID_FILE}")"
  log INFO "Stopping pipeline (PID ${pid})..."

  # Negative PID targets the setsid session (worker + docker/singularity children)
  if [[ "${force}" -eq 1 ]]; then
    kill -KILL "-${pid}" 2>/dev/null || kill -9 "${pid}" 2>/dev/null || true
  else
    kill -TERM "-${pid}" 2>/dev/null || kill -TERM "${pid}" 2>/dev/null || true
    local i
    for i in $(seq 1 30); do
      if ! kill -0 "${pid}" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    if kill -0 "${pid}" 2>/dev/null; then
      log INFO "Process still running; sending SIGKILL to process group"
      kill -KILL "-${pid}" 2>/dev/null || kill -9 "${pid}" 2>/dev/null || true
    fi
  fi

  rm -f "${AID_PID_FILE}"
  log INFO "Pipeline stopped."
}
