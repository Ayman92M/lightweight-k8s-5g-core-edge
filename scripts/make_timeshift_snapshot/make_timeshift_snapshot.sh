#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Timeshift Baseline Snapshot Script (SSH-safe)
# Usage:
#   sudo ./make_timeshift_baseline.sh "CLEAN BASELINE"
# ============================================

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root (use sudo)."
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: sudo $0 \"Snapshot description\""
  exit 1
fi

DESC="$1"

echo "=== [1/5] Updating apt ==="
apt update -y

echo "=== [2/5] Installing timeshift if needed ==="
if ! command -v timeshift >/dev/null 2>&1; then
  apt install -y timeshift rsync
else
  echo "Timeshift already installed."
fi

echo "=== [3/5] Detecting root filesystem device ==="
ROOTDEV="$(findmnt -n -o SOURCE /)"
if [[ -z "$ROOTDEV" ]]; then
  echo "ERROR: Could not detect root device."
  exit 1
fi
echo "Root device detected: $ROOTDEV"

echo "=== [4/5] Creating snapshot: \"$DESC\" ==="
timeshift --rsync --snapshot-device "$ROOTDEV" \
  --create --comments "$DESC"

echo "=== [5/5] Listing snapshots (verification) ==="
timeshift --list

echo
echo "✅ Done. Snapshot created successfully."
