#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=runtime.sh
source "${SCRIPT_DIR}/runtime.sh"

cmd_install() {
  local runtime="auto"
  local use_gpu="auto"
  local skip_test=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --runtime)
        runtime="$2"
        shift 2
        ;;
      --gpu | --use-gpu)
        use_gpu="$2"
        shift 2
        ;;
      --no-gpu)
        use_gpu="no"
        shift
        ;;
      --skip-test)
        skip_test=1
        shift
        ;;
      -h | --help)
        cat <<'EOF'
Usage: ./aid install [options]

Install the AID-HS container, download models, and verify the setup.

Options:
  --runtime auto|docker|singularity|apptainer   Container backend (default: auto)
  --gpu auto|yes|no                             Enable GPU for Docker (default: auto)
  --no-gpu                                      Disable GPU
  --skip-test                                   Skip pytest verification

Data layout (all under the pipeline directory):
  ./input/              BIDS MRI and demographics
  ./output/             Pipeline outputs (also under input/output per AID-HS)
  ./aidhs_license.txt   License file (required)
EOF
        exit 0
        ;;
      *)
        die "Unknown install option: $1"
        ;;
    esac
  done

  export AID_LOG_FILE="${AID_INSTALL_LOG}"
  : >"${AID_INSTALL_LOG}"

  log INFO "AID-HS install starting (root: ${AID_ROOT})"
  require_license
  setup_bids_defaults

  AID_RUNTIME="$(detect_runtime "${runtime}")"
  AID_USE_GPU="${use_gpu}"
  save_config
  load_config

  log INFO "Using runtime: ${AID_RUNTIME}"
  pull_or_build_image
  run_prepare

  if [[ "${skip_test}" -eq 0 ]]; then
    run_pytest || die "Installation verification failed. See ${AID_INSTALL_LOG}"
  else
    log INFO "Skipped pytest (--skip-test)"
  fi

  log INFO "Install complete."
  echo ""
  echo "Next steps:"
  echo "  1. Place BIDS data under: ${AID_ROOT}/input/"
  echo "  2. Edit demographics:   ${AID_ROOT}/input/demographics_file.csv (or project root)"
  echo "  3. Run: ./aid start -id sub-XXX -demos demographics_file.csv"
}
