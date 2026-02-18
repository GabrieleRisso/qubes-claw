#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

declare -A PLUGINS=(
    [matrix]="@openclaw/matrix"
    [powermem]="powermem"
    [memos]="github:MemTensor/MemOS-Cloud-OpenClaw-Plugin"
    [voice]="@openclaw/voice-call"
    [exoshell]="exoshell"
)

PLUGIN_ORDER=(matrix powermem memos voice exoshell)

install_plugin() {
    local name=$1 pkg=$2
    echo -e "  ${CYAN}Installing${NC} $name ($pkg)..."
    if openclaw plugins install "$pkg" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name installed"
    else
        echo -e "  ${RED}✗${NC} $name failed (skipping)"
    fi
}

if ! command -v openclaw &>/dev/null; then
    echo -e "${RED}openclaw not found in PATH${NC}"
    echo "Install OpenClaw first: npm i -g openclaw"
    exit 1
fi

if [ $# -gt 0 ]; then
    for arg in "$@"; do
        key=$(echo "$arg" | tr '[:upper:]' '[:lower:]')
        if [ -n "${PLUGINS[$key]:-}" ]; then
            install_plugin "$key" "${PLUGINS[$key]}"
        else
            echo -e "${RED}Unknown plugin: $arg${NC}"
            echo "Available: ${!PLUGINS[*]}"
        fi
    done
else
    echo -e "${BOLD}Installing curated OpenClaw plugins${NC}"
    echo ""
    for key in "${PLUGIN_ORDER[@]}"; do
        install_plugin "$key" "${PLUGINS[$key]}"
    done
fi

echo ""
echo -e "${BOLD}Installed plugins:${NC}"
openclaw plugins list 2>/dev/null || echo "(could not list)"
echo ""
echo "Configure plugin-specific settings in ~/.openclaw/openclaw.json"
echo "See qubes-integration/plugins/README.md for config examples."
