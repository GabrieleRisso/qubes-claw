#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-dom0.sh — Configure dom0 for OpenClaw server VM
# Uses qubes.ConnectTCP for safe cross-VM access (no qubes-network-server)
# Run in dom0 ONLY
# ---------------------------------------------------------------------------

VM_NAME="${1:-openclaw-vm}"
TEMPLATE="${2:-fedora-41}"
NETVM="${3:-sys-net}"

echo "=== Qubes dom0 setup for OpenClaw ==="
echo "VM:       $VM_NAME"
echo "Template: $TEMPLATE"
echo "NetVM:    $NETVM"
echo ""

# 1. Create VM
if ! qvm-check "$VM_NAME" &>/dev/null; then
    echo "[1/4] Creating VM: $VM_NAME"
    qvm-create "$VM_NAME" --class AppVM --template "$TEMPLATE" --label orange
    qvm-prefs "$VM_NAME" netvm "$NETVM"
else
    echo "[1/4] VM $VM_NAME already exists"
fi

# 2. Allow outbound (VM needs internet to install packages and for cursor-agent)
echo "[2/4] Ensuring outbound connectivity"
qvm-prefs "$VM_NAME" netvm "$NETVM"

# 3. Write qubes.ConnectTCP policy — allow all VMs to reach proxy + gateway
POLICY_DIR="/etc/qubes/policy.d"
POLICY_FILE="$POLICY_DIR/50-openclaw.policy"

echo "[3/4] Writing ConnectTCP policy to $POLICY_FILE"
cat > "$POLICY_FILE" <<EOF
# OpenClaw: allow VMs to connect to proxy (32125) and gateway (18789) on $VM_NAME
qubes.ConnectTCP +32125 @anyvm $VM_NAME allow
qubes.ConnectTCP +18789 @anyvm $VM_NAME allow
EOF

echo "[4/4] Policy written. Verifying..."
cat "$POLICY_FILE"

echo ""
echo "=== Dom0 setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Start the VM:   qvm-start $VM_NAME"
echo "  2. Install inside:  qvm-run -p $VM_NAME 'curl -fsSL https://raw.githubusercontent.com/GabrieleRisso/openclaw-cursor/main/qubes-integration/scripts/setup-vm.sh | bash'"
echo ""
echo "From any client VM:"
echo "  qvm-connect-tcp 32125:$VM_NAME:32125"
echo "  curl http://localhost:32125/health"
