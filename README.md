# qubes-claw

OpenClaw + Cursor Pro proxy on Qubes OS. Safe cross-VM AI agents via `qubes.ConnectTCP`.

## Layout

```
qubes-claw/
├── openclaw/              # openclaw-cursor proxy (Go)
├── qubes-integration/     # Qubes setup scripts + systemd
│   ├── scripts/
│   │   ├── setup-dom0.sh      # dom0: create VM + ConnectTCP policy
│   │   ├── setup-vm.sh        # server VM: install everything
│   │   └── client-connect.sh  # client VM: open qrexec tunnels
│   └── systemd/               # auto-start units
└── .cursor/rules/         # Cursor AI context rules
```

## Quick start — Qubes OS

```bash
# 1. dom0: create VM + policy
bash setup-dom0.sh openclaw-vm

# 2. server VM: install
qvm-run -p openclaw-vm 'bash setup-vm.sh'

# 3. server VM: auth + start
qvm-run -p openclaw-vm 'openclaw-cursor login && openclaw-cursor start & openclaw gateway --port 18789 &'

# 4. client VM: connect via qrexec
bash client-connect.sh openclaw-vm
curl http://localhost:32125/health
```

## Quick start — Any OS (Docker)

```bash
git clone https://github.com/GabrieleRisso/openclaw-cursor.git
cd openclaw-cursor
docker compose up -d
```

## Links

- [openclaw-cursor proxy](https://github.com/GabrieleRisso/openclaw-cursor)
- [Qubes integration](qubes-integration/)
- [OpenClaw docs](https://docs.openclaw.ai/)
