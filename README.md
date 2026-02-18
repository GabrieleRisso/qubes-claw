# qubes-claw

Run [OpenClaw](https://openclaw.ai) AI agents on [Qubes OS](https://www.qubes-os.org/) with VM isolation, airgapped admin, and multi-provider support.

## What is this?

qubes-claw connects OpenClaw's multi-agent AI framework to Qubes OS's security model. Your AI agents run in an isolated VM while you administer them from dom0 — the most privileged, airgapped domain — through secure qrexec tunnels. No network exposure required.

**Works with any provider:** Cursor Pro, OpenAI, Anthropic, Ollama (local), or all of them at once.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ dom0 (airgapped)                                                │
│                                                                 │
│   localhost:9876  → admin web UI (qubes-global-admin-web)       │
│   localhost:32125 → OpenClaw proxy API  ─┐                      │
│   localhost:18789 → OpenClaw dashboard ──┤ socat + qrexec       │
│                                          │ tunnels              │
└──────────────────────────────────────────┤──────────────────────┘
                                           │
┌──────────────────────────────────────────┤──────────────────────┐
│ openclaw-vm (StandaloneVM)               │                      │
│                                          ▼                      │
│   qubes.ConnectTCP handler (socat → localhost)                  │
│                                                                 │
│   openclaw-cursor proxy  (:32125)  ← OpenAI-compatible API     │
│   openclaw gateway       (:18789)  ← Dashboard + WebSocket     │
│                                                                 │
│   Providers: Cursor / OpenAI / Anthropic / Ollama / custom      │
│   Optional: Tailscale, WhatsApp, Docker                         │
└─────────────────────────────────────────────────────────────────┘
```

Two networking modes:

| Mode | Security | Access | Use case |
|------|----------|--------|----------|
| **Tunnel** (default) | Airgapped — dom0 only | `localhost:32125`, `localhost:18789` | Personal workstation |
| **Network** | LAN-reachable | `10.137.0.100:32125` from any VM/LAN host | Shared team server |

## Quick start

### 1. Dom0 setup

```bash
# Clone (or copy) to dom0
git clone https://github.com/GabrieleRisso/qubes-claw.git
cd qubes-claw

# Airgapped tunnel mode (recommended)
bash qubes-integration/scripts/setup-dom0.sh my-openclaw-vm fedora-41 sys-net 10.137.0.100 tunnel

# Or: LAN-reachable mode
bash qubes-integration/scripts/setup-dom0.sh my-openclaw-vm fedora-41 sys-net 10.137.0.100 network
```

### 2. VM setup

```bash
# Start the VM
qvm-start my-openclaw-vm

# Option A: Cursor Pro (needs subscription)
qvm-run -p my-openclaw-vm 'bash /path/to/qubes-claw/qubes-integration/scripts/setup-vm.sh cursor'

# Option B: OpenAI API
qvm-run -p my-openclaw-vm 'bash /path/to/qubes-claw/qubes-integration/scripts/setup-vm.sh openai'

# Option C: Anthropic API
qvm-run -p my-openclaw-vm 'bash /path/to/qubes-claw/qubes-integration/scripts/setup-vm.sh anthropic'

# Option D: Ollama (local models, free)
qvm-run -p my-openclaw-vm 'bash /path/to/qubes-claw/qubes-integration/scripts/setup-vm.sh ollama'
```

### 3. Start services

Inside the VM:

```bash
# Cursor provider: log in first
openclaw-cursor login
systemctl --user start openclaw-cursor-proxy openclaw-gateway

# Other providers: just start the gateway
systemctl --user start openclaw-gateway
```

### 4. Access

From dom0 (tunnel mode):

```bash
# API health check
curl http://127.0.0.1:32125/health

# Open dashboard (token authenticates the WebSocket)
firefox http://127.0.0.1:18789#token=dom0-local

# Chat completion
curl http://127.0.0.1:32125/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hello"}]}'
```

## Provider configs

Example configs are in `qubes-integration/examples/`. Copy one to the VM:

| File | Provider | Auth needed |
|------|----------|-------------|
| `openclaw-cursor.json` | Cursor Pro (via proxy) | Cursor login |
| `openclaw-openai.json` | OpenAI API | `OPENAI_API_KEY` |
| `openclaw-anthropic.json` | Anthropic API | `ANTHROPIC_API_KEY` |
| `openclaw-ollama.json` | Ollama (local) | None |
| `openclaw-multi-provider.json` | All of the above | Mixed |

To switch providers after install, edit `~/.openclaw/openclaw.json` on the VM or copy an example:

```bash
cp qubes-integration/examples/openclaw-openai.json ~/.openclaw/openclaw.json
# Edit to add your API key, then restart:
systemctl --user restart openclaw-gateway
```

## Repo layout

```
qubes-claw/
├── qubes-integration/
│   ├── scripts/
│   │   ├── setup-dom0.sh        # Dom0 installer (tunnel or network mode)
│   │   └── setup-vm.sh          # VM installer (provider-aware)
│   ├── systemd/
│   │   ├── openclaw-cursor-proxy.service  # User service: Cursor proxy
│   │   └── openclaw-gateway.service       # User service: gateway + dashboard
│   ├── dom0/
│   │   ├── openclaw-tunnel@.service  # Systemd template: socat→qrexec tunnel
│   │   ├── openclaw-tcp-forward      # Helper: qrexec-client wrapper
│   │   └── openclaw.conf             # Config: which VM to tunnel to
│   ├── vm/
│   │   └── qubes.ConnectTCP          # Qrexec handler: TCP forwarding
│   ├── policies/
│   │   ├── 50-openclaw.policy        # ConnectTCP port access
│   │   └── 30-openclaw-inter-vm.policy  # Optional: inter-VM shell/exec
│   ├── examples/                     # Provider config templates
│   └── README.md                     # Detailed integration docs
├── openclaw/                         # openclaw-cursor proxy (submodule)
├── .cursor/rules/                    # Cursor AI workspace rules
└── README.md                         # This file
```

## Adding client VMs

Tag any VM as an OpenClaw client to give it API access:

```bash
# In dom0
qvm-tags my-other-vm add openclaw-client

# From that VM, access the proxy
curl http://10.137.0.100:32125/health  # network mode
# or through qrexec ConnectTCP         # tunnel mode
```

## Survives reboot

Everything auto-starts:

| Component | Where | Mechanism |
|-----------|-------|-----------|
| OpenClaw VM | dom0 | `qvm-prefs autostart True` |
| Cursor proxy | VM | systemd user service + linger |
| Gateway | VM | systemd user service + linger |
| qrexec tunnels | dom0 | systemd system services |
| ConnectTCP handler | VM | `/etc/qubes-rpc/` (persistent on StandaloneVM) |
| Policies | dom0 | `/etc/qubes/policy.d/` |

## Security

- **Isolation**: AI agents run in a separate VM — cannot access dom0 or other VMs unless explicitly allowed by qrexec policy.
- **Airgapped admin**: In tunnel mode, dom0 never touches the network. Tunnels use qrexec (Xen shared memory), not TCP/IP.
- **Token auth**: The gateway dashboard requires a token. Default is `dom0-local` for localhost-only access. Change it in `~/.openclaw/openclaw.json`.
- **Firewall**: Network mode uses Qubes firewall rules. Only allowed ports are open.
- **No secrets in git**: API keys live in `~/.openclaw/openclaw.json` inside the VM. Example configs use `${PLACEHOLDER}` syntax.

## Non-Qubes (Docker)

```bash
cd openclaw
docker compose up -d
```

## Links

- [OpenClaw docs](https://docs.openclaw.ai/)
- [openclaw-cursor proxy](openclaw/)
- [Qubes integration details](qubes-integration/)
- [qubes-network-server](https://github.com/Rudd-O/qubes-network-server)
- [qvm-remote](https://github.com/GabrieleRisso/qvm-remote)
