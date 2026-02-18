#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-dom0.sh — Configure dom0 for OpenClaw server VM
#
# Supports two modes:
#   A) Network server (qubes-network-server) — VM reachable from LAN + other VMs
#   B) Airgapped tunnels (qrexec + socat) — VM only reachable from dom0
#
# Run in dom0 ONLY.
# ---------------------------------------------------------------------------

VM_NAME="${1:-openclaw-vm}"
TEMPLATE="${2:-fedora-41}"
NETVM="${3:-sys-net}"
IP="${4:-10.137.0.100}"
MODE="${5:-tunnel}"  # "tunnel" (airgapped) or "network" (LAN-reachable)

PROXY_PORT=32125
GATEWAY_PORT=18789
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INTEGRATION_DIR="$REPO_DIR/qubes-integration"

echo "=== Qubes dom0 setup for OpenClaw ==="
echo "VM:       $VM_NAME"
echo "Template: $TEMPLATE"
echo "NetVM:    $NETVM"
echo "IP:       $IP"
echo "Mode:     $MODE"
echo ""

# --- 1. Create VM ---
if ! qvm-check "$VM_NAME" &>/dev/null; then
    echo "[1/7] Creating VM: $VM_NAME"
    qvm-create "$VM_NAME" --class StandaloneVM --template "$TEMPLATE" --label orange
    qvm-prefs "$VM_NAME" netvm "$NETVM"
else
    echo "[1/7] VM $VM_NAME already exists"
fi

# --- 2. Set static IP ---
echo "[2/7] Setting IP to $IP"
qvm-prefs "$VM_NAME" ip "$IP"

# --- 3. Tag VM ---
echo "[3/7] Tagging VM as openclaw-server"
qvm-tags "$VM_NAME" add openclaw-server

# --- 4. Enable autostart ---
echo "[4/7] Enabling autostart"
qvm-prefs "$VM_NAME" autostart True

# --- 5. Install qrexec policies ---
echo "[5/7] Installing qrexec policies"
if [ -f "$INTEGRATION_DIR/policies/50-openclaw.policy" ]; then
    sudo cp "$INTEGRATION_DIR/policies/50-openclaw.policy" /etc/qubes/policy.d/
    echo "  Installed 50-openclaw.policy"
fi
if [ -f "$INTEGRATION_DIR/policies/30-openclaw-inter-vm.policy" ]; then
    sudo cp "$INTEGRATION_DIR/policies/30-openclaw-inter-vm.policy" /etc/qubes/policy.d/
    echo "  Installed 30-openclaw-inter-vm.policy"
fi

# --- 6. Mode-specific setup ---
if [ "$MODE" = "network" ]; then
    echo "[6/7] Network mode: enabling routing-method forward"

    if ! rpm -q qubes-core-admin-addon-network-server &>/dev/null; then
        echo "  Installing qubes-core-admin-addon-network-server..."
        sudo qubes-dom0-update qubes-core-admin-addon-network-server
    fi

    qvm-features "$VM_NAME" routing-method forward

    echo "  Adding firewall rules"
    qvm-firewall "$VM_NAME" add --before 0 action=accept dstports=$PROXY_PORT proto=tcp 2>/dev/null || true
    qvm-firewall "$VM_NAME" add --before 0 action=accept dstports=$GATEWAY_PORT proto=tcp 2>/dev/null || true
else
    echo "[6/7] Tunnel mode: setting up airgapped qrexec tunnels"

    # Config file
    sudo mkdir -p /etc/qubes
    cat <<EOF | sudo tee /etc/qubes/openclaw.conf >/dev/null
OPENCLAW_VM=$VM_NAME
EOF

    # TCP forward helper
    sudo install -m 0755 "$INTEGRATION_DIR/dom0/openclaw-tcp-forward" /usr/local/bin/

    # Tunnel service template
    sudo cp "$INTEGRATION_DIR/dom0/openclaw-tunnel@.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable --now "openclaw-tunnel@${PROXY_PORT}.service"
    sudo systemctl enable --now "openclaw-tunnel@${GATEWAY_PORT}.service"
    echo "  Tunnels active: localhost:$PROXY_PORT and localhost:$GATEWAY_PORT"
fi

# --- 7. Summary ---
echo "[7/7] Setup complete"
echo ""
echo "Next: Start the VM and run the VM setup script:"
echo "  qvm-start $VM_NAME"
echo "  qvm-run -p $VM_NAME 'curl -fsSL https://raw.githubusercontent.com/GabrieleRisso/qubes-claw/main/qubes-integration/scripts/setup-vm.sh | bash'"
echo ""
if [ "$MODE" = "tunnel" ]; then
    echo "Access (dom0 only — airgapped):"
    echo "  curl http://127.0.0.1:$PROXY_PORT/health"
    echo "  firefox http://127.0.0.1:$GATEWAY_PORT#token=dom0-local"
else
    echo "Access (from any VM on $NETVM, or LAN):"
    echo "  curl http://$IP:$PROXY_PORT/health"
    echo "  xdg-open http://$IP:$GATEWAY_PORT"
fi
