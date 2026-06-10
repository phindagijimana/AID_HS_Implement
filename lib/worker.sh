#!/usr/bin/env bash
# Background worker invoked by ./aid start

set -euo pipefail

AID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AID_ROOT

# shellcheck source=common.sh
source "${AID_ROOT}/lib/common.sh"
# shellcheck source=runtime.sh
source "${AID_ROOT}/lib/runtime.sh"

pipeline_args="$*"
load_config
export AID_LOG_FILE="${AID_RUN_LOG}"

cleanup() {
  rm -f "${AID_PID_FILE}"
}
trap cleanup EXIT

run_pipeline "${pipeline_args}"
