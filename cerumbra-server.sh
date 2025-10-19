#!/usr/bin/env bash
# Cerumbra DGX Spark shielded inference server launcher

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN="${CERUMBRA_PYTHON_BIN:-python3}"
HOST="${CERUMBRA_SERVER_HOST:-0.0.0.0}"
PORT="${CERUMBRA_SERVER_PORT:-8765}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "Error: ${PYTHON_BIN} is not available in PATH." >&2
    echo "Set CERUMBRA_PYTHON_BIN to an alternate interpreter if required." >&2
    exit 1
fi

NVSMI_PRESENT=false
GPU_INFO="Unavailable"
GPU_OK=false
TEE_CONF_STATUS="Unknown"
TEE_CONF_OK=false

if command -v nvidia-smi >/dev/null 2>&1; then
    NVSMI_PRESENT=true

    if GPU_QUERY=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null); then
        GPU_INFO="$(printf '%s' "$GPU_QUERY" | head -n1 | tr -d $'\r')"
        GPU_INFO="$(echo "$GPU_INFO" | sed 's/^ *//;s/ *$//')"
        if printf '%s' "$GPU_INFO" | grep -qiE 'Blackwell|GB[0-9]{2,3}'; then
            GPU_OK=true
        fi
    else
        GPU_INFO="Unknown (nvidia-smi query failed)"
    fi

    if CONF_QUERY=$(nvidia-smi --query-gpu=conf_computing_mode --format=csv,noheader 2>/dev/null); then
        CONF_QUERY="$(printf '%s' "$CONF_QUERY" | head -n1 | tr -d $'\r')"
        CONF_QUERY="$(echo "$CONF_QUERY" | sed 's/^ *//;s/ *$//')"
        if [ -n "$CONF_QUERY" ]; then
            TEE_CONF_STATUS="$CONF_QUERY"
            if printf '%s' "$CONF_QUERY" | grep -qiE 'Enabled|On|Secure'; then
                TEE_CONF_OK=true
            fi
        fi
    fi

    if [ "$TEE_CONF_OK" = false ]; then
        if CONF_ALT=$(nvidia-smi -q 2>/dev/null | awk -F: '/Confidential Compute Mode/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'); then
            CONF_ALT="$(printf '%s' "$CONF_ALT" | tr -d $'\r')"
            CONF_ALT="$(echo "$CONF_ALT" | sed 's/^ *//;s/ *$//')"
            if [ -n "$CONF_ALT" ]; then
                TEE_CONF_STATUS="$CONF_ALT"
                if printf '%s' "$CONF_ALT" | grep -qiE 'Enabled|On|Secure'; then
                    TEE_CONF_OK=true
                fi
            fi
        fi
    fi
else
    GPU_INFO="Unavailable (nvidia-smi not found)"
fi

MODE="production"
if [ "$GPU_OK" != "true" ] || [ "$TEE_CONF_OK" != "true" ]; then
    MODE="test"
fi

if [ "${CERUMBRA_FORCE_PRODUCTION:-0}" = "1" ]; then
    MODE="production"
fi

echo "[Cerumbra] Environment preflight"
echo "--------------------------------"
echo "Deployment mode        : ${MODE}"
echo "GPU model              : ${GPU_INFO}"
if [ "$NVSMI_PRESENT" = true ]; then
    if [ "$GPU_OK" = "true" ]; then
        echo "Blackwell GPU          : detected"
    else
        echo "Blackwell GPU          : NOT detected"
    fi
    echo "Confidential compute   : ${TEE_CONF_STATUS}"
    if [ "$TEE_CONF_OK" = "true" ]; then
        echo "Confidential compute OK: yes"
    else
        echo "Confidential compute OK: no"
    fi
else
    echo "nvidia-smi             : not found (unable to verify GPU/TEE state)"
fi
echo ""

if [ "$MODE" != "production" ]; then
    cat <<'EOF'
================================================================
WARNING: Cerumbra server is running in TEST MODE.
Hardware-backed attestation and memory encryption are not active.
To enable secure mode on DGX Spark:
  1. Deploy on a DGX Spark system with an NVIDIA Blackwell GPU.
  2. Enable confidential computing (sudo nvidia-ccadm --mode SECURE) and reboot.
  3. Re-run cerumbra-server.sh once `nvidia-smi -q` reports
     "Confidential Compute Mode : Enabled".
================================================================
EOF
    if [ "$NVSMI_PRESENT" = false ]; then
        echo "Install the NVIDIA drivers so that nvidia-smi can report GPU state."
    elif [ "$GPU_OK" != "true" ]; then
        echo "Detected GPU '${GPU_INFO}'. Shielded inference requires a Blackwell GPU."
    fi
    if [ "$TEE_CONF_OK" != "true" ]; then
        echo "Confidential computing mode is not enabled; run sudo nvidia-ccadm --mode SECURE and reboot."
    fi
    echo ""
fi

export CERUMBRA_DEPLOYMENT_MODE="$MODE"
export CERUMBRA_GPU_MODEL="$GPU_INFO"
export CERUMBRA_TEE_CONF_MODE="$TEE_CONF_STATUS"

echo "[Cerumbra] DGX Spark Shielded Inference Server"
echo "Preparing Python environment..."
"$PYTHON_BIN" -m pip install --disable-pip-version-check --quiet -r requirements.txt

echo ""
echo "Running Cerumbra verification..."
if ! "$PYTHON_BIN" verify.py; then
    echo ""
    echo "Verification failed. Please address the issues above and retry."
    exit 1
fi

echo ""
echo "Starting server with:"
echo "  Host : ${HOST}"
echo "  Port : ${PORT}"
echo "  Code : ${SCRIPT_DIR}/server.py"
echo "  Mode : ${MODE}"
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

exec "$PYTHON_BIN" server.py --host "$HOST" --port "$PORT"
