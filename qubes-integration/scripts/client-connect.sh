#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# client-connect.sh — Connect to OpenClaw server VM via qubes.ConnectTCP
# Run inside any client AppVM
#
# Usage: bash client-connect.sh <server-vm-name>
# ---------------------------------------------------------------------------

SERVER_VM="${1:?Usage: $0 <server-vm-name>}"

echo "=== Connecting to OpenClaw on $SERVER_VM ==="
echo ""

if [ ! -f /usr/share/qubes/marker-vm ]; then
    echo "ERROR: Not a Qubes VM."
    exit 1
fi

cleanup() {
    echo ""
    echo "Shutting down tunnels..."
    kill $PID_PROXY $PID_GW 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[1/3] Opening proxy tunnel (localhost:32125 → $SERVER_VM:32125)..."
qvm-connect-tcp 32125:"$SERVER_VM":32125 &
PID_PROXY=$!
sleep 1

echo "[2/3] Opening gateway tunnel (localhost:18789 → $SERVER_VM:18789)..."
qvm-connect-tcp 18789:"$SERVER_VM":18789 &
PID_GW=$!
sleep 1

echo "[3/3] Verifying..."
if curl -sf http://localhost:32125/health > /dev/null 2>&1; then
    echo ""
    echo "Connected. Services available at:"
    echo "  Proxy:     http://localhost:32125/v1/chat/completions"
    echo "  Models:    http://localhost:32125/v1/models"
    echo "  Health:    http://localhost:32125/health"
    echo "  Dashboard: http://localhost:18789/"
    echo ""
    echo "Press Ctrl+C to disconnect."
    wait
else
    echo ""
    echo "WARNING: Could not reach proxy. Check that:"
    echo "  1. $SERVER_VM is running"
    echo "  2. openclaw-cursor proxy is started inside $SERVER_VM"
    echo "  3. Dom0 policy allows ConnectTCP (run setup-dom0.sh)"
    echo ""
    echo "Tunnels are open -- retrying manually:"
    echo "  curl http://localhost:32125/health"
    wait
fi
