#!/bin/bash
# openclaw-watchdog.sh — Health watchdog for OpenClaw services on the server VM
# Monitors proxy and gateway, restarts via systemd if either becomes unhealthy.
# Runs as a background service with configurable intervals and thresholds.

PROXY_URL="http://127.0.0.1:32125/health"
GATEWAY_URL="http://127.0.0.1:18789/"
CHECK_INTERVAL="${OPENCLAW_WATCHDOG_INTERVAL:-30}"
FAIL_THRESHOLD="${OPENCLAW_WATCHDOG_THRESHOLD:-3}"
LOG_FILE="/tmp/openclaw-watchdog.log"

proxy_fails=0
gateway_fails=0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

check_proxy() {
    local resp
    resp=$(curl -sf --connect-timeout 5 --max-time 10 "$PROXY_URL" 2>/dev/null)
    if echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['status']=='healthy'" 2>/dev/null; then
        proxy_fails=0
        return 0
    fi
    proxy_fails=$((proxy_fails + 1))
    log "WARN proxy check failed ($proxy_fails/$FAIL_THRESHOLD)"
    return 1
}

check_gateway() {
    local code
    code=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$GATEWAY_URL" 2>/dev/null)
    if [ "$code" = "200" ]; then
        gateway_fails=0
        return 0
    fi
    gateway_fails=$((gateway_fails + 1))
    log "WARN gateway check failed HTTP=$code ($gateway_fails/$FAIL_THRESHOLD)"
    return 1
}

restart_service() {
    local qubes_unit=$1 user_unit=$2
    if systemctl is-active "$qubes_unit" >/dev/null 2>&1 || \
       [ -f /var/run/qubes-service/"${qubes_unit#qubes-}" ]; then
        log "ACTION restarting $qubes_unit (system)"
        systemctl restart "$qubes_unit"
    elif systemctl --user is-active "$user_unit" >/dev/null 2>&1; then
        log "ACTION restarting $user_unit (user)"
        systemctl --user restart "$user_unit"
    else
        log "WARN no active unit found for $qubes_unit / $user_unit"
    fi
}

restart_proxy() {
    restart_service qubes-openclaw-proxy openclaw-cursor-proxy
    proxy_fails=0
    sleep 5
}

restart_gateway() {
    restart_service qubes-openclaw-gateway openclaw-gateway
    gateway_fails=0
    sleep 8
}

log "watchdog started (interval=${CHECK_INTERVAL}s threshold=${FAIL_THRESHOLD})"

while true; do
    check_proxy
    if [ "$proxy_fails" -ge "$FAIL_THRESHOLD" ]; then
        restart_proxy
    fi

    check_gateway
    if [ "$gateway_fails" -ge "$FAIL_THRESHOLD" ]; then
        restart_gateway
    fi

    sleep "$CHECK_INTERVAL"
done
