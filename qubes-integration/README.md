# Qubes OS + OpenClaw Integration

Detailed setup and architecture docs for running OpenClaw inside Qubes OS.

## Architecture

### Tunnel mode (default — airgapped)

```
┌──────────────────────────────────────────────────────────────────┐
│ dom0                                                             │
│                                                                  │
│  openclaw-tunnel@32125.service ──socat──┐                        │
│  openclaw-tunnel@18789.service ──socat──┤                        │
│                                         │                        │
│  /usr/local/bin/openclaw-tcp-forward ◄──┘                        │
│      └──► qrexec-client -d <vm> qubes.ConnectTCP+<port>         │
└──────────────────────────────────────────────────────────────────┘
                        │ qrexec (Xen shared memory)
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│ openclaw-vm                                                      │
│                                                                  │
│  /etc/qubes-rpc/qubes.ConnectTCP                                │
│      └──► socat - TCP:127.0.0.1:$PORT                           │
│                                                                  │
│  openclaw-cursor proxy (:32125) ← systemd user service          │
│  openclaw gateway      (:18789) ← systemd user service          │
└──────────────────────────────────────────────────────────────────┘
```

### Network mode (LAN-reachable)

```
┌───────────────────────────────────────────────┐
│ dom0                                           │
│  qvm-features <vm> routing-method forward      │
└───────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────┐
│ sys-net (NetVM)                                │
│  qubes-routing-manager → nftables + proxy ARP  │
└───────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────┐
│ openclaw-vm (AppVM)                            │
│  :32125  proxy  ← reachable from LAN + VMs    │
│  :18789  gateway                               │
└───────────────────────────────────────────────┘
```

## Prerequisites

- Qubes OS 4.2+
- Node 22+ in the VM (installed by `setup-vm.sh`)
- **Tunnel mode**: `socat` in the VM (installed by `setup-vm.sh`)
- **Network mode**: `qubes-network-server` in NetVM template, `qubes-core-admin-addon-network-server` in dom0

### Provider-specific

| Provider | Extra requirements |
|----------|-------------------|
| Cursor | Go 1.22+, Cursor Pro subscription |
| OpenAI | `OPENAI_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| Ollama | ~8GB RAM for 7B models, ~40GB for 70B |

## Setup

### Step 1: Dom0

```bash
# Tunnel mode (airgapped — recommended for personal use)
bash setup-dom0.sh <vm-name> <template> <netvm> <ip> tunnel

# Network mode (LAN-reachable — for shared servers)
bash setup-dom0.sh <vm-name> <template> <netvm> <ip> network
```

**What it does:**
1. Creates the VM (StandaloneVM, orange label)
2. Sets a static IP
3. Tags it as `openclaw-server`
4. Enables autostart
5. Installs qrexec policies
6. Sets up tunnels (tunnel mode) or routing (network mode)

### Step 2: VM

```bash
# Pick your provider
bash setup-vm.sh cursor     # Cursor Pro
bash setup-vm.sh openai     # OpenAI API
bash setup-vm.sh anthropic  # Anthropic API
bash setup-vm.sh ollama     # Local models
```

**What it does:**
1. Installs `socat` and the ConnectTCP qrexec handler
2. Installs OpenClaw
3. Installs provider-specific tooling (proxy binary, API client, Ollama, etc.)
4. Generates `~/.openclaw/openclaw.json` from the example config
5. Installs and enables systemd user services
6. Enables loginctl linger (services persist without login)

### Step 3: First run

```bash
# Cursor only: authenticate
openclaw-cursor login

# Start everything
systemctl --user start openclaw-cursor-proxy  # cursor only
systemctl --user start openclaw-gateway
```

## Files installed

### Dom0 (tunnel mode)

| File | Purpose |
|------|---------|
| `/etc/systemd/system/openclaw-tunnel@.service` | Systemd template for socat→qrexec tunnels |
| `/usr/local/bin/openclaw-tcp-forward` | qrexec-client wrapper called by socat |
| `/etc/qubes/openclaw.conf` | Config: target VM name |
| `/etc/qubes/policy.d/50-openclaw.policy` | ConnectTCP port access rules |
| `/etc/qubes/policy.d/30-openclaw-inter-vm.policy` | Optional inter-VM shell/exec |

### VM

| File | Purpose |
|------|---------|
| `/etc/qubes-rpc/qubes.ConnectTCP` | Qrexec handler: forwards TCP to localhost |
| `~/.config/systemd/user/openclaw-cursor-proxy.service` | Cursor proxy service |
| `~/.config/systemd/user/openclaw-gateway.service` | Gateway + dashboard service |
| `~/.openclaw/openclaw.json` | OpenClaw config (provider, models, gateway) |
| `~/.openclaw/cursor-proxy.json` | Cursor proxy config (cursor provider only) |

## Adding new client VMs

```bash
# In dom0: tag the VM
qvm-tags my-client-vm add openclaw-client

# The 50-openclaw.policy already allows tagged clients.
# From the client VM:
curl http://10.137.0.100:32125/health  # network mode
```

For tunnel mode access from client VMs, install the ConnectTCP handler in the client too:

```bash
# In the client VM
echo '#!/bin/sh
exec socat - "TCP:127.0.0.1:${QREXEC_SERVICE_ARGUMENT}"' | sudo tee /etc/qubes-rpc/qubes.ConnectTCP
sudo chmod +x /etc/qubes-rpc/qubes.ConnectTCP
```

## Changing providers

Edit `~/.openclaw/openclaw.json` in the VM. Example configs are in `examples/`:

```bash
# Switch to OpenAI
cp examples/openclaw-openai.json ~/.openclaw/openclaw.json
# Edit: replace ${OPENAI_API_KEY} with your key
vim ~/.openclaw/openclaw.json
systemctl --user restart openclaw-gateway
```

## Troubleshooting

### Gateway shows "disconnected"
The dashboard needs a token. Open it with the token in the URL hash:
```
http://127.0.0.1:18789#token=dom0-local
```

### Tunnel not working
```bash
# In dom0: check tunnel services
systemctl status openclaw-tunnel@32125
systemctl status openclaw-tunnel@18789

# In VM: check ConnectTCP handler exists
cat /etc/qubes-rpc/qubes.ConnectTCP

# In VM: check services
systemctl --user status openclaw-gateway
systemctl --user status openclaw-cursor-proxy  # cursor only
```

### Services don't start after reboot
```bash
# In VM: ensure linger is enabled
loginctl enable-linger $(whoami)

# In dom0: ensure autostart
qvm-prefs <vm-name> autostart True
```

## Security

- **VM isolation**: AI agents can't escape the VM. Qrexec policies control all cross-VM communication.
- **Port restrictions**: Only ports 32125 and 18789 are allowed through ConnectTCP.
- **Tag-based access**: Only VMs tagged `openclaw-client` can reach the server.
- **No network in dom0**: Tunnel mode uses Xen shared memory (qrexec), not TCP/IP networking.
- **API keys stay in VM**: Never stored in dom0 or git. Example configs use placeholder syntax.
