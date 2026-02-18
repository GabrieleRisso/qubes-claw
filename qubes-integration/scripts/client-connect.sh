#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# client-connect.sh — Connect to OpenClaw server VM via qubes.ConnectTCP
# Run inside the openclaw-admin AppVM
#
# Usage: bash client-connect.sh [server-vm-name]
# ---------------------------------------------------------------------------

SERVER_VM="${1:-visyble}"
PROXY_PORT=32125
GATEWAY_PORT=18789

echo "=== Connecting to OpenClaw on $SERVER_VM ==="

if [ ! -f /usr/share/qubes/marker-vm ]; then
    echo "ERROR: Not a Qubes VM."
    exit 1
fi

cleanup() {
    echo ""
    echo "Shutting down tunnels..."
    kill $(jobs -p) 2>/dev/null || true
}
trap cleanup EXIT INT TERM

is_port_open() { ss -tln 2>/dev/null | grep -q ":$1 "; }

if is_port_open $PROXY_PORT && is_port_open $GATEWAY_PORT; then
    echo "Tunnels already active."
else
    is_port_open $PROXY_PORT  || { qvm-connect-tcp $PROXY_PORT:$SERVER_VM:$PROXY_PORT 2>/dev/null & }
    is_port_open $GATEWAY_PORT || { qvm-connect-tcp $GATEWAY_PORT:$SERVER_VM:$GATEWAY_PORT 2>/dev/null & }
    sleep 3
fi

H=$(curl -sf --connect-timeout 5 http://localhost:$PROXY_PORT/health 2>/dev/null)
if [ -n "$H" ]; then
    TOKEN=$(echo "$H" | python3 -c "import sys; print('ok')" 2>/dev/null)
    echo ""
    echo "Proxy:     OK (port $PROXY_PORT)"
    echo "Gateway:   $(curl -sf --connect-timeout 5 -o /dev/null -w 'HTTP %{http_code}' http://localhost:$GATEWAY_PORT/)"
    echo ""
    echo "Endpoints:"
    echo "  API:       http://localhost:$PROXY_PORT/v1/chat/completions"
    echo "  Models:    http://localhost:$PROXY_PORT/v1/models"
    echo "  Health:    http://localhost:$PROXY_PORT/health"
    echo "  Dashboard: http://localhost:$GATEWAY_PORT/"
    echo ""
    echo "Tunnels running. Ctrl+C to disconnect."
    wait
else
    echo ""
    echo "WARNING: Could not reach proxy. Check that:"
    echo "  1. $SERVER_VM is running"
    echo "  2. openclaw-cursor services are started inside $SERVER_VM"
    echo "  3. Dom0 policy allows ConnectTCP from this VM"
    echo ""
    echo "Tunnels are open -- retrying in 10s..."
    sleep 10
    curl -sf --connect-timeout 5 http://localhost:$PROXY_PORT/health > /dev/null && echo "Proxy: OK (retry)" || echo "Proxy: still down"
    wait
fi
