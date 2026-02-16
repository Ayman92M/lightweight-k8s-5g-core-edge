#!/usr/bin/env bash
set -euo pipefail



# -----------------------------
# Guards
# -----------------------------
validate_require_env_charts() {

  local required_vars=(
    MASTER_BASE_DIR
    REPO_DIR CHARTS_DIR

  )

  local missing=0
  for v in "${required_vars[@]}"; do
    if [[ -z "${!v:-}" ]]; then
      warn "Missing/empty variable: ${v}"
      missing=1
    fi
  done

  (( missing == 0 )) || {
    return 1
  }
  return 0
  ok "Exported env looks OK."
}


# -----------------------------
# get_free5gc_charts
# -----------------------------
get_free5gc_charts() {
  title "Get Free5GC Helm charts"

  info "MASTER_BASE_DIR=${MASTER_BASE_DIR}"
  command --run "mkdir -p \"${MASTER_BASE_DIR}\""

  if [[ -d "${REPO_DIR}/.git" ]]; then
    #ask_yn "Repo already exists at ${repo_dir}. Pull latest changes?" Y || {
    #  warn "Skipping repo update."
    #  return 0
    #}
    #info "Updating existing repo: ${repo_dir}"
    #command --run "git -C \"${repo_dir}\" pull"
    info "Repo already exists at ${REPO_DIR}. Skipping clone/pull."
  else
    info "Cloning repo into: ${REPO_DIR}"
    command --run "git clone https://github.com/free5gc/free5gc-helm.git \"${REPO_DIR}\""
  fi

  [[ -d "$CHARTS_DIR" ]] || { warn "Charts dir not found: $CHARTS_DIR"; exit 1; }

  ok "Charts ready."

}



run_step03_get_free5gc_charts() {

  if ! validate_require_env_charts; then
    warn "Missing exported env. Loading default env now."
    step00_init_env
  fi

  if ask_yn "Fetch Free5GC Helm charts now?" Y; then
    get_free5gc_charts

    info "Current tag in ${REPO_DIR}:"
    command --run "git -C \"${REPO_DIR}\" describe --tags --abbrev=0"

    info "Available tags in ${REPO_DIR}:"
    command --run "git -C \"${REPO_DIR}\" tag --list --sort=-creatordate"

    if ask_yn "Checkout specific tag/commit for free5gc-helm repo (default No)?" N; then
      local tag
      read -r -p "Enter tag/commit: " tag
      info "Checking out ${tag} in ${REPO_DIR}"
      command --run "git -C \"${REPO_DIR}\" checkout \"${tag}\""
    fi

    if ask_yn "Set values in charts now?" Y; then
      set_charts_values
    else
      warn "Skipping setting values."
    fi
    ok "Free5GC charts ready at: ${CHARTS_DIR} - step 03 complete."
  else
    warn "Skipping fetching charts."
  fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

  HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
  LOADER_ENV_PATH="${ROOT_DIR}/scripts/00_load_env.sh"
  SET_VALUES_PATH="${ROOT_DIR}/scripts/031_set_values.sh"
  YAML_HELPER_PATH="${ROOT_DIR}/helper_scripts/yaml_helpers.sh"

  source "$HELPER_PATH"
  source "$LOADER_ENV_PATH"
  source "$SET_VALUES_PATH"
  source "$YAML_HELPER_PATH"

  run_step03_get_free5gc_charts
fi