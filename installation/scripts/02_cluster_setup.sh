#!/usr/bin/env bash
set -euo pipefail




# -----------------------------
# Guards
# -----------------------------
validate_require_env_cluster_setup() {

  local required_vars=(
    CORE5G_WORKLOAD_VALUE CORE5G_NODE_NAME
    UERANSIM_WORKLOAD_VALUE UERANSIM_NODE_NAME
    PV_MONGO_NAME PV_CERT_NAME
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

require_kubectl_ready() {
  if ! builtin command -v kubectl >/dev/null 2>&1; then
    warn "kubectl not found in PATH."
    return 1
  fi
  if ! kubectl get nodes >/dev/null 2>&1; then
    warn "kubectl cannot access the cluster (check KUBECONFIG)."
    return 1
  fi
  return 0
}

# -----------------------------
# install_helm
# -----------------------------
install_helm() {
  title "Install Helm (master node)"

  need_sudo || { warn "sudo required"; return 1; }

  info "Install prerequisites"
  command --run "sudo apt-get update"
  command --run "sudo apt-get install -y curl gpg apt-transport-https"

  info "Add Helm apt repository key"
  command --run "curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg >/dev/null"

  info "Add Helm apt repository"
  command --run "echo 'deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null"

  info "Install Helm"
  command --run "sudo apt-get update"
  command --run "sudo apt-get install -y helm"

  info "Verify Helm"
  command --run "helm version"
  ok "Helm installed."
}

# -----------------------------
# install_k8s_dashboard
# -----------------------------
install_k8s_dashboard() {
  title "Kubernetes Dashboard (via Helm)"

  if ! require_kubectl_ready; then
    warn "kubectl not ready; skipping dashboard."
    return 0
  fi
  if ! builtin command -v helm >/dev/null 2>&1; then
    warn "helm not found; install Helm first."
    return 1
  fi

  info "Add dashboard Helm repo"
  command --run "helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/"

  info "Install/upgrade dashboard"
  command --run "helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard"

  ok "Dashboard installed."
  
  create_dashboard_admin_token
  dashboard_port_forward_instructions
}


create_dashboard_admin_token() {
  title "Create Dashboard admin token (MASTER node)"

  info "Create ServiceAccount + ClusterRoleBinding + long-lived token Secret for Dashboard login"
  command --run "cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-admin-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
YAML"

  info "Fetch Dashboard login token (wait until secret is populated)"

  local dash_token=""
  for i in {1..30}; do
    local tok_b64
    tok_b64=$(kubectl -n kubernetes-dashboard get secret dashboard-admin-token \
      -o jsonpath='{.data.token}' 2>/dev/null || true)

    if [[ -n "$tok_b64" ]]; then
      dash_token=$(echo "$tok_b64" | base64 -d)
      break
    fi
    sleep 1
  done

  if [[ -z "$dash_token" ]]; then
    warn "Token not ready yet."
    warn "Try manually:"
    command "kubectl -n kubernetes-dashboard get secret dashboard-admin-token -o jsonpath='{.data.token}' | base64 -d"
    exit 1
  fi

  local token_file="$HOME/dash_board_token"
  printf "%s\n" "$dash_token" > "$token_file"
  chmod 600 "$token_file"

  ok "Dashboard token saved to: $token_file"
  info "To view it later:"
  info "cat $token_file"

  info "Dashboard token:"
  printf "%s\n" "$dash_token"
}

dashboard_port_forward_instructions() {
  title "Access Dashboard (port-forward via SSH)"

  do_step "Run this on your local machine (keep it running):" "$(cat <<'EOF'
ssh master -L 8443:127.0.0.1:8443 \
  'KUBECONFIG=$HOME/.kube/config kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443'
EOF
)" || { warn "User aborted."; exit 1; }

  info "When the port-forward is running, open:"
  info "https://127.0.0.1:8443"
  pause
}

# -----------------------------
# label_nodes_workload
# -----------------------------
label_nodes_workload() {
  title "Label nodes using exported env values"

  if ! require_kubectl_ready; then
    warn "kubectl not ready; skipping labeling."
    return 0
  fi

  info "Planned labels:"
  info "  CORE5G_NODE_NAME=${CORE5G_NODE_NAME}  -> workload=${CORE5G_WORKLOAD_VALUE}"
  info "  UERANSIM_NODE_NAME=${UERANSIM_NODE_NAME} -> workload=${UERANSIM_WORKLOAD_VALUE}"
  command --run "kubectl get nodes -L workload || true"

  if ! ask_yn "Apply these workload labels now?" Y; then
    warn "Skipped node labeling."
    return 0
  fi

  # CORE5G node
  command --run "kubectl label node \"${CORE5G_NODE_NAME}\" \"workload=${CORE5G_WORKLOAD_VALUE}\" --overwrite"
  ok "Labeled ${CORE5G_NODE_NAME} workload=${CORE5G_WORKLOAD_VALUE}"

  # UERANSIM node 
  command --run "kubectl label node \"${UERANSIM_NODE_NAME}\" \"workload=${UERANSIM_WORKLOAD_VALUE}\" --overwrite"
  ok "Labeled ${UERANSIM_NODE_NAME} workload=${UERANSIM_WORKLOAD_VALUE}"

  info "Result:"
  command --run "kubectl get nodes -L workload"
}


# -----------------------------
# worker_promisc_instructions
# -----------------------------
worker_promisc_instructions() {
  title "Worker node: enable PROMISC mode (instructions)"

  do_step "Run on the WORKER node (default NIC) to enable PROMISC:" "$(cat <<'EOF'
NIC=$(ip route show default | awk '{print $5; exit}')
echo "Using NIC: $NIC"
sudo ip link set "$NIC" promisc on
ip link show "$NIC" | grep -q PROMISC && echo "PROMISC enabled" || echo "PROMISC NOT enabled"
EOF
)"
}

# -----------------------------
# install_gtp5g_instructions
# -----------------------------
install_gtp5g_instructions() {
  title "CORE5G worker node: install gtp5g kernel module (instructions)"

  do_step "Run on the CORE5G WORKER node:" "$(cat <<'EOF'
sudo apt -y update
sudo apt -y install git gcc g++ cmake autoconf libtool pkg-config libmnl-dev libyaml-dev

git clone https://github.com/free5gc/gtp5g.git
cd gtp5g
make clean && make
sudo make install

sudo modprobe gtp5g
lsmod | grep gtp5g

# Optional: load after reboot
# echo gtp5g | sudo tee /etc/modules-load.d/gtp5g.conf
EOF
)"
}

# -----------------------------
# create_free5gc_pvs
# -----------------------------
create_free5gc_pvs() {
  title "Create Free5GC PVs (mongo + cert)"

  if ! require_kubectl_ready; then
    warn "kubectl not ready; skipping PV creation."
    return 0
  fi

  info "CORE5G_NODE_NAME=${CORE5G_NODE_NAME}"
  info "PV_MONGO_NAME=${PV_MONGO_NAME}"
  info "PV_CERT_NAME=${PV_CERT_NAME}"
  info "PV_MONGO_DIR=${PV_MONGO_DIR}"
  info "PV_CERT_DIR=${PV_CERT_DIR}"

  warn "IMPORTANT: PV directories must exist ON the CORE5G WORKER node filesystem."
  do_step "Run on CORE5G worker '${CORE5G_NODE_NAME}' to create PV directories:" "$(cat <<EOF
mkdir -p "${PV_MONGO_DIR}" "${PV_CERT_DIR}"

ls -ld "${PV_MONGO_DIR}" "${PV_CERT_DIR}"
EOF
)"

  info "Applying PV objects"
  command --run "cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${PV_MONGO_NAME}
  labels:
    project: free5gc
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: ${PV_MONGO_DIR}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - ${CORE5G_NODE_NAME}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${PV_CERT_NAME}
  labels:
    project: free5gc
spec:
  capacity:
    storage: 2Mi
  accessModes:
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: ${PV_CERT_DIR}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - ${CORE5G_NODE_NAME}
EOF"

  ok "PVs applied."
  command --run "kubectl get pv | grep -E \"${PV_MONGO_NAME}|${PV_CERT_NAME}\" || true"
}




run_step02_cluster_setup() {

  if ! validate_require_env_cluster_setup; then
    info "Some required env variables are missing, Loading free5gc.env and exporting them now..."
    step00_init_env
  fi

  if require_kubectl_ready; then
    ok "kubectl is ready."
  else
    warn "kubectl is not ready yet. Please ensure your cluster is up and KUBECONFIG is set correctly."
    exit 1
  fi

  install_helm

  if ask_yn "Install Kubernetes Dashboard (via Helm)?" Y; then
    install_k8s_dashboard
  else
    warn "Skipping Kubernetes Dashboard."
  fi

  label_nodes_workload

  worker_promisc_instructions
  install_gtp5g_instructions

  if ask_yn "Create/apply Free5GC PVs now (mongo + cert)?" Y; then
    create_free5gc_pvs
  else
    warn "Skipping PV creation."
  fi

  ok "Step 02 completed."
}

# If executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"


  HELPER_PATH="${ROOT_DIR}/helper_scripts/bash_helper.sh"
  LOADER_ENV_PATH="${ROOT_DIR}/scripts/00_load_env.sh"

  source "$HELPER_PATH"
  source "$LOADER_ENV_PATH"

  run_step02_cluster_setup
fi
