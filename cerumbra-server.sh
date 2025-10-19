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

echo "[Cerumbra] DGX Spark Shielded Inference Server"
echo "Preparing Python environment..."
"$PYTHON_BIN" -m pip install --disable-pip-version-check --quiet -r requirements.txt

echo ""
echo "Starting server with:"
echo "  Host : ${HOST}"
echo "  Port : ${PORT}"
echo "  Code : ${SCRIPT_DIR}/server.py"
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

exec "$PYTHON_BIN" server.py --host "$HOST" --port "$PORT"
