#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
LOADER_ENV_PATH="${ROOT_DIR}/scripts/00_load_env.sh"

LOADER_ENV_PATH="${ROOT_DIR}/scripts/00_load_env.sh"
INSTALL_K3S_PATH="${ROOT_DIR}/scripts/01_install_k3s.sh"
CLUSTER_SETUP_PATH="${ROOT_DIR}/scripts/02_cluster_setup.sh"
GET_CHARTS_PATH="${ROOT_DIR}/scripts/03_get_free5gc_charts.sh"
SET_VALUES_PATH="${ROOT_DIR}/scripts/031_set_values.sh"
INSTALL_MULTUS_PATH="${ROOT_DIR}/scripts/04_install_multus.sh"
DEPLOY_PATH="${ROOT_DIR}/scripts/05_deploy.sh"


source "${HELPER_PATH}"
source "${LOADER_ENV_PATH}"

source "${INSTALL_K3S_PATH}"
source "${CLUSTER_SETUP_PATH}"
source "${GET_CHARTS_PATH}"
source "${SET_VALUES_PATH}"
source "${INSTALL_MULTUS_PATH}"
source "${DEPLOY_PATH}"


# -----------------------------
# Globals (chosen during this run)
# -----------------------------
K8S_DISTRO="${K8S_DISTRO:-}"         # k3s | k0s | microk8s | etc
HELM_ACTION="${HELM_ACTION:-}"       # install | skip
CNI_CHOICE="${CNI_CHOICE:-}"         # multus  | etc
DEPLOY_CHOICE="${DEPLOY_CHOICE:-}"   # free5gc | ueransim | none


# -----------------------------
# Step 01: Choose lightweight k8s
# -----------------------------
step01_choose_lightweight_k8s() {
  title "Step 01 - Choose lightweight Kubernetes"

  while true; do
    echo "1) k3s"
    echo "2) k0s (not implemented yet)"
    echo "3) microk8s (not implemented yet)"
    echo "4) full K8s (not implemented yet)"
    echo "5) Skip / none"
    echo
    printf "Choose (1-5) [default: 1]: "
    local choice=""
    IFS= read -r choice
    choice="${choice:-1}"

    case "$choice" in
      1)
        K8S_DISTRO="k3s"
        ok "Chosen lightweight k8s: ${K8S_DISTRO}"
        run_step01_k3s
        break
        ;;
      2)
        K8S_DISTRO="k0s"
        ok "Chosen lightweight k8s: ${K8S_DISTRO}"
        info "(Later: TODO implement install_${K8S_DISTRO}. 01_install_k0s.sh.)"
        break
        ;;
      3)
        K8S_DISTRO="microk8s"
        ok "Chosen lightweight k8s: ${K8S_DISTRO}"
        info "(Later: TODO implement install_${K8S_DISTRO}. 01_install_microk8s.sh.)"
        break
        ;;
      4)
        K8S_DISTRO="K8s"
        ok "Chosen k8s: ${K8S_DISTRO}"
        info "(Later: TODO implement install_${K8S_DISTRO}. 01_install_k8s.sh.)"
        break
        ;;
      5)
        K8S_DISTRO="none"
        warn "No Kubernetes distro will be installed. Chosen: ${K8S_DISTRO}"
        break
        ;;
      *)
        warn "Invalid choice: '$choice' (please choose 1, 2, 3, 4, or 5)"
        ;;
    esac
  done

  info "(Next: Step 02 - Helm configuration.)"
}


# -----------------------------
# Step 02: Configure cluster setup
# -----------------------------
step02_cluster_setup() {
  title "Step 02 - cluster_setup"

  if ask_yn "Run cluster setup (Helm, labels, etc.)?" Y; then
    
    HELM_ACTION="install and configure Helm"
    ok "Helm action: ${HELM_ACTION}"
    run_step02_cluster_setup

  else
    HELM_ACTION="skip"
    warn "Helm action: ${HELM_ACTION}"
  fi
  info "(Next: Step 03 - Get Free5GC Helm charts.)"
}


# -----------------------------
# Step 03: Get Free5GC Helm charts
# -----------------------------
step03_get_free5gc_charts() {
  title "Step 03 - Get Free5GC Helm charts"

  if ask_yn "Get Free5GC Helm charts and set values?" Y; then
    run_step03_get_free5gc_charts
  else
    warn "Skipping getting charts and setting values."
  fi

  info "(Next: Step 04 - CNI choice.)"
}



# -----------------------------
# Step 04: Install CNI
# -----------------------------
step04_choose_cni() {
  title "Step 04 - CNI"

  while true; do
    echo "Choose CNI to install/configure:"
    echo "1) multus"
    echo "2) calico (not implemented yet) - in case we need it"
    echo "3) cilium (not implemented yet) - in case we need it"
    echo "4) flannel (not implemented yet) - in case we need it"
    echo "5) none / skip"
    echo
    printf "Choose (1-5) [default: 5]: "
    local choice=""
    IFS= read -r choice
    choice="${choice:-5}"

    case "$choice" in
      1) CNI_CHOICE="multus"; 
         ok "Chosen CNI: ${CNI_CHOICE}"
         run_step04_install_multus
         break 
         ;;
      2) CNI_CHOICE="calico"; break ;;
      3) CNI_CHOICE="cilium"; break ;;
      4) CNI_CHOICE="flannel"; break ;;
      5) CNI_CHOICE="skip"; break ;;
      *)
        warn "Invalid choice: '$choice' (please choose 1-5)"
        continue
        ;;
    esac
  done

  ok "Chosen CNI: ${CNI_CHOICE}"
  info "(Next: Step 05 - Deploy Free5GC and UERANSIM.)"
}



# -----------------------------
# Step 05: Deploy
# -----------------------------
step05_choose_deploy() {
  title "Step 05 - Deploy (loop mode)"

  warn "Free5gc must be deployed before UERANSIM"
  warn "Choose 3 to check pod status in the namespace (to verify if free5gc is ready before deploying UERANSIM)."
  warn "Otherwise ueransim (gnb) will fail to deploy if free5gc isn't ready yet."

  while true; do
    echo
    echo "Deploy menu (namespace: ${NAMESPACE}):"
    echo "1) Deploy (free5gc): ${FREE5GC_RELEASE}"
    echo "2) Deploy (ueransim): ${UERANSIM_RELEASE}"
    echo "3) Show pods (kubectl get pods -n ${NAMESPACE} -o wide)"
    echo "4) Done / exit deploy step"
    echo
    

    printf "Choose (1-4) [default: 3]: "
    local choice=""
    IFS= read -r choice
    choice="${choice:-3}"

    case "$choice" in
      1)
        DEPLOY_CHOICE="free5gc"
        ok "Selected deploy: ${DEPLOY_CHOICE}"
        run_step05_deploy free5gc
        ;;
      2)
        DEPLOY_CHOICE="ueransim"
        ok "Selected deploy: ${DEPLOY_CHOICE}"
        run_step05_deploy ueransim
        ;;

      3)
        title "Pods in namespace '${NAMESPACE}'"
        run_step05_deploy status
        ;;
      4)
        ok "Exiting Step 05."
        break
        ;;
      *)
        warn "Invalid choice: '$choice' (please choose 1-4)"
        ;;
    esac
  done
}


print_choices() {
  title "Selected choices (this run)"
  cat <<EOF
K8S_DISTRO=${K8S_DISTRO}
CNI_CHOICE=${CNI_CHOICE}
EOF
}

main() {

  step00_init_env

  step01_choose_lightweight_k8s
  step02_cluster_setup
  step03_get_free5gc_charts
  step04_choose_cni
  step05_choose_deploy

  
  print_choices

  ok "Main selection flow completed."
}

main "$@"
