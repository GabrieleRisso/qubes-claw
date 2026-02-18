#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SKILLS=(
    "self-improving-agent"
    "capability-evolver"
    "wacli"
    "byterover"
)

if ! command -v clawhub &>/dev/null; then
    echo -e "${CYAN}Installing clawhub CLI...${NC}"
    npm i -g clawhub 2>&1 || {
        echo -e "${RED}Failed to install clawhub. Install manually: npm i -g clawhub${NC}"
        exit 1
    }
fi

echo -e "${BOLD}Installing curated ClawHub skills${NC}"
echo -e "${CYAN}Source: VoltAgent/awesome-openclaw-skills (16k stars)${NC}"
echo ""

if [ $# -gt 0 ]; then
    SKILLS=("$@")
fi

ok=0
fail=0
for skill in "${SKILLS[@]}"; do
    echo -e "  ${CYAN}→${NC} $skill"
    if clawhub install "$skill" 2>&1; then
        echo -e "  ${GREEN}✓${NC} $skill installed"
        ok=$((ok+1))
    else
        echo -e "  ${RED}✗${NC} $skill failed (skipping)"
        fail=$((fail+1))
    fi
    echo ""
done

echo -e "${BOLD}Done:${NC} $ok installed, $fail skipped"
echo ""
echo "Manage skills:"
echo "  clawhub search \"query\"     # find skills"
echo "  clawhub install <slug>     # install a skill"
echo "  clawhub update --all       # update all"
echo "  clawhub list               # list installed"
