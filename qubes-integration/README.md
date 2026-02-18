# Qubes OS + OpenClaw + Cursor Proxy

Run OpenClaw and the Cursor proxy inside a Qubes VM. Other VMs connect safely through `qubes.ConnectTCP` (qrexec) -- no raw network routing needed.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ dom0                                                         │
│   Adds qubes.ConnectTCP policy for openclaw-vm               │
└──────────────────────────────────────────────────────────────┘
        │ qrexec policy controls which VMs can connect
        ▼
┌──────────────────────────────────────────────────────────────┐
│ openclaw-vm (AppVM) — server                                 │
│                                                              │
│   openclaw-cursor proxy  (:32125)  ← OpenAI-compatible API  │
│   openclaw gateway       (:18789)  ← Dashboard + WebSocket  │
│   cursor-agent           (spawned per request)               │
└──────────────────────────────────────────────────────────────┘
        ▲ qubes.ConnectTCP tunnel (secure qrexec)
        │
┌──────────────────────────────────────────────────────────────┐
│ client-vm (any AppVM)                                        │
│                                                              │
│   localhost:32125 → tunnelled to openclaw-vm:32125           │
│   localhost:18789 → tunnelled to openclaw-vm:18789           │
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Qubes OS 4.2+
- Node 22+, Go 1.22+ in the server AppVM (or Docker)

## Setup

### 1. Dom0: create VM and allow ConnectTCP

```bash
# Run from dom0 (or copy-paste the commands)
bash setup-dom0.sh openclaw-vm fedora-41 sys-net
```

This creates the VM and writes a `qubes.ConnectTCP` policy so other VMs can reach ports 32125 and 18789 through qrexec.

### 2. Server VM: install everything

```bash
# Inside openclaw-vm
bash setup-vm.sh
```

Or with `qvm-run` from dom0:

```bash
qvm-run -p openclaw-vm 'curl -fsSL https://raw.githubusercontent.com/GabrieleRisso/openclaw-cursor/main/qubes-integration/scripts/setup-vm.sh | bash'
```

### 3. Server VM: authenticate and start

```bash
openclaw-cursor login
openclaw-cursor start &
openclaw gateway --port 18789
```

### 4. Client VM: connect

```bash
# From any other AppVM — opens safe qrexec tunnels
bash client-connect.sh openclaw-vm
```

This creates `localhost:32125` and `localhost:18789` tunnels to the server VM. Then:

```bash
curl http://localhost:32125/health
xdg-open http://localhost:18789/
```

### 5. Docker alternative (server VM)

```bash
git clone https://github.com/GabrieleRisso/openclaw-cursor.git
cd openclaw-cursor
docker compose up -d
```

## Systemd auto-start

```bash
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw-cursor-proxy openclaw-gateway
```

## How qubes.ConnectTCP works

`qubes.ConnectTCP` is Qubes' built-in secure TCP forwarding over qrexec. It tunnels TCP connections between VMs through dom0's qrexec policy engine -- no network routing, no firewall holes, no IP forwarding.

Dom0 policy controls exactly which source VMs can connect to which ports on which target VMs. All traffic goes through the Xen vchan (not the network stack).

## Security

- Traffic between VMs goes through qrexec (Xen vchan), not the network
- Dom0 policy whitelists specific VMs and ports -- deny by default
- The proxy uses your Cursor auth -- restrict access to trusted VMs only
- Gateway supports token auth: set `gateway.auth.token` in `~/.openclaw/openclaw.json`
- No `qubes-network-server` needed (no LAN exposure)

## Links

- [openclaw-cursor proxy](https://github.com/GabrieleRisso/openclaw-cursor)
- [OpenClaw docs](https://docs.openclaw.ai/)
- [qubes.ConnectTCP docs](https://www.qubes-os.org/doc/qrexec/#extracting-specific-connecttcp)
