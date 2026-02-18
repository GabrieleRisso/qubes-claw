#!/bin/bash
# monitor-dashboard.sh — Live status dashboard for OpenClaw services
# Opens in a terminal and shows real-time health + logs

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_status() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  OpenClaw + Cursor Proxy — $(date '+%H:%M:%S')               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Proxy health
    HEALTH=$(curl -sf --connect-timeout 2 http://127.0.0.1:32125/health 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null)
        AUTH=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('authenticated','?'))" 2>/dev/null)
        VER=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('proxy_version','?'))" 2>/dev/null)
        echo -e "  Proxy:    ${GREEN}● $STATUS${NC}  auth=$AUTH  ver=$VER"
    else
        echo -e "  Proxy:    ${RED}● offline${NC}"
    fi

    # Gateway
    GW_HTTP=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 2 http://127.0.0.1:18789/ 2>/dev/null)
    if [ "$GW_HTTP" = "200" ]; then
        echo -e "  Gateway:  ${GREEN}● running${NC}  http://0.0.0.0:18789"
    else
        echo -e "  Gateway:  ${RED}● offline${NC}  (HTTP $GW_HTTP)"
    fi

    # Models
    MODELS=$(curl -sf --connect-timeout 2 http://127.0.0.1:32125/v1/models 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null)
    echo -e "  Models:   ${CYAN}${MODELS:-0} available${NC}"

    # Systemd units
    PROXY_STATE=$(systemctl --user is-active openclaw-cursor-proxy.service 2>/dev/null)
    GW_STATE=$(systemctl --user is-active openclaw-gateway.service 2>/dev/null)
    if [ "$PROXY_STATE" = "active" ]; then
        echo -e "  Systemd:  proxy=${GREEN}$PROXY_STATE${NC}  gateway=${GREEN}$GW_STATE${NC}"
    else
        echo -e "  Systemd:  proxy=${YELLOW}$PROXY_STATE${NC}  gateway=${YELLOW}$GW_STATE${NC}  (manual start)"
    fi

    # VM info
    VM_NAME=$(qubesdb-read /name 2>/dev/null || echo "unknown")
    VM_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "?")
    echo ""
    echo -e "  VM:       ${CYAN}$VM_NAME${NC} ($VM_IP)"
    echo -e "  Ports:    32125 (proxy)  18789 (gateway)"
    echo ""
    echo -e "${CYAN}────────────── Recent gateway log ──────────────${NC}"
    tail -15 /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log 2>/dev/null || echo "  (no log yet)"
    echo ""
    echo -e "  Press Ctrl+C to exit.  Refreshing every 5s..."
}

while true; do
    show_status
    sleep 5
done
