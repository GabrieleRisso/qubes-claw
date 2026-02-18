# Qubes OS + OpenClaw + Cursor Proxy Integration

Run OpenClaw and the Cursor proxy inside a Qubes OS VM, with proper networking so other VMs and LAN hosts can reach the gateway and proxy.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ dom0                                                         │
│   qvm-features openclaw-vm routing-method forward            │
└──────────────────────────────────────────────────────────────┘
        │ writes routing-method to NetVM Qubes DB
        ▼
┌──────────────────────────────────────────────────────────────┐
│ sys-net (NetVM)                                              │
│   qubes-routing-manager → nftables forward + proxy ARP       │
└──────────────────────────────────────────────────────────────┘
        │ forwards traffic to/from openclaw-vm
        ▼
┌──────────────────────────────────────────────────────────────┐
│ openclaw-vm (AppVM)                                          │
│                                                              │
│   openclaw-cursor proxy  (:32125)  ← OpenAI-compatible API  │
│   openclaw gateway       (:18789)  ← Dashboard + WebSocket  │
│   cursor-agent           (spawned per request)               │
│                                                              │
│   Reachable from:                                            │
│     - Other Qubes VMs on same NetVM                          │
│     - LAN hosts (via proxy ARP)                              │
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Qubes OS 4.2+
- `qubes-network-server` installed in NetVM template
- `qubes-core-admin-addon-network-server` installed in dom0
- Node 22+, Go 1.22+ in the AppVM (or use Docker)

## Setup

### 1. Install qubes-network-server (one-time)

**In dom0:**

```bash
sudo qubes-dom0-update qubes-core-admin-addon-network-server
```

**In NetVM template (e.g. fedora-41):**

```bash
sudo dnf install qubes-network-server
```

Then restart the NetVM.

### 2. Create the OpenClaw VM

```bash
# In dom0
qvm-create openclaw-vm --class AppVM --template fedora-41 --label orange
qvm-prefs openclaw-vm netvm sys-net
```

### 3. Enable server networking

```bash
# In dom0 — makes the VM reachable from LAN and other VMs
qvm-features openclaw-vm routing-method forward
```

### 4. Set a static IP (optional but recommended)

```bash
# In dom0
qvm-prefs openclaw-vm ip 10.137.0.100
```

### 5. Allow inbound ports in Qubes firewall

```bash
# In dom0
qvm-firewall openclaw-vm add --before 0 action=accept dstports=32125 proto=tcp
qvm-firewall openclaw-vm add --before 0 action=accept dstports=18789 proto=tcp
```

### 6. Install and start (inside openclaw-vm)

#### Option A: From source

```bash
# Run the setup script
curl -fsSL https://raw.githubusercontent.com/GabrieleRisso/qubes-claw/main/qubes-integration/scripts/setup-vm.sh | bash
```

#### Option B: Docker

```bash
git clone https://github.com/GabrieleRisso/openclaw-cursor.git
cd openclaw-cursor
docker compose up -d
```

### 7. Access from other VMs

From any VM on the same NetVM:

```bash
# Health check
curl http://10.137.0.100:32125/health

# Chat completion
curl http://10.137.0.100:32125/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"cursor/auto","messages":[{"role":"user","content":"hello"}]}'

# Dashboard (open in browser)
xdg-open http://10.137.0.100:18789/
```

## Systemd services

Install the systemd units for auto-start:

```bash
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw-cursor-proxy.service
sudo systemctl enable --now openclaw-gateway.service
```

## Security notes

- The proxy uses your Cursor auth — do NOT expose port 32125 beyond your trusted network
- Use `qvm-firewall` to restrict which VMs/IPs can reach the proxy
- OpenClaw gateway supports token auth: set `gateway.auth.token` in `~/.openclaw/openclaw.json`
- For remote access beyond LAN, use Tailscale or SSH tunnels
