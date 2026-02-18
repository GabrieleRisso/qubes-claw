#!/bin/bash
# openclaw-tunnel-daemon.sh — Persistent ConnectTCP tunnel manager for admin VM
# Auto-reconnects if tunnels drop. Runs as a background daemon.

SERVER_VM="${OPENCLAW_SERVER_VM:-visyble}"
PROXY_PORT=32125
GATEWAY_PORT=18789
CHECK_INTERVAL=15
LOG="/tmp/openclaw-tunnels.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

is_port_listening() { ss -tln 2>/dev/null | grep -q ":$1 "; }

ensure_tunnel() {
    local port=$1
    if is_port_listening "$port"; then
        return 0
    fi
    log "tunnel :$port down, reconnecting to $SERVER_VM"
    pkill -f "qvm-connect-tcp ${port}:" 2>/dev/null
    sleep 1
    nohup qvm-connect-tcp "${port}:${SERVER_VM}:${port}" >> "$LOG" 2>&1 &
    sleep 3
    if is_port_listening "$port"; then
        log "tunnel :$port restored"
        return 0
    fi
    log "tunnel :$port FAILED to restore"
    return 1
}

verify_proxy() {
    curl -sf --connect-timeout 5 "http://127.0.0.1:${PROXY_PORT}/health" > /dev/null 2>&1
}

cleanup() {
    log "shutting down tunnels"
    pkill -f "qvm-connect-tcp ${PROXY_PORT}:" 2>/dev/null
    pkill -f "qvm-connect-tcp ${GATEWAY_PORT}:" 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

log "tunnel daemon started (server=$SERVER_VM)"

ensure_tunnel $PROXY_PORT
ensure_tunnel $GATEWAY_PORT

while true; do
    ensure_tunnel $PROXY_PORT
    ensure_tunnel $GATEWAY_PORT

    if verify_proxy; then
        log "health OK"
    else
        log "proxy unreachable through tunnel -- server VM may be down"
    fi

    sleep "$CHECK_INTERVAL"
done
