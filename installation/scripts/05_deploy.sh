#!/usr/bin/env bash
set -euo pipefail


# -----------------------------
# Expected exported env 
# -----------------------------
validate_require_deploy_env() {
  local required_vars=(

    NAMESPACE FREE5GC_RELEASE UERANSIM_RELEASE
    CHARTS_DIR
    MONGO_REPO MONGO_TAG
  )
  local missing=0
  for v in "${required_vars[@]}"; do
    if [[ -z "${!v:-}" ]]; then
      warn "Missing/empty env variable: $v"
      missing=1
    fi
  done
  (( missing == 0 )) || return 1
}

require_charts_layout() {
  
  FREE5GC_CHART="${CHARTS_DIR%/}/free5gc"
  UERANSIM_CHART="${CHARTS_DIR%/}/ueransim"

  [[ -d "$FREE5GC_CHART" ]] || { warn "Missing Free5GC chart dir: $FREE5GC_CHART"; return 1; }
  [[ -d "$UERANSIM_CHART" ]] || { warn "Missing UERANSIM chart dir: $UERANSIM_CHART"; return 1; }

  FREE5GC_VALUES="${FREE5GC_CHART}/values.yaml"
  UERANSIM_VALUES="${UERANSIM_CHART}/values.yaml"

  [[ -f "$FREE5GC_VALUES" ]] || { warn "Missing file: $FREE5GC_VALUES"; return 1; }
  [[ -f "$UERANSIM_VALUES" ]] || { warn "Missing file: $UERANSIM_VALUES"; return 1; }

  return 0
}

require_tools() {
  command -v kubectl >/dev/null 2>&1 || { warn "kubectl not found"; return 1; }
  command -v helm   >/dev/null 2>&1 || { warn "helm not found"; return 1; }
}



ensure_namespace() {
  if kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  command --run "kubectl create ns \"${NAMESPACE}\""
}

# -----------------------------
# Status helpers
# -----------------------------
show_pods() {
  title "Pods in namespace: ${NAMESPACE}"
  command --run "kubectl get pods -n \"${NAMESPACE}\" -o wide || true"
}



# -----------------------------
# Deploy actions (one at a time)
# -----------------------------
# helm -n free5gc get values core -a
deploy_free5gc() {
  title "Deploy Free5GC (release: ${FREE5GC_RELEASE:-core})"
  ensure_namespace

  info "Chart: ${FREE5GC_CHART}"
  command --run "helm upgrade --install -n \"${NAMESPACE}\" \"${FREE5GC_RELEASE}\" \"${FREE5GC_CHART}\" \
    --set \"mongodb.image.repository=${MONGO_REPO}\" \
    --set \"mongodb.image.tag=${MONGO_TAG}\""

  show_pods
}

deploy_ueransim() {
  title "Deploy UERANSIM (release: ${UERANSIM_RELEASE})"
  ensure_namespace

  info "Chart: ${UERANSIM_CHART}"
  command --run "helm upgrade --install -n \"${NAMESPACE}\" \"${UERANSIM_RELEASE}\" \"${UERANSIM_CHART}\""

  #show_pods
}



# -----------------------------
# Old deploy functions (with global values setting)
# -----------------------------
old_deploy_free5gc_and_set_global_values() {
  title "Deploy Free5GC (release: ${FREE5GC_RELEASE:-core})"

  : "${NAMESPACE:=free5gc}"
  : "${FREE5GC_RELEASE:=core}"

  : "${BASE_DIR:=$HOME}"
  : "${CHARTS_DIR:=${BASE_DIR}/free5gc-helm/charts}"
  : "${FREE5GC_CHART:=${CHARTS_DIR}/free5gc}"

  : "${CORE5G_WORKLOAD_VALUE:?CORE5G_WORKLOAD_VALUE not set}"
  : "${CORE5G_NODE_NAME:?CORE5G_NODE_NAME not set}"
  : "${CORE5G_NIC:?CORE5G_NIC not set}"

  : "${N6_SUBNET:?N6_SUBNET not set}"
  : "${N6_CIDR:?N6_CIDR not set}"
  : "${N6_GATEWAY:?N6_GATEWAY not set}"
  : "${N6_EXCLUDE:?N6_EXCLUDE not set}"

  : "${UPF_IP0:?UPF_IP0 not set}"
  : "${UPF_IP1:?UPF_IP1 not set}"
  : "${UPF_IP2:?UPF_IP2 not set}"
  : "${UPF_IP3:?UPF_IP3 not set}"
  : "${UPF_IP4:?UPF_IP4 not set}"
  : "${UPF_IP5:?UPF_IP5 not set}"
  : "${UPF_IP6:?UPF_IP6 not set}"

  : "${MONGO_REPO:=bitnamilegacy/mongodb}"
  : "${MONGO_TAG:=7.0.9-debian-12-r4}"

  # Toggle this if you want ONLY workload (simpler):
  : "${PIN_TO_HOSTNAME:=1}"   # 1 = also set kubernetes.io/hostname, 0 = workload only

  [[ -d "${FREE5GC_CHART}" ]] || { warn "Chart dir not found: ${FREE5GC_CHART}"; return 1; }

  info "Chart: ${FREE5GC_CHART}"
  info "Workload label: workload=${CORE5G_WORKLOAD_VALUE}"
  info "Pinning to node hostname: ${CORE5G_NODE_NAME}"
  info "masterIf for ALL networks: ${CORE5G_NIC}"
  info "Mongo override: ${MONGO_REPO}:${MONGO_TAG}"
  info "n6: ${N6_SUBNET}/${N6_CIDR} gw=${N6_GATEWAY} exclude=${N6_EXCLUDE}"
  info "UPF IPs: ${UPF_IP0} ${UPF_IP1} ${UPF_IP2} ${UPF_IP3} ${UPF_IP4} ${UPF_IP5} ${UPF_IP6}"

  ensure_namespace

  # IMPORTANT: keep kubernetes.io as ONE key (literal "\." must reach Helm)
  local k8s_hostname_key="kubernetes\\.io/hostname"

  # Build args as array (safe), then stringify for your helper
  local -a helm_cmd
  helm_cmd=(
    helm upgrade --install
    -n "${NAMESPACE}"
    "${FREE5GC_RELEASE}"
    "${FREE5GC_CHART}"

    --set "mongodb.image.repository=${MONGO_REPO}"
    --set "mongodb.image.tag=${MONGO_TAG}"

    # masterIf for ALL networks (global.*)
    --set "global.n2network.masterIf=${CORE5G_NIC}"
    --set "global.n3network.masterIf=${CORE5G_NIC}"
    --set "global.n4network.masterIf=${CORE5G_NIC}"
    --set "global.n6network.masterIf=${CORE5G_NIC}"
    --set "global.n9network.masterIf=${CORE5G_NIC}"

    # n6 subnet details (global.*)
    --set "global.n6network.subnetIP=${N6_SUBNET}"
    --set "global.n6network.cidr=${N6_CIDR}"
    --set "global.n6network.gatewayIP=${N6_GATEWAY}"
    --set "global.n6network.excludeIP=${N6_EXCLUDE}"

    # Some templates also read top-level n*network.*
    --set "n2network.masterIf=${CORE5G_NIC}"
    --set "n3network.masterIf=${CORE5G_NIC}"
    --set "n4network.masterIf=${CORE5G_NIC}"
    --set "n6network.masterIf=${CORE5G_NIC}"
    --set "n9network.masterIf=${CORE5G_NIC}"

    --set "n6network.subnetIP=${N6_SUBNET}"
    --set "n6network.cidr=${N6_CIDR}"
    --set "n6network.gatewayIP=${N6_GATEWAY}"
    --set "n6network.excludeIP=${N6_EXCLUDE}"

    # workload nodeSelectors
    --set "free5gc-amf.amf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-ausf.ausf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-chf.chf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-dbpython.dbpython.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-nef.nef.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-nrf.nrf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-nssf.nssf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-pcf.pcf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-smf.smf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-udm.udm.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-udr.udr.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-webui.webui.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "mongodb.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "mongodb.mongodb.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.upf.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.upf1.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.upf2.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.upfb.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.iupf1.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.psaupf1.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"
    --set "free5gc-upf.psaupf2.nodeSelector.workload=${CORE5G_WORKLOAD_VALUE}"

    # UPF IPs (force string)
    --set-string "free5gc-upf.upf.n6if.ipAddress=${UPF_IP0}"
    --set-string "free5gc-upf.upf1.n6if.ipAddress=${UPF_IP1}"
    --set-string "free5gc-upf.upf2.n6if.ipAddress=${UPF_IP2}"
    --set-string "free5gc-upf.upfb.n6if.ipAddress=${UPF_IP3}"
    --set-string "free5gc-upf.iupf1.n6if.ipAddress=${UPF_IP4}"
    --set-string "free5gc-upf.psaupf1.n6if.ipAddress=${UPF_IP5}"
    --set-string "free5gc-upf.psaupf2.n6if.ipAddress=${UPF_IP6}"
  )

  # Optional hostname pinning (workload is primary; hostname makes it strict)
  if [[ "${PIN_TO_HOSTNAME}" == "1" ]]; then
    helm_cmd+=(
      --set "free5gc-amf.amf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-ausf.ausf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-chf.chf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-dbpython.dbpython.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-nef.nef.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-nrf.nrf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-nssf.nssf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-pcf.pcf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-smf.smf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-udm.udm.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-udr.udr.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-webui.webui.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "mongodb.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "mongodb.mongodb.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.upf.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.upf1.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.upf2.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.upfb.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.iupf1.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.psaupf1.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
      --set "free5gc-upf.psaupf2.nodeSelector.${k8s_hostname_key}=${CORE5G_NODE_NAME}"
    )
  fi

  # Convert array -> single safe shell string for your helper
  local cmd_str=""
  printf -v cmd_str '%q ' "${helm_cmd[@]}"

  command --run "${cmd_str}"

  ok "Free5GC deploy command submitted."
}


old_deploy_ueransim_and_set_global_values() {
  title "Deploy UERANSIM (release: ${UERANSIM_RELEASE:-ueransim})"

  : "${NAMESPACE:=free5gc}"
  : "${UERANSIM_RELEASE:=ueransim}"

  : "${BASE_DIR:=$HOME}"
  : "${CHARTS_DIR:=${BASE_DIR}/free5gc-helm/charts}"
  : "${UERANSIM_CHART:=${CHARTS_DIR}/ueransim}"

  : "${UERANSIM_WORKLOAD_VALUE:?UERANSIM_WORKLOAD_VALUE not set}"
  : "${UERANSIM_NODE_NAME:?UERANSIM_NODE_NAME not set}"
  : "${UERANSIM_NIC:=${CORE5G_NIC}}"

  # Toggle this if you want ONLY workload (simpler):
  : "${PIN_TO_HOSTNAME:=1}"   # 1 = also set kubernetes.io/hostname, 0 = workload only

  [[ -d "${UERANSIM_CHART}" ]] || { warn "Chart dir not found: ${UERANSIM_CHART}"; return 1; }

  info "Chart: ${UERANSIM_CHART}"
  info "Workload label: workload=${UERANSIM_WORKLOAD_VALUE}"
  info "Pinning to node hostname: ${UERANSIM_NODE_NAME}"
  info "masterIf for UERANSIM networks: ${UERANSIM_NIC}"

  ensure_namespace

  local k8s_hostname_key="kubernetes\\.io/hostname"

  local -a helm_cmd
  helm_cmd=(
    helm upgrade --install
    -n "${NAMESPACE}"
    "${UERANSIM_RELEASE}"
    "${UERANSIM_CHART}"

    # masterIf in chart (UERANSIM values.yaml uses masterIf for its network attachment)
    --set "global.n2network.masterIf=${UERANSIM_NIC}"
    --set "global.n3network.masterIf=${UERANSIM_NIC}"

    # workload selector
    --set "gnb.nodeSelector.workload=${UERANSIM_WORKLOAD_VALUE}"
    --set "ue.nodeSelector.workload=${UERANSIM_WORKLOAD_VALUE}"

    # --set ue.command="./nr-ue -c ./config/ue-config.yaml -n 20"
  )

  if [[ "${PIN_TO_HOSTNAME}" == "1" ]]; then
    helm_cmd+=(
      --set "gnb.nodeSelector.${k8s_hostname_key}=${UERANSIM_NODE_NAME}"
      --set "ue.nodeSelector.${k8s_hostname_key}=${UERANSIM_NODE_NAME}"
    )
  fi

  # Convert array -> single safe shell string for your helper
  local cmd_str=""
  printf -v cmd_str '%q ' "${helm_cmd[@]}"

  command --run "${cmd_str}"

  ok "UERANSIM deploy command submitted."
}



# -----------------------------
# Entrypoint
# -----------------------------
usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  free5gc   Deploy only Free5GC
  ueransim  Deploy only UERANSIM
  status    Show pods in namespace
EOF
}

run_step05_deploy() {
  local cmd="${1:-}"

  validate_require_deploy_env || { warn "Missing exported env. Loading default env now."; step00_init_env; }
  require_tools || exit 1

  # For deploy commands we need chart paths
  case "${cmd}" in
  free5gc|ueransim)
    require_charts_layout || exit 1
    ;;
  esac


  case "${cmd}" in
    free5gc)  deploy_free5gc ;;
    ueransim) deploy_ueransim ;;
    status)   show_pods ;;
    *)        usage; exit 1 ;;
  esac
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

  HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
  LOADER_ENV_PATH="${ROOT_DIR}/scripts/00_load_env.sh"

  source "$HELPER_PATH"
  source "$LOADER_ENV_PATH"

  run_step05_deploy "$@"
fi