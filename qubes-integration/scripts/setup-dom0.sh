#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-dom0.sh — Configure dom0 for OpenClaw (server + admin VMs)
# Uses qubes.ConnectTCP for safe cross-VM access (Xen vchan, not network)
# Run in dom0 ONLY
# ---------------------------------------------------------------------------

SERVER_VM="${1:-visyble}"
ADMIN_VM="${2:-openclaw-admin}"
ADMIN_TEMPLATE="${3:-fedora-42-xfce}"
NETVM="${4:-sys-firewall}"

echo "=== Qubes dom0 setup for OpenClaw ==="
echo "Server VM:     $SERVER_VM"
echo "Admin VM:      $ADMIN_VM"
echo "Admin template: $ADMIN_TEMPLATE"
echo "NetVM:         $NETVM"
echo ""

# 1. Ensure server VM exists
if qvm-check "$SERVER_VM" &>/dev/null; then
    echo "[1/7] Server VM $SERVER_VM exists"
else
    echo "[1/7] ERROR: Server VM $SERVER_VM does not exist. Create it first."
    exit 1
fi

# 2. Create admin VM if needed
if ! qvm-check "$ADMIN_VM" &>/dev/null; then
    echo "[2/7] Creating admin VM: $ADMIN_VM"
    qvm-create "$ADMIN_VM" --class AppVM --template "$ADMIN_TEMPLATE" --label blue
    qvm-prefs "$ADMIN_VM" netvm "$NETVM"
else
    echo "[2/7] Admin VM $ADMIN_VM already exists"
fi

# 3. Set autostart on both VMs
echo "[3/7] Enabling autostart"
qvm-prefs "$SERVER_VM" autostart True
qvm-prefs "$ADMIN_VM" autostart True

# 4. Tag VMs, set features, and register Qubes services
echo "[4/8] Setting tags, features, and Qubes services"
qvm-tags "$SERVER_VM" add openclaw-server ai-services 2>/dev/null || true
qvm-tags "$ADMIN_VM" add openclaw-admin ai-services 2>/dev/null || true
qvm-features "$SERVER_VM" openclaw-role server 2>/dev/null || true
qvm-features "$SERVER_VM" openclaw-proxy-port 32125 2>/dev/null || true
qvm-features "$SERVER_VM" openclaw-gateway-port 18789 2>/dev/null || true
qvm-features "$SERVER_VM" description "OpenClaw AI server: proxy(:32125) + gateway(:18789)" 2>/dev/null || true
qvm-features "$ADMIN_VM" openclaw-role admin 2>/dev/null || true
qvm-features "$ADMIN_VM" openclaw-server-vm "$SERVER_VM" 2>/dev/null || true
qvm-features "$ADMIN_VM" description "OpenClaw admin panel (connects to $SERVER_VM via ConnectTCP)" 2>/dev/null || true

# Register supported services so they appear in Qubes Manager
qvm-features "$SERVER_VM" supported-service.openclaw-proxy 1 2>/dev/null || true
qvm-features "$SERVER_VM" supported-service.openclaw-gateway 1 2>/dev/null || true
qvm-features "$SERVER_VM" supported-service.openclaw-watchdog 1 2>/dev/null || true
qvm-features "$ADMIN_VM" supported-service.openclaw-tunnels 1 2>/dev/null || true

# Enable services (creates /var/run/qubes-service/ flags at VM boot)
qvm-service "$SERVER_VM" openclaw-proxy on
qvm-service "$SERVER_VM" openclaw-gateway on
qvm-service "$SERVER_VM" openclaw-watchdog on
qvm-service "$ADMIN_VM" openclaw-tunnels on
echo "Services registered and enabled"

# 5. Write hardened ConnectTCP policy
POLICY_DIR="/etc/qubes/policy.d"
POLICY_FILE="$POLICY_DIR/50-openclaw.policy"

echo "[5/8] Writing ConnectTCP policy to $POLICY_FILE"
cat > "$POLICY_FILE" <<EOF
## OpenClaw ConnectTCP policy
## Server VM: $SERVER_VM (proxy :32125, gateway :18789)
## Admin VM: $ADMIN_VM
##
## Only $ADMIN_VM can reach the server ports via qrexec.
## All other VMs are denied. Traffic uses Xen vchan, not the network.

# Admin panel access to proxy API
qubes.ConnectTCP +32125 $ADMIN_VM $SERVER_VM allow

# Admin panel access to gateway dashboard + WebSocket
qubes.ConnectTCP +18789 $ADMIN_VM $SERVER_VM allow

# Deny everything else to server
qubes.ConnectTCP +32125 @anyvm $SERVER_VM deny
qubes.ConnectTCP +18789 @anyvm $SERVER_VM deny
EOF

# 6. Lock down admin VM firewall (only needs qrexec, not internet)
echo "[6/8] Hardening admin VM firewall (qrexec-only)"
qvm-firewall "$ADMIN_VM" del --rule-no 0 2>/dev/null || true
qvm-firewall "$ADMIN_VM" add action=accept specialtarget=dns 2>/dev/null || true
qvm-firewall "$ADMIN_VM" add action=drop 2>/dev/null || true

# 7. Verify
echo "[7/8] Verifying..."
echo ""
echo "Policy:"
cat "$POLICY_FILE"
echo ""
echo "Admin firewall:"
qvm-firewall "$ADMIN_VM" list
echo ""
echo "Services:"
echo "  $SERVER_VM:"
qvm-service "$SERVER_VM" -l
echo "  $ADMIN_VM:"
qvm-service "$ADMIN_VM" -l

# 8. Summary
echo ""
echo "[8/8] Setup complete"
echo ""
echo "Next: Start the VM and run the VM setup script:"
echo "  qvm-start $VM_NAME"
echo "  qvm-run -p $VM_NAME 'curl -fsSL https://raw.githubusercontent.com/GabrieleRisso/qubes-claw/main/qubes-integration/scripts/setup-vm.sh | bash'"
echo ""
echo "The services are registered and will start automatically at VM boot."
echo "Toggle from dom0 at any time:"
echo "  qvm-service $SERVER_VM openclaw-proxy on|off"
echo "  qvm-service $SERVER_VM openclaw-gateway on|off"
echo "  qvm-service $SERVER_VM openclaw-watchdog on|off"
echo "  qvm-service $ADMIN_VM openclaw-tunnels on|off"
echo ""
echo "View status from inside any VM:"
echo "  openclaw-ctl status"
echo "  openclaw-ctl logs [proxy|gateway|watchdog|tunnels]"
echo "  openclaw-ctl follow gateway"
