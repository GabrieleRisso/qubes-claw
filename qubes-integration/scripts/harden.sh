#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}OpenClaw Security Hardening Check${NC}"
echo ""

ok=0
warn=0
fail=0

check() {
    local label=$1 status=$2
    case "$status" in
        ok)   echo -e "  ${GREEN}✓${NC} $label"; ok=$((ok+1)) ;;
        warn) echo -e "  ${YELLOW}!${NC} $label"; warn=$((warn+1)) ;;
        fail) echo -e "  ${RED}✗${NC} $label"; fail=$((fail+1)) ;;
    esac
}

# 1. Config file permissions
CONFIG="$HOME/.openclaw/openclaw.json"
if [ -f "$CONFIG" ]; then
    perms=$(stat -c '%a' "$CONFIG" 2>/dev/null || stat -f '%Lp' "$CONFIG" 2>/dev/null)
    if [ "$perms" = "600" ]; then
        check "Config file permissions ($perms)" ok
    else
        check "Config file permissions ($perms) — should be 600" warn
        echo -e "       Fix: chmod 600 $CONFIG"
    fi
else
    check "Config file not found at $CONFIG" warn
fi

# 2. Gateway bind address
if [ -f "$CONFIG" ]; then
    bind=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('gateway',{}).get('bind',''))" 2>/dev/null || true)
    if [ "$bind" = "loopback" ] || [ "$bind" = "127.0.0.1" ]; then
        check "Gateway bound to loopback" ok
    elif [ "$bind" = "lan" ] || [ "$bind" = "0.0.0.0" ]; then
        if [ -f /usr/share/qubes/marker-vm ]; then
            check "Gateway bound to LAN (OK — Qubes VM, ConnectTCP provides isolation)" ok
        else
            check "Gateway bound to LAN — should be loopback unless behind ConnectTCP/reverse proxy" warn
        fi
    else
        check "Gateway bind: '$bind' (unknown)" warn
    fi
fi

# 3. Auth tokens
if [ -f "$CONFIG" ]; then
    gw_token=$(python3 -c "import json; t=json.load(open('$CONFIG')).get('gateway',{}).get('auth',{}).get('token',''); print('placeholder' if 'CHANGE_ME' in t or 'REPLACE' in t or len(t)<16 else 'ok')" 2>/dev/null || echo "missing")
    if [ "$gw_token" = "ok" ]; then
        check "Gateway auth token set" ok
    else
        check "Gateway auth token not set or placeholder" fail
    fi

    hook_token=$(python3 -c "import json; t=json.load(open('$CONFIG')).get('hooks',{}).get('token',''); print('placeholder' if 'CHANGE_ME' in t or 'REPLACE' in t or len(t)<16 else 'ok')" 2>/dev/null || echo "missing")
    if [ "$hook_token" = "ok" ]; then
        check "Webhook auth token set" ok
    elif [ "$hook_token" = "missing" ]; then
        check "Webhook token not configured (hooks disabled?)" warn
    else
        check "Webhook auth token not set or placeholder" fail
    fi
fi

# 4. Process user
proxy_user=$(ps -eo user,comm 2>/dev/null | grep openclaw-cursor | awk '{print $1}' | head -1)
if [ -n "$proxy_user" ]; then
    if [ "$proxy_user" = "root" ]; then
        check "Proxy running as root — should run as unprivileged user" fail
    else
        check "Proxy running as user: $proxy_user" ok
    fi
fi

gw_user=$(ps -eo user,comm 2>/dev/null | grep "openclaw" | grep -v cursor | awk '{print $1}' | head -1)
if [ -n "$gw_user" ]; then
    if [ "$gw_user" = "root" ]; then
        check "Gateway running as root — should run as unprivileged user" fail
    else
        check "Gateway running as user: $gw_user" ok
    fi
fi

# 5. Qubes isolation (if applicable)
if [ -f /usr/share/qubes/marker-vm ]; then
    vmname=$(qubesdb-read /name 2>/dev/null || echo "?")
    check "Running inside Qubes VM: $vmname" ok

    if ss -tln 2>/dev/null | grep -q ":${PROXY_PORT:-32125} "; then
        check "Proxy listening (server VM)" ok
    fi
fi

# 6. Exposed ports on all interfaces
exposed=$(ss -tln 2>/dev/null | grep "0.0.0.0:" | awk '{print $4}' | sed 's/0.0.0.0://' | tr '\n' ',' | sed 's/,$//')
if [ -n "$exposed" ]; then
    check "Ports on 0.0.0.0: $exposed (review if intentional)" warn
else
    check "No ports bound to 0.0.0.0" ok
fi

echo ""
echo -e "${BOLD}Summary:${NC} ${GREEN}$ok ok${NC}, ${YELLOW}$warn warn${NC}, ${RED}$fail fail${NC}"

if [ "$fail" -gt 0 ]; then
    echo ""
    echo -e "${RED}Action required — fix the failed checks above.${NC}"
    exit 1
fi
