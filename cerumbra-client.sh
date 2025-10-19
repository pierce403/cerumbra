#!/usr/bin/env bash
# Cerumbra local client launcher

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN="${CERUMBRA_PYTHON_BIN:-python3}"
BIND_ADDRESS="${CERUMBRA_CLIENT_BIND:-127.0.0.1}"
PORT="${CERUMBRA_CLIENT_PORT:-8080}"
SERVER_URL="${CERUMBRA_SERVER_URL:-}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "Error: ${PYTHON_BIN} is not available in PATH." >&2
    echo "Set CERUMBRA_PYTHON_BIN to an alternate interpreter if required." >&2
    exit 1
fi

echo "[Cerumbra] Local Chat-style Client"
echo "Serving static assets from: ${SCRIPT_DIR}"
echo "Bind address: ${BIND_ADDRESS}"
echo "HTTP port:    ${PORT}"

CLIENT_URL="http://${BIND_ADDRESS}:${PORT}/index.html"

if [ -n "$SERVER_URL" ]; then
    echo "DGX Spark WebSocket endpoint: ${SERVER_URL}"
    echo "Open ${CLIENT_URL}?server=${SERVER_URL} in your browser."
else
    echo "No CERUMBRA_SERVER_URL provided; defaulting to ws://localhost:8765."
    echo "Open ${CLIENT_URL} (optional: append ?server=ws://host:port)."
fi

echo ""
echo "Press Ctrl+C to stop the client web server."
echo ""

exec "$PYTHON_BIN" -m http.server "$PORT" --bind "$BIND_ADDRESS"
