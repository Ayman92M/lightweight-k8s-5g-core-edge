# docs/02_cluster_setup.md — Cluster Setup (Helm, labels, PVs, worker prerequisites)

This script prepares the Kubernetes cluster **after the distro install** (Step 01).  
It’s a **common step**: the same logic should work regardless of whether you used K3s/k0s/MicroK8s, as long as `kubectl` can reach the cluster.

---

## What it does

- Verifies cluster access works (runs `kubectl get nodes`)
- Installs **Helm**
- (Optional) Installs Kubernetes Dashboard (if enabled in the script)
- Labels nodes for scheduling workloads:
  - labels the **Free5GC node** with `workload=<CORE5G_WORKLOAD_VALUE>`
  - labels the **UERANSIM node** with `workload=<UERANSIM_WORKLOAD_VALUE>`
- Prints **ACTION REQUIRED** worker prerequisites (so the deployment can actually work):
  - enable **PROMISC** mode on the relevant NIC(s)
  - install/load **gtp5g** kernel module on the UPF / core node (if required by your datapath)
- Prepares **local PVs** for storage (commonly MongoDB data + certs):
  - creates PV manifests pinned to the core node (node affinity by hostname)
  - expects directories like `PV_MONGO_DIR` and `PV_CERT_DIR` to exist on the target node filesystem

---

## Prerequisites

- Step 01 completed (cluster is up)
- `kubectl` works on the machine running the script
- Node names in config match real cluster node names (check with `kubectl get nodes`)
- If you will create local PVs:
  - the directories exist on the target node(s)
  - the node hostname used in PV affinity matches exactly

---

## Inputs (from `free5gc.env`)

Commonly used variables:

### Node scheduling
- `CORE5G_NODE_NAME` — node that will run Free5GC core NFs
- `UERANSIM_NODE_NAME` — node that will run UERANSIM (optional)
- `CORE5G_WORKLOAD_VALUE` — label value for core node (e.g., `core5g`)
- `UERANSIM_WORKLOAD_VALUE` — label value for ueransim node (e.g., `ueransim`)

### Storage (if PVs are created here)
- `PV_MONGO_NAME`, `PV_MONGO_DIR`
- `PV_CERT_NAME`, `PV_CERT_DIR`

---

## Outputs

- Helm installed and usable (verify with `helm version`)
- Nodes labeled for workload placement (verify with `kubectl get nodes --show-labels`)
- PVs created and available (verify with `kubectl get pv`)
- Clear worker prerequisites printed (PROMISC / gtp5g)

---

## How to run

From `installation/`, run:

    bash scripts/02_cluster_setup.sh

---

## Verify success

Helm:

    helm version

Node labels:

    kubectl get nodes --show-labels

PVs (if enabled):

    kubectl get pv
    kubectl get pvc -A

---

## Troubleshooting

### `kubectl get nodes` fails
- Step 01 didn’t finish correctly, or kubeconfig isn’t set.
- Check:
  - `echo $KUBECONFIG`
  - `ls -la ~/.kube/config`

### Pods stuck `Pending` later
- **Node selector mismatch**:
  - chart expects `workload=<value>` but node label differs
- **PV binding issue**:
  - PV directories missing on the target node
  - node affinity hostname mismatch

### Worker prerequisites not done
- If PROMISC / gtp5g is required and not applied, Free5GC dataplane or multi-interface behavior will break.
- Re-run the worker-side commands printed by the script, then continue.
