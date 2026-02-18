#!/bin/bash
# openclaw-wait-ready.sh — Pre-start readiness gate for OpenClaw services
# Used by systemd ExecStartPre to ensure dependencies are healthy before start.
# Usage: openclaw-wait-ready.sh <proxy|gateway>

set -euo pipefail

COMPONENT="${1:-proxy}"
MAX_WAIT=30
INTERVAL=2

wait_for_network() {
    local n=0
    while [ $n -lt $MAX_WAIT ]; do
        if curl -sf --connect-timeout 2 https://www.google.com > /dev/null 2>&1; then
            return 0
        fi
        n=$((n + INTERVAL))
        sleep $INTERVAL
    done
    echo "WARN: network not ready after ${MAX_WAIT}s, proceeding anyway"
    return 0
}

wait_for_proxy() {
    local n=0
    while [ $n -lt $MAX_WAIT ]; do
        if curl -sf --connect-timeout 2 http://127.0.0.1:32125/health > /dev/null 2>&1; then
            return 0
        fi
        n=$((n + INTERVAL))
        sleep $INTERVAL
    done
    echo "WARN: proxy not ready after ${MAX_WAIT}s"
    return 1
}

case "$COMPONENT" in
    proxy)
        echo "Waiting for network..."
        wait_for_network
        echo "Ready to start proxy"
        ;;
    gateway)
        echo "Waiting for proxy to be healthy..."
        wait_for_proxy
        echo "Proxy healthy, starting gateway"
        ;;
    *)
        echo "Unknown component: $COMPONENT"
        exit 1
        ;;
esac
