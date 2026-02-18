#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-dom0.sh — Configure dom0 for OpenClaw server VM
# Run in dom0 ONLY
# ---------------------------------------------------------------------------

VM_NAME="${1:-openclaw-vm}"
TEMPLATE="${2:-fedora-41}"
NETVM="${3:-sys-net}"
IP="${4:-10.137.0.100}"

echo "=== Qubes dom0 setup for OpenClaw ==="
echo "VM:       $VM_NAME"
echo "Template: $TEMPLATE"
echo "NetVM:    $NETVM"
echo "IP:       $IP"
echo ""

# 1. Install dom0 addon (if not already)
if ! rpm -q qubes-core-admin-addon-network-server &>/dev/null; then
    echo "[1/5] Installing qubes-core-admin-addon-network-server..."
    sudo qubes-dom0-update qubes-core-admin-addon-network-server
else
    echo "[1/5] Dom0 addon already installed"
fi

# 2. Create VM if it doesn't exist
if ! qvm-check "$VM_NAME" &>/dev/null; then
    echo "[2/5] Creating VM: $VM_NAME"
    qvm-create "$VM_NAME" --class AppVM --template "$TEMPLATE" --label orange
    qvm-prefs "$VM_NAME" netvm "$NETVM"
else
    echo "[2/5] VM $VM_NAME already exists"
fi

# 3. Set static IP
echo "[3/5] Setting IP to $IP"
qvm-prefs "$VM_NAME" ip "$IP"

# 4. Enable server networking
echo "[4/5] Enabling routing-method forward"
qvm-features "$VM_NAME" routing-method forward

# 5. Open firewall ports
echo "[5/5] Adding firewall rules for ports 32125 and 18789"
qvm-firewall "$VM_NAME" add --before 0 action=accept dstports=32125 proto=tcp 2>/dev/null || true
qvm-firewall "$VM_NAME" add --before 0 action=accept dstports=18789 proto=tcp 2>/dev/null || true

echo ""
echo "=== Dom0 setup complete ==="
echo ""
echo "Next: Start the VM and run the VM setup script inside it:"
echo "  qvm-start $VM_NAME"
echo "  qvm-run $VM_NAME 'curl -fsSL https://raw.githubusercontent.com/GabrieleRisso/qubes-claw/main/qubes-integration/scripts/setup-vm.sh | bash'"
echo ""
echo "Access from other VMs:"
echo "  curl http://$IP:32125/health"
echo "  xdg-open http://$IP:18789/"
