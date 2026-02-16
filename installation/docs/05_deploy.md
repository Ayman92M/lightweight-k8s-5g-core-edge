# docs/05_deploy.md — Deploy Free5GC +  UERANSIM (Helm install/upgrade + status)

This script deploys the workloads using **Helm**:
- **Free5GC** (5G Core)
- **UERANSIM** (RAN simulator)

---

## What it does

- Ensures the target namespace exists (or creates it)
- Deploys **Free5GC** using Helm (`upgrade --install`)
- Deploys **UERANSIM** using Helm (`upgrade --install`)
- Provides a simple status view:
  - `kubectl get pods -n <namespace> -o wide`

Recommended order:
1) Deploy **Free5GC**
2) Wait until core pods are **Running/Ready**
3) Deploy **UERANSIM** 

---

## Prerequisites

- Step 02 done: Helm installed and nodes labeled
- Step 03 done: charts fetched (`$CHARTS_DIR/free5gc` and `$CHARTS_DIR/ueransim` exist)
- Step 031 done: `values.yaml` patched for your environment (NICs, nodeSelectors, N6, UPF IPs, etc.)
- Step 04 done: CNI stack ready (Multus/Whereabouts if multi-network is required)
- `kubectl` access working on the machine running the script

---

## Inputs (from `free5gc.env`)

Typical variables used:

- `NAMESPACE` — Kubernetes namespace to deploy into
- `FREE5GC_RELEASE` — Helm release name for Free5GC
- `UERANSIM_RELEASE` — Helm release name for UERANSIM
- `CHARTS_DIR` — must contain:
  - `$CHARTS_DIR/free5gc`
  - `$CHARTS_DIR/ueransim`

---


## How to run

From `installation/`:

```bash
installation/scripts/05_deploy.sh <command>

Commands:
  free5gc   Deploy only Free5GC
  ueransim  Deploy only UERANSIM
---