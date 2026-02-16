# docs/04_install_multus.sh — Install Multus + Whereabouts (CNI)

This script installs **Multus** (multi-network CNI) and **Whereabouts** (IPAM) so Kubernetes pods can attach **multiple network interfaces** — required for many **5G Core / Free5GC** deployments.

---

## What it does

- Installs **Multus** in the cluster (usually in `kube-system`)
- Enables/installs **Whereabouts** for secondary IP allocation
- Waits for Multus components to become ready

---

## How to run

From `installation/`:

    bash scripts/04_install_multus.sh

---

## Verify

Check Multus is running:

    kubectl -n kube-system get pods -o wide | grep -i multus
    kubectl -n kube-system get ds | grep -i multus

check Whereabouts:

    kubectl -n kube-system get pods -o wide | grep -i where

---