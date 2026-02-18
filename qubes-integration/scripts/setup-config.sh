#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../config/openclaw.json.template"
TARGET="${1:-$HOME/.openclaw/openclaw.json}"

if [ -f "$TARGET" ]; then
    echo "Config already exists at $TARGET"
    echo "Back up and remove it first, or pass a different path."
    exit 1
fi

mkdir -p "$(dirname "$TARGET")"

GW_TOKEN=$(openssl rand -hex 32)
HOOK_TOKEN=$(openssl rand -hex 32)

sed \
    -e "s/CHANGE_ME_GENERATE_WITH_openssl_rand_hex_32/$GW_TOKEN/" \
    -e "0,/$GW_TOKEN/! s/$GW_TOKEN/$HOOK_TOKEN/" \
    "$TEMPLATE" > "$TARGET"

chmod 600 "$TARGET"

echo "Config written to $TARGET"
echo ""
echo "  Gateway token: ${GW_TOKEN:0:8}..."
echo "  Webhook token: ${HOOK_TOKEN:0:8}..."
echo ""
echo "Open dashboard: xdg-open http://localhost:18789/#token=$GW_TOKEN"
