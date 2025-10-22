#!/usr/bin/env bash
# Cerumbra helper to enable NVIDIA confidential computing mode on DGX Spark

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

echo "[Cerumbra] Checking confidential compute status..."
if command -v nvidia-ccadm >/dev/null 2>&1; then
    nvidia-ccadm --status || true
else
    echo "Error: nvidia-ccadm tool not found. Install the NVIDIA confidential computing utilities." >&2
    exit 1
fi

echo "[Cerumbra] Enabling SECURE mode via nvidia-ccadm..."
nvidia-ccadm --mode SECURE

echo "[Cerumbra] Confidential compute requested. Please reboot the system to finalize."
