# qubes-claw

OpenClaw + Cursor Pro proxy + Qubes OS networking. Run AI agents on Qubes with proper VM isolation and network server routing.

## What's in here

```
qubes-claw/
├── openclaw/              # openclaw-cursor proxy (Go)
│   ├── Dockerfile         # Docker containerized deployment
│   ├── docker-compose.yml
│   └── ...
├── qubes-integration/     # Qubes OS networking + systemd
│   ├── scripts/
│   │   ├── setup-dom0.sh  # Run in dom0: create VM, enable routing
│   │   └── setup-vm.sh    # Run in VM: install everything
│   ├── systemd/           # Auto-start services
│   └── README.md
├── qubes-network-server/  # Upstream qubes-network-server (submodule)
└── .cursor/rules/         # Cursor AI rules for this workspace
```

## Quick start

### Qubes OS

```bash
# 1. In dom0: create VM with server networking
bash setup-dom0.sh openclaw-vm fedora-41 sys-net

# 2. In the VM: install everything
bash setup-vm.sh

# 3. Log in and start
openclaw-cursor login
openclaw-cursor start &
openclaw gateway --port 18789
```

### Any Linux / macOS / Windows

```bash
git clone https://github.com/GabrieleRisso/qubes-claw.git
cd qubes-claw/openclaw
docker compose up -d
```

## Cursor rules

The `.cursor/rules/` directory contains AI rules for this workspace:

| Rule | Scope | Description |
|------|-------|-------------|
| `openclaw-overview.mdc` | Always | OpenClaw architecture, config, tools |
| `qubes-networking.mdc` | Always | Qubes OS network model + server setup |
| `cursor-proxy-go.mdc` | `*.go` files | Go conventions for the proxy |
| `docker-integration.mdc` | Docker files | Container build + auth patterns |

## Links

- [openclaw-cursor proxy](openclaw/)
- [Qubes integration](qubes-integration/)
- [OpenClaw docs](https://docs.openclaw.ai/)
- [qubes-network-server](https://github.com/Rudd-O/qubes-network-server)
