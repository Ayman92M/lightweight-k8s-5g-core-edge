#!/usr/bin/env bash
set -euo pipefail


ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_PATH="${ROOT_DIR}/free5gc.env"



# -----------------------------
# Helper loading / env
# -----------------------------

load_env() {
  title "Load configuration"
  info "Env file: $ENV_PATH"

  if [[ ! -f "$ENV_PATH" ]]; then
    warn "Config file not found: $ENV_PATH"
    warn "Create it first (free5gc.env)."
    exit 1
  fi

  source "$ENV_PATH"
  ok "Loaded free5gc.env"
}

export_env() {
  # Export your existing variables from free5gc.env
  export MASTER_BASE_DIR REPO_DIR CHARTS_DIR

  export NAMESPACE FREE5GC_RELEASE UERANSIM_RELEASE

  export CORE5G_WORKLOAD_VALUE UERANSIM_WORKLOAD_VALUE
  export CORE5G_NODE_NAME UERANSIM_NODE_NAME

  export FREE5GC_MASTERIF_KEY
  export CORE5G_NIC UERANSIM_NIC

  export FREE5GC_N6_BASE_KEY 
  export N6_SUBNET N6_CIDR N6_GATEWAY N6_EXCLUDE


  export UPF_IP0 UPF_IP1 UPF_IP2 UPF_IP3 UPF_IP4 UPF_IP5 UPF_IP6

  export PV_BASE_DIR PV_MONGO_DIR PV_CERT_DIR
  export PV_MONGO_NAME PV_CERT_NAME 

  export MONGO_REPO MONGO_TAG

  # export K8S_DISTRO HELM_ACTION CNI_CHOICE DEPLOY_CHOICE
}

validate_env() {
  title "Validate free5gc.env"

  local required_vars=(
    MASTER_BASE_DIR REPO_DIR CHARTS_DIR

  NAMESPACE FREE5GC_RELEASE UERANSIM_RELEASE

  CORE5G_WORKLOAD_VALUE UERANSIM_WORKLOAD_VALUE
  CORE5G_NODE_NAME UERANSIM_NODE_NAME

  FREE5GC_MASTERIF_KEY
  CORE5G_NIC UERANSIM_NIC

  FREE5GC_N6_BASE_KEY 
  N6_SUBNET N6_CIDR N6_GATEWAY N6_EXCLUDE


  UPF_IP0 UPF_IP1 UPF_IP2 UPF_IP3 UPF_IP4 UPF_IP5 UPF_IP6

  PV_BASE_DIR PV_MONGO_DIR PV_CERT_DIR
  PV_MONGO_NAME PV_CERT_NAME 

  MONGO_REPO MONGO_TAG
  )

  local missing=0
  for v in "${required_vars[@]}"; do
    if [[ -z "${!v:-}" ]]; then
      warn "Missing/empty variable: $v"
      missing=1
    fi
  done

  if [[ -n "${N6_CIDR:-}" ]] && ! [[ "$N6_CIDR" =~ ^[0-9]+$ ]]; then
    warn "N6_CIDR must be a number (got: $N6_CIDR)"
    missing=1
  fi

  (( missing == 0 )) || { warn "Fix free5gc.env and re-run."; exit 1; }
  ok "free5gc.env looks valid"
}

print_env_summary() {
  title "free5gc.env summary"

  cat <<EOF
  MASTER_BASE_DIR=${MASTER_BASE_DIR}
  REPO_DIR=${REPO_DIR}
  CHARTS_DIR=${CHARTS_DIR}

  NAMESPACE=${NAMESPACE}
  FREE5GC_RELEASE=${FREE5GC_RELEASE}
  UERANSIM_RELEASE=${UERANSIM_RELEASE}

  CORE5G_NODE_NAME=${CORE5G_NODE_NAME} - CORE5G_WORKLOAD_VALUE=${CORE5G_WORKLOAD_VALUE}
  UERANSIM_NODE_NAME=${UERANSIM_NODE_NAME} - UERANSIM_WORKLOAD_VALUE=${UERANSIM_WORKLOAD_VALUE}

  FREE5GC_MASTERIF_KEY=${FREE5GC_MASTERIF_KEY}
  CORE5G_NIC=${CORE5G_NIC}
  UERANSIM_NIC=${UERANSIM_NIC}

  FREE5GC_N6_BASE_KEY=${FREE5GC_N6_BASE_KEY}

  N6_SUBNET=${N6_SUBNET}
  N6_CIDR=${N6_CIDR}
  N6_GATEWAY=${N6_GATEWAY}
  N6_EXCLUDE=${N6_EXCLUDE}

  UPF_IP0=${UPF_IP0}
  UPF_IP1=${UPF_IP1}
  UPF_IP2=${UPF_IP2}
  UPF_IP3=${UPF_IP3}
  UPF_IP4=${UPF_IP4}
  UPF_IP5=${UPF_IP5}
  UPF_IP6=${UPF_IP6}

  PV_BASE_DIR=${PV_BASE_DIR}
  PV_MONGO_DIR=${PV_MONGO_DIR}
  PV_CERT_DIR=${PV_CERT_DIR}
  PV_MONGO_NAME=${PV_MONGO_NAME}
  PV_CERT_NAME=${PV_CERT_NAME}

  MONGO_REPO=${MONGO_REPO}
  MONGO_TAG=${MONGO_TAG}
EOF
}

confirm_continue() {
  if ! ask_yn "Continue using these free5gc.env values?" Y; then
    warn "Aborted. Edit free5gc.env and run again."
    exit 1
  fi
  ok "Config accepted"
}


step00_init_env() {
  load_env
  validate_env
  print_env_summary
  confirm_continue
  export_env
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
  source "$HELPER_PATH"
  step00_init_env
fi