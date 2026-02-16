#!/usr/bin/env bash
set -euo pipefail


run_step04_install_multus() {
  title "Install Multus (K3s HelmChart) + Whereabouts"
  info "This will install Multus CNI using the RKE2 HelmChart, which is compatible with K3s clusters. It also enables the Whereabouts IPAM plugin for better IP management of secondary interfaces."
  
  command --run "cat <<EOF | kubectl apply -f -
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: multus
  namespace: kube-system
spec:
  repo: https://rke2-charts.rancher.io
  chart: rke2-multus
  targetNamespace: kube-system
  valuesContent: |-
    config:
      fullnameOverride: multus
      cni_conf:
        confDir: /var/lib/rancher/k3s/agent/etc/cni/net.d
        binDir: /var/lib/rancher/k3s/data/cni/
        kubeconfig: /var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d/multus.kubeconfig
        multusAutoconfigDir: /var/lib/rancher/k3s/agent/etc/cni/net.d

    rke2-whereabouts:
      fullnameOverride: whereabouts
      enabled: true
      cniConf:
        confDir: /var/lib/rancher/k3s/agent/etc/cni/net.d
        binDir: /var/lib/rancher/k3s/data/cni/

EOF"

  info "Waiting for Multus DaemonSet to appear..."
  local ds=""
  for i in {1..180}; do
    if kubectl -n kube-system get ds multus >/dev/null 2>&1; then
      ds="daemonset.apps/multus"
      ok "Found Multus DaemonSet: ${ds}"
      break
    fi
    sleep 1
  done

  if [[ -z "$ds" ]]; then
    warn "Timed out waiting for Multus DaemonSet to be created."
    info "Debug:"
    command --run "kubectl -n kube-system get helmchart multus -o yaml || true"
    command --run "kubectl -n kube-system get ds | grep -i multus || true"
    return 1
  fi

  info "Waiting for Multus DaemonSet rollout to complete..."
  command --run "kubectl -n kube-system rollout status ${ds} --timeout=5m"

  # Some clusters use different labels; keep your original but also fallback.
  info "Waiting for Multus pods to be Ready..."
  if ! kubectl -n kube-system wait --for=condition=Ready pods -l app=rke2-multus --timeout=5m >/dev/null 2>&1; then
    warn "Label app=rke2-multus did not match pods; trying a broader match..."
    command --run "kubectl -n kube-system get pods -o wide | grep -i multus || true"
  else
    ok "Multus pods Ready (app=rke2-multus)."
  fi

  ok "Multus is installed. Step 04 complete."

  info "Multus DaemonSet:"
  command --run "kubectl -n kube-system get ds multus -o wide || true"

  
}


# If executed directly, run it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

  # Resolve to the directory where THIS script lives
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

  HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
  LOADER_ENV_PATH="${ROOT_DIR}/scripts/00_load_env.sh"

  source "$HELPER_PATH"
  source "$LOADER_ENV_PATH"

  run_step04_install_multus
fi
