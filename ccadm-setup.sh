#!/usr/bin/env bash
# Cerumbra helper to enable NVIDIA confidential computing mode on DGX Spark

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

echo "[Cerumbra] Checking confidential compute status..."
if ! command -v nvidia-ccadm >/dev/null 2>&1; then
    echo "[Cerumbra] nvidia-ccadm not found. Attempting installation..."
    if command -v apt-get >/dev/null 2>&1; then
        echo "[Cerumbra] Updating apt package listings..."
        apt-get update
        echo "[Cerumbra] Installing nvidia-ccadm package..."
        if ! apt-get install -y nvidia-ccadm; then
            echo "Error: Failed to install nvidia-ccadm via apt-get. Install the NVIDIA confidential computing utilities manually." >&2
            exit 1
        fi
    else
        echo "Error: apt-get not available. Install the NVIDIA confidential computing utilities manually (nvidia-ccadm)." >&2
        exit 1
    fi
fi

nvidia-ccadm --status || true

echo "[Cerumbra] Enabling SECURE mode via nvidia-ccadm..."
nvidia-ccadm --mode SECURE

echo "[Cerumbra] Confidential compute requested. Please reboot the system to finalize."
