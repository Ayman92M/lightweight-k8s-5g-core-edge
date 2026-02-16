# Modular Edge Builder for Lightweight Kubernetes + 5G Core (Free5GC)

This repository provides a lab setup to deploy Free5GC + UERANSIM on a lightweight Kubernetes cluster for edge testing.


[`installation/main.sh`](main.sh) is an **interactive, menu-driven installer** that:
- sets up a **lightweight Kubernetes cluster** 
- deploys **Free5GC** (5G Core) and **UERANSIM**

It’s built around a simple idea: **shared workflow steps stay stable**, while **Kubernetes distro** and **CNI stack** are pluggable.

---

## High-level pipeline

| Step | What happens | Type |
|---:|---|---|
| 0 | Load config (`free5gc.env`) | Common |
| 1 | Choose + install lightweight Kubernetes distro | Pluggable |
| 2 | Cluster setup (Helm, labels, PVs/storage prep, worker prerequisites) | Common |
| 3 | Fetch charts + apply config to Helm values | Common |
| 4 | Choose + install CNI stack | Pluggable |
| 5 | Deploy 5G Core + (optional) RAN simulator (UERANSIM) | Common |


---

## Current status

### ✅ Implemented
- **Shared workflow steps:** **0, 2, 3, 5**
- **Kubernetes distro (Step 1):** K3s
- **CNI stack (Step 4):** Multus + Whereabouts
- **Workloads:** Free5GC + UERANSIM

### 🧩 Planned (TODO)
- **Kubernetes distros:** k0s, MicroK8s, k8s
- **Additional CNI stacks:** 

---

## Quick start

From repo root:

```bash
cd installation
chmod +x main.sh scripts/*.sh helper_scripts/*.sh
./main.sh
```

Recommended workflow:
1) Edit [`installation/free5gc.env`](free5gc.env)
2) Run [`./main.sh`](main.sh)
3) Follow prompts: **distro → setup → charts/values → CNI → deploy**

---

## How it works

[`installation/main.sh`](main.sh) is the **orchestrator**:
- sources helper libraries from `helper_scripts/`
- sources step scripts from `scripts/`
- shows menus for **Step 1 (distro)** and **Step 4 (CNI)**
- runs steps in order and **stops on errors** 

It typically pauses between major steps using a **yes/no confirmation**, so you can review output and choose whether to continue.

---

## Step responsibilities

| Step | Name | Responsible for | Where it lives |
|---:|---|---|---|
| 0 | Config (load + validate) | Load [`free5gc.env`](free5gc.env), validate required values, export variables | Sourced by [`scripts/00_load.env.sh`](scripts/00_load_env.sh) |
| 1 | [Kubernetes distro (install + bring-up)](docs/01_install_k3s.md) | Install chosen distro, verify control-plane, set kubeconfig, print join instructions, verify `kubectl get nodes` |  (e.g., [`scripts/01_install_k3s.sh`](scripts/01_install_k3s.sh)) |
| 2 | [Cluster setup (post-install prep)](docs/02_cluster_setup.md) | Install Helm, optional add-ons, label nodes, storage/PV guidance, print **ACTION REQUIRED** prerequisites (e.g., promisc, gtp5g) | [`scripts/02_cluster_setup.sh`](scripts/02_cluster_setup.sh) |
| 3 | [Charts & values (config layer)](docs/03_get_free5gc_charts.md) | Clone charts, checkout tag/commit, patch `values.yaml` (NICs, N6 subnet, nodeSelectors, UPF N6 IPs, etc.), keep versions reproducible | [`scripts/03_get_free5gc_charts.sh`](scripts/03_get_free5gc_charts.sh), [`scripts/031_set_values.sh`](scripts/031_set_values.sh), [`helper_scripts/yaml_helpers.sh`](helper_scripts/yaml_helpers.sh) |
| 4 | [CNI (network stack choice)](docs/04_install_multus.md) | Install chosen CNI, enable multi-networking/IPAM, wait for readiness, verify networking layer | (e.g., [`scripts/04_install_multus.sh`](scripts/04_install_multus.sh)) |
| 5 | [Deploy (install/upgrade + status)](docs/05_deploy.md) | Helm install/upgrade, deploy order (Free5GC → UERANSIM), show basic status/sanity checks | [`scripts/05_deploy.sh`](scripts/05_deploy.sh) |

---


## Docs

- [Step 1 — Install K3s](docs/01_install_k3s.md)
- [Step 2 — Cluster setup](docs/02_cluster_setup.md)
- [Step 3 — Get Free5GC charts](docs/03_get_free5gc_charts.md)
- [Step 5 — Deploy](docs/05_deploy.md)
