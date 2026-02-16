#!/usr/bin/env bash
# scripts/05_set_values.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
source "${ROOT_DIR}/helper_scripts/yaml_helpers.sh"

chart_require_env_vars() {

  local required_vars=(
    MASTER_BASE_DIR 

    CORE5G_WORKLOAD_VALUE UERANSIM_WORKLOAD_VALUE
    CORE5G_NIC UERANSIM_NIC
    N6_SUBNET N6_CIDR N6_GATEWAY N6_EXCLUDE
    UPF_IP0 UPF_IP1 UPF_IP2 UPF_IP3 UPF_IP4 UPF_IP5 UPF_IP6

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

detect_chart_paths() {
  local base="${MASTER_BASE_DIR}"
  local charts="${CHARTS_DIR:-}"

  if [[ -z "${charts}" ]]; then
    if [[ -d "${base}/free5gc-helm/charts" ]]; then
      charts="${base}/free5gc-helm/charts"
    elif [[ -d "${base}/charts" ]]; then
      charts="${base}/charts"
    fi
  fi

  CHARTS_DIR="${charts}"
  [[ -n "${CHARTS_DIR:-}" ]] || { warn "CHARTS_DIR could not be detected"; return 1; }

  FREE5GC_VALUES="${CHARTS_DIR}/free5gc/values.yaml"
  UERANSIM_VALUES="${CHARTS_DIR}/ueransim/values.yaml"

  [[ -f "${FREE5GC_VALUES}" ]] || { warn "Missing file: ${FREE5GC_VALUES}"; return 1; }
  [[ -f "${UERANSIM_VALUES}" ]] || { warn "Missing file: ${UERANSIM_VALUES}"; return 1; }
}

set_free5gc_values() {
  title "Set values.yaml: Free5GC"

  local f="${FREE5GC_VALUES}"
  local w="${CORE5G_WORKLOAD_VALUE}"

  info "File: $f"
  yaml_backup_once "$f"

  # masterIf everywhere
  yaml_set_all_scalar_keys "$f" "masterIf" "${CORE5G_NIC}"

  # global.n6network (only if chart has it)
  if yaml_path_exists "$f" "global.n6network"; then
    yaml_upsert_scalar_path "$f" "global.n6network.subnetIP"  "${N6_SUBNET}"
    yaml_upsert_scalar_path "$f" "global.n6network.cidr"      "${N6_CIDR}"
    yaml_upsert_scalar_path "$f" "global.n6network.gatewayIP" "${N6_GATEWAY}"
    yaml_upsert_scalar_path "$f" "global.n6network.excludeIP" "${N6_EXCLUDE}"
    yaml_upsert_scalar_path "$f" "global.n6network.masterIf"  "${CORE5G_NIC}"
  fi

  # keep other global networks masterIf aligned if they exist
  for net in n2network n3network n4network n9network; do
    if yaml_path_exists "$f" "global.${net}"; then
      yaml_upsert_scalar_path "$f" "global.${net}.masterIf" "${CORE5G_NIC}"
    fi
  done

  # mongodb selector (does not touch other mongodb defaults)
  if yaml_path_exists "$f" "mongodb"; then
    yaml_upsert_scalar_path "$f" "mongodb.nodeSelector.workload" "$w"
    
  fi

  # free5gc-nrf special: add nrf: sibling to db: without touching db.enabled=false
  if yaml_path_exists "$f" "free5gc-nrf"; then
    yaml_upsert_scalar_path "$f" "free5gc-nrf.nrf.nodeSelector.workload" "$w"
  fi

  # other NFs: ALWAYS upsert (adds missing ones at end)
  declare -a nf_paths=(
    "free5gc-amf.amf.nodeSelector.workload"
    "free5gc-ausf.ausf.nodeSelector.workload"
    "free5gc-chf.chf.nodeSelector.workload"
    "free5gc-dbpython.dbpython.nodeSelector.workload"
    "free5gc-nef.nef.nodeSelector.workload"
    "free5gc-nssf.nssf.nodeSelector.workload"
    "free5gc-pcf.pcf.nodeSelector.workload"
    "free5gc-smf.smf.nodeSelector.workload"
    "free5gc-udm.udm.nodeSelector.workload"
    "free5gc-udr.udr.nodeSelector.workload"
    "free5gc-webui.webui.nodeSelector.workload"
  )
  for p in "${nf_paths[@]}"; do
    yaml_upsert_scalar_path "$f" "$p" "$w"
  done

  # UPF selectors + IPs
  for u in upf upf1 upf2 upfb iupf1 psaupf1 psaupf2; do
    yaml_upsert_scalar_path "$f" "free5gc-upf.${u}.nodeSelector.workload" "$w"
  done

  yaml_upsert_scalar_path "$f" "free5gc-upf.upf.n6if.ipAddress"     "${UPF_IP0}"
  yaml_upsert_scalar_path "$f" "free5gc-upf.upf1.n6if.ipAddress"    "${UPF_IP1}"
  yaml_upsert_scalar_path "$f" "free5gc-upf.upf2.n6if.ipAddress"    "${UPF_IP2}"
  yaml_upsert_scalar_path "$f" "free5gc-upf.upfb.n6if.ipAddress"    "${UPF_IP3}"
  yaml_upsert_scalar_path "$f" "free5gc-upf.iupf1.n6if.ipAddress"   "${UPF_IP4}"
  yaml_upsert_scalar_path "$f" "free5gc-upf.psaupf1.n6if.ipAddress" "${UPF_IP5}"
  yaml_upsert_scalar_path "$f" "free5gc-upf.psaupf2.n6if.ipAddress" "${UPF_IP6}"

  ok "Free5GC values.yaml updated."
}

set_ueransim_values() {
  title "Set values.yaml: UERANSIM"

  local f="${UERANSIM_VALUES}"
  local w="${UERANSIM_WORKLOAD_VALUE}"
  local nic="${UERANSIM_NIC:-${CORE5G_NIC}}"

  info "File: $f"
  yaml_backup_once "$f"

  yaml_set_all_scalar_keys "$f" "masterIf" "${nic}"

  # FIX: nodeSelector: {} breaks YAML when we add workload under it
  sed -i -E 's/^([[:space:]]*nodeSelector:)[[:space:]]*\{[[:space:]]*\}[[:space:]]*$/\1/' "$f"

  yaml_upsert_scalar_path "$f" "gnb.nodeSelector.workload" "$w"
  yaml_upsert_scalar_path "$f" "ue.nodeSelector.workload" "$w"

  ok "UERANSIM values.yaml updated."
}


set_charts_values() {
  title "Set Helm chart values based on exported env"
  chart_require_env_vars || { warn "Missing exported env. Loading default env now."; step00_init_env; }
  detect_chart_paths || { warn "Could not detect chart paths. Make sure MASTER_BASE_DIR is correct and charts are present."; return 1; }
  set_free5gc_values
  set_ueransim_values

}



if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

  source "${ROOT_DIR}/helper_scripts/bash_helper.sh"
  source "${ROOT_DIR}/scripts/00_load_env.sh"
  
  set_charts_values
fi