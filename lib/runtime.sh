#!/usr/bin/env bash
# Container execution helpers (Docker Compose and Singularity/Apptainer).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

generate_compose_yml() {
  local template="${AID_ROOT}/templates/compose.yml.in"
  local out="${AID_ROOT}/compose.yml"
  [[ -f "${template}" ]] || die "Missing template: ${template}"

  local gpu_block=""
  if detect_gpu "${AID_USE_GPU}"; then
    gpu_block="$(gpu_compose_block)"
  fi

  sed \
    -e "s|__AID_DATA_DIR__|${AID_DATA_DIR}|g" \
    -e "s|__AID_LICENSE_FILE__|${AID_LICENSE_FILE}|g" \
    -e "s|__GPU_BLOCK__|${gpu_block}|g" \
    "${template}" >"${out}"

  # Remove placeholder line if GPU block empty
  if [[ -z "${gpu_block}" ]]; then
    sed -i '/__GPU_BLOCK__/d' "${out}" 2>/dev/null || sed -i '' '/__GPU_BLOCK__/d' "${out}" 2>/dev/null || true
  fi

  log INFO "Wrote ${out}"
}

docker_compose_cmd() {
  if docker compose version &>/dev/null 2>&1; then
    echo "docker compose"
  elif have_cmd docker-compose; then
    echo "docker-compose"
  else
    die "docker compose not available"
  fi
}

docker_user_export() {
  if [[ "$(uname -s)" == "Linux" ]]; then
    export DOCKER_USER="$(id -u):$(id -g)"
  fi
}

container_bindpath() {
  load_config
  local binds="${AID_DATA_DIR}:/data,${AID_LICENSE_FILE}:/aidhs_license.txt:ro"
  if [[ -n "${AID_EXTRA_BINDS}" ]]; then
    binds="${binds},${AID_EXTRA_BINDS}"
  fi
  printf '%s' "${binds}"
}

# Prevent host ~/.local Python packages from breaking container numpy/nnUNet
setup_container_env() {
  export PYTHONNOUSERSITE=1
  unset PYTHONPATH || true
  export APPTAINERENV_PYTHONNOUSERSITE=1
  export APPTAINERENV_PYTHONPATH=""
  export SINGULARITYENV_PYTHONNOUSERSITE=1
  export SINGULARITYENV_PYTHONPATH=""
}

run_in_container() {
  local inner_cmd="$1"
  shift
  load_config
  require_license

  case "${AID_RUNTIME}" in
    docker)
      generate_compose_yml
      docker_user_export
      local dc
      dc="$(docker_compose_cmd)"
      # shellcheck disable=SC2086
      ${dc} -f "${AID_ROOT}/compose.yml" run --rm aidhs bash -c "${inner_cmd}" "$@"
      ;;
    singularity | apptainer)
      setup_apptainer_paths
      setup_container_env
      local s_cmd binds
      s_cmd="$(singularity_cmd)"
      binds="$(container_bindpath)"
      if [[ "${s_cmd}" == "apptainer" ]]; then
        export APPTAINERENV_AIDHS_LICENSE="/aidhs_license.txt"
        export APPTAINER_BINDPATH="${binds}"
      else
        export SINGULARITYENV_AIDHS_LICENSE="/aidhs_license.txt"
        export SINGULARITY_BINDPATH="${binds}"
      fi
      "${s_cmd}" exec "${AID_SIF}" /bin/bash -c "cd /app && ${inner_cmd}" "$@"
      ;;
    *)
      die "Unknown runtime: ${AID_RUNTIME}"
      ;;
  esac
}

pull_or_build_image() {
  load_config
  setup_apptainer_paths
  case "${AID_RUNTIME}" in
    docker)
      log INFO "Pulling Docker image ${AID_IMAGE} (this may take a while)..."
      docker pull "${AID_IMAGE}"
      ;;
    singularity | apptainer)
      local s_cmd
      s_cmd="$(singularity_cmd)"
      log INFO "Building Singularity image at ${AID_SIF} (requires ~20GB free space)..."
      mkdir -p "${AID_STATE_DIR}"
      # Honor user cache overrides from environment
      "${s_cmd}" build "${AID_SIF}" "docker://${AID_IMAGE}"
      ;;
  esac
}

run_pytest() {
  log INFO "Running installation verification (pytest)..."
  case "${AID_RUNTIME}" in
    docker)
      generate_compose_yml
      docker_user_export
      local dc
      dc="$(docker_compose_cmd)"
      # shellcheck disable=SC2086
      ${dc} -f "${AID_ROOT}/compose.yml" run --rm aidhs pytest
      ;;
    singularity | apptainer)
      run_in_container "pytest"
      ;;
  esac
}

run_prepare() {
  log INFO "Downloading models and configuring data paths (prepare_aidhs.py)..."
  run_in_container "python ${AID_PREPARE_SCRIPT}"
}

run_pipeline() {
  local pipeline_args="$1"
  log INFO "Starting AID-HS pipeline: ${pipeline_args}"

  # Upstream new_patient_pipeline.py segfaults with --skip_segmentation on some
  # platforms; call the prediction step directly (same path pytest uses).
  if [[ "${pipeline_args}" == *"--skip_segmentation"* ]]; then
    local pred_args="${pipeline_args//--skip_segmentation/}"
    run_in_container "python scripts/new_patient_pipeline/run_pipeline_prediction.py ${pred_args}"
    return
  fi

  run_in_container "python ${AID_PIPELINE_SCRIPT} ${pipeline_args}"
}
