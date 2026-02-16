# docs/03_get_free5gc_charts.md — Fetch + Configure Free5GC Helm Charts (Free5GC + UERANSIM)

This script fetches the **Free5GC Helm charts repository** and (when used together with Step **031**) configures the charts so they match your **edge lab environment** (NICs, node placement, N6, UPF IPs, etc.).

Upstream repo:
- https://github.com/free5gc/free5gc-helm

---

## What it does

- Fetches the **Free5GC Helm charts repository** into `REPO_DIR`:
  - clones the repo if it does not exist
  - reuses the existing repo if it is already present (and may update/fetch depending on your script logic)
- (Optional) pins a specific chart version for reproducible experiments:
  - lists available tags
  - checks out a selected tag/commit
- Validates the chart folders exist under `CHARTS_DIR`:
  - `$CHARTS_DIR/free5gc`
  - `$CHARTS_DIR/ueransim`
- Configures the charts by applying your environment settings from free5gc.env
  - updates `$CHARTS_DIR/free5gc/values.yaml` and `$CHARTS_DIR/ueransim/values.yaml` using `free5gc.env`
  - sets interface/NIC fields (e.g., `masterIf`) to match your real NIC names:
    - Free5GC → `CORE5G_NIC`
    - UERANSIM → `UERANSIM_NIC` 
  - sets scheduling so pods land on the intended nodes:
    - Free5GC NFs → `nodeSelector.workload=<CORE5G_WORKLOAD_VALUE>`
    - UERANSIM → `nodeSelector.workload=<UERANSIM_WORKLOAD_VALUE>`
  - applies N6 network parameters if the chart supports them:
    - subnet, cidr prefix, gateway, exclude
  - applies fixed UPF N6 IPs if your setup uses them:
    - e.g., `UPF_IP0..UPF_IP6`


---

## Prerequisites

- `git` installed
- `free5gc.env` 

---

## How to run

From `installation/`:

    bash scripts/03_get_free5gc_charts.sh

---
