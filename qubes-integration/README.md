# Qubes OS + OpenClaw Integration

Run OpenClaw and the Cursor proxy inside a Qubes VM. A dedicated admin VM connects safely through `qubes.ConnectTCP` (qrexec) -- no raw network routing needed.

## Architecture

### Tunnel mode (default — airgapped)

```
┌──────────────────────────────────────────────────────────────┐
│ dom0                                                         │
│   50-openclaw.policy → only openclaw-admin can connect       │
│   Tags: ai-services on both VMs for Qubes Manager grouping   │
└──────────────────────────────────────────────────────────────┘
        │ qrexec policy: allow openclaw-admin, deny @anyvm
        ▼
┌──────────────────────────────────────────────────────────────┐
│ visyble (StandaloneVM) — server                              │
│                                                              │
│   openclaw-cursor proxy  (:32125)  ← OpenAI-compatible API  │
│   openclaw gateway       (:18789)  ← Dashboard + WebSocket  │
│   cursor-agent           (spawned per request)               │
│                                                              │
│   Firewall: outbound-only (internet for cursor-agent)        │
└──────────────────────────────────────────────────────────────┘
        ▲ qubes.ConnectTCP tunnel (Xen vchan, not network)
        │
┌──────────────────────────────────────────────────────────────┐
│ openclaw-admin (AppVM, fedora-42-xfce) — admin panel         │
│                                                              │
│   localhost:32125 → tunnelled to visyble:32125               │
│   localhost:18789 → tunnelled to visyble:18789               │
│                                                              │
│   Firewall: DNS-only + drop-all (no internet, qrexec-only)  │
│   Autostart: tunnels connect on login                        │
│   Desktop: dashboard + status shortcuts                      │
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Qubes OS 4.2+
- Node 22+, Go 1.22+ in the server VM (or Docker)

## Setup

### 1. Dom0: create admin VM, set policy, harden firewalls

```bash
bash setup-dom0.sh visyble openclaw-admin fedora-42-xfce sys-firewall
```

This:
- Creates `openclaw-admin` if needed
- Enables autostart on both VMs
- Tags both VMs with `ai-services` for Qubes Manager
- Writes a hardened `qubes.ConnectTCP` policy (admin-only, deny all others)
- Locks `openclaw-admin` firewall to DNS-only (qrexec doesn't need internet)

### Step 2: VM

```bash
# Inside visyble
bash setup-vm.sh
```

### 3. Server VM: authenticate and start

```bash
# Cursor only: authenticate
openclaw-cursor login
systemctl --user enable --now openclaw-cursor-proxy openclaw-gateway
```

### 4. Admin VM: connect

```bash
# Tunnels auto-start via autostart desktop entry, or run manually:
bash client-connect.sh visyble
```

Then open the dashboard:

```bash
xdg-open http://localhost:18789/#token=<your-token>
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

## ConnectTCP policy (dom0)

```
# /etc/qubes/policy.d/50-openclaw.policy

# Only openclaw-admin can reach server ports via qrexec
qubes.ConnectTCP +32125 openclaw-admin visyble allow
qubes.ConnectTCP +18789 openclaw-admin visyble allow

# Deny all other VMs
qubes.ConnectTCP +32125 @anyvm visyble deny
qubes.ConnectTCP +18789 @anyvm visyble deny
```

## Qubes-managed services

Services are controlled from dom0 using `qvm-service` and start automatically at boot when enabled.

| Service | VM | Description |
|---------|-----|-------------|
| `openclaw-proxy` | visyble | Cursor proxy (`:32125`) |
| `openclaw-gateway` | visyble | Web dashboard + WebSocket (`:18789`) |
| `openclaw-watchdog` | visyble | Health monitor, auto-restarts failed services |
| `openclaw-tunnels` | openclaw-admin | ConnectTCP tunnels to visyble |

Enable from dom0:

```bash
qvm-service visyble openclaw-proxy on
qvm-service visyble openclaw-gateway on
qvm-service visyble openclaw-watchdog on
qvm-service openclaw-admin openclaw-tunnels on
```

## CLI: openclaw-ctl

Available on both server and admin VMs after install.

```bash
openclaw-ctl status          # Service health, ports, models, VM info
openclaw-ctl health          # Deep health check of all endpoints
openclaw-ctl logs [component]  # Recent logs (proxy|gateway|watchdog|tunnels|all)
openclaw-ctl follow [component]  # Tail logs in real time
openclaw-ctl restart [component] # Restart a service
openclaw-ctl cron [list|add|remove]  # Manage scheduled tasks
openclaw-ctl webhook-test    # Test webhook endpoint
```

## Features (openclaw.json)

Copy the template to get started:

```bash
cp qubes-integration/config/openclaw.json.template ~/.openclaw/openclaw.json
# Edit tokens: replace CHANGE_ME values with output of `openssl rand -hex 32`
```

| Feature | Config key | Description |
|---------|-----------|-------------|
| Heartbeat | `agents.defaults.heartbeat` | Periodic agent wake (default 30m) |
| Webhooks | `hooks` | HTTP triggers at `/hooks/wake` and `/hooks/agent` |
| Cron | `cron` | Built-in scheduler for recurring agent tasks |
| Memory | `memory` | Persistent semantic memory across sessions |
| Browser | `browser` | Agent browser automation via Chrome |
| Logging | `logging` | Structured pretty-printed logs |

## Security defaults

| Setting | visyble (server) | openclaw-admin |
|---------|-----------------|----------------|
| Firewall | Outbound-only (internet) | DNS-only + drop-all |
| Network access | Via sys-firewall | Via sys-firewall (blocked) |
| ConnectTCP | Target (receives) | Source (initiates) |
| Qubes tags | `openclaw-server`, `ai-services` | `openclaw-admin`, `ai-services` |
| Autostart | Yes | Yes |
| Gateway auth | Token-based | Token in URL fragment |

- Traffic between VMs goes through qrexec (Xen vchan), not the network
- Dom0 policy whitelists only `openclaw-admin` -- all other VMs denied
- The proxy uses your Cursor auth -- only the admin VM can reach it
- Gateway uses token auth: set `gateway.auth.token` in `~/.openclaw/openclaw.json`
- No `qubes-network-server` needed (no LAN exposure)

## Links

- [openclaw-cursor proxy](https://github.com/GabrieleRisso/openclaw-cursor)
- [OpenClaw docs](https://docs.openclaw.ai/)
- [qubes.ConnectTCP docs](https://www.qubes-os.org/doc/qrexec/)
