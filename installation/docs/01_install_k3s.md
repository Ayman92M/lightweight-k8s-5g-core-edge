# docs/01_install_k3s.md — Install K3s Server (Master)

This script installs a **K3s server (master/control-plane)** on the machine you run it on, prints a **worker join command**, and sets up **kubectl** access so you can start using the cluster quickly.

Official docs:
- Quick Start: https://docs.k3s.io/quick-start
- Installation: https://docs.k3s.io/installation
- Cluster access (kubeconfig): https://docs.k3s.io/cluster-access

---

## What it does

- Updates apt (`apt-get update`)
- Installs K3s server using the official installer:
  - `curl -sfL https://get.k3s.io | sh -`
- Checks that the `k3s` service is running
- Shows basic cluster status:
  - `kubectl get nodes`
  - `kubectl get ns`
  - `kubectl get pods -A`
- Prints:
  - the server **node token**
  - a ready-to-copy **join command** for workers
- Makes `kubectl` easier to use by configuring kubeconfig for the current user:
  - copies/links K3s kubeconfig to `~/.kube/config`
  - sets `KUBECONFIG` (or prints the export command)

---

## Prerequisites

- Ubuntu/Debian-like machine with `sudo`
- The node should have a stable IP reachable by workers (API server port 6443)

---

## Inputs (from `free5gc.env`)

Usually none are strictly required for installing K3s itself.  
(Cluster naming / node labels / NIC settings are handled later in Step 02/03.)

---

## Outputs

- A running K3s control-plane on this machine
- Working kubectl access for the current user
- Worker join info (token + join command)

---

## How to run

From `installation/`:

```bash
bash scripts/01_install_k3s.sh
