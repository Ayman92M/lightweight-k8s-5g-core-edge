#!/usr/bin/env bash
set -euo pipefail

# Resolve to the directory where THIS script lives
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"



# -----------------------------
# K3s functions
# -----------------------------


install_k3s() {
  title "--- Installing K3s ---"
  info "Install K3s using the official installation script"
  command --run "curl -sfL https://get.k3s.io | sh -"
  ok "K3s installation complete!"

  command "sudo systemctl is-active --quiet k3s;"
  if sudo systemctl is-active --quiet k3s; then
    ok "K3s service is running."
  else
    warn "K3s service is not running. Please check the installation logs."
    exit 1
  fi
}

show_k3s_info() {
  title "- K3s info -"

  local k3s_version
  k3s_version="$(sudo k3s --version)"
  info "$k3s_version"

  printf "\n"
  info "Cluster info"
  command --run "sudo k3s kubectl cluster-info"

  info "Node status"
  command --run "sudo k3s kubectl get nodes"

  info "All namespaces"
  command --run "sudo k3s kubectl get namespaces"

  info "All pvcs in all namespaces"
  command --run "sudo k3s kubectl get pvc --all-namespaces"

  info "All pods in all namespaces"
  command --run "sudo k3s kubectl get pods --all-namespaces"
}

print_join_agent_instructions() {
  title "Join agent/worker nodes to the cluster"

  info "Token for joining agent nodes:"
  command "sudo cat /var/lib/rancher/k3s/server/node-token"
  local token
  token="$(sudo cat /var/lib/rancher/k3s/server/node-token)"
  echo -e "$token\n"

  info "Detect server IP (first IPv4 address from hostname -I)"
  local server_ip
  server_ip="$(hostname -I | awk '{print $1}')"
  echo -e "Server IP: $server_ip\n"

  do_step \
    "Run on the agent/worker nodes:" \
    $'curl -sfL https://get.k3s.io | K3S_URL=https://'"$server_ip"':6443 K3S_TOKEN='"$token"' sh -'
}

configure_kubectl_access() {
  title "Configure kubectl access (Master node) - fresh system"

  local K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  local USER_KUBECONFIG="$HOME/.kube/config"

  info "Create ~/.kube and copy K3s kubeconfig there (user-owned)"
  command --run "mkdir -p '$HOME/.kube'"
  command --run "sudo cp '$K3S_KUBECONFIG' '$USER_KUBECONFIG'"
  command --run "sudo chown '$USER:$USER' '$USER_KUBECONFIG'"
  command --run "chmod 600 '$USER_KUBECONFIG'"

  info "Persist KUBECONFIG for new shells"
  command --run "grep -qxF 'export KUBECONFIG=\$HOME/.kube/config' ~/.bashrc || echo 'export KUBECONFIG=\$HOME/.kube/config' >> ~/.bashrc"
  command --run "grep -qxF 'export KUBECONFIG=\$HOME/.kube/config' ~/.profile || echo 'export KUBECONFIG=\$HOME/.kube/config' >> ~/.profile"

  info "Apply for this session"
  export KUBECONFIG="$USER_KUBECONFIG"
  info "KUBECONFIG=$KUBECONFIG"

  info "Verify kubectl access"
  command --run "kubectl get nodes"
  ok "kubectl access configured successfully!"
}

# -----------------------------
# Callable entrypoint
# -----------------------------
run_step01_k3s() {

  need_sudo
  apt_update

  install_k3s
  show_k3s_info
  print_join_agent_instructions
  configure_kubectl_access
  ok "K3s - step 01 finished."

}

# If executed directly, run it.
# If sourced, main.sh can call run_step01_k3s.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  
  HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
  source "$HELPER_PATH"
  run_step01_k3s
fi
