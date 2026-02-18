#!/bin/bash
set -euo pipefail

SERVER_VM="${1:-visyble}"

echo "=== Testing qubes.ConnectTCP to $SERVER_VM ==="
echo ""

echo "[1/2] Proxy (port 32125)..."
qvm-connect-tcp 32125:"$SERVER_VM":32125 &
PID1=$!
sleep 2

if curl -sf --connect-timeout 5 http://localhost:32125/health > /dev/null 2>&1; then
    echo "  OK: $(curl -sf http://localhost:32125/health)"
else
    echo "  FAIL: proxy not reachable"
fi
kill $PID1 2>/dev/null

echo "[2/2] Gateway (port 18789)..."
qvm-connect-tcp 18789:"$SERVER_VM":18789 &
PID2=$!
sleep 2

HTTP=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:18789/ 2>/dev/null) \
    && echo "  OK: HTTP $HTTP" \
    || echo "  FAIL: gateway not reachable"
kill $PID2 2>/dev/null

echo ""
echo "Done. Both services tested via qrexec (no network routing)."
