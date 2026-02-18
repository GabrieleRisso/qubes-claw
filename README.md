# qubes-claw

**Secure, isolated AI agent infrastructure on Qubes OS.**

Run [OpenClaw](https://openclaw.ai) AI agents in Xen-isolated virtual machines with airgapped administration from dom0, multi-provider LLM support, and zero-touch reboot persistence.

> **Paper:** A full academic paper with formal threat model, TikZ diagrams, and latency benchmarks is available in [`paper/`](paper/).

[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)

---

## Why This Exists

LLM agents routinely execute shell commands, modify file systems, and manage credentials. This creates an expanding attack surface that containers cannot adequately contain — Docker shares the host kernel (~400 syscalls exposed), and SELinux can't stop exfiltration through legitimate channels.

**qubes-claw** solves this by running AI agents in Xen-isolated VMs while providing airgapped administration from dom0 — the most privileged domain with **zero network interfaces**. The key insight: the administration interface doesn't need network access; it only needs structured data flow from the agent VM, which Xen's shared memory transport (qrexec) provides with hardware-enforced guarantees.

## Architecture

```
  dom0 (airgapped)                           Agent VM (StandaloneVM)
 ┌────────────────────────┐                 ┌────────────────────────┐
 │                        │    qrexec       │                        │
 │  Admin Web    :9876    │   (Xen vchan)   │  Cursor Proxy  :32125  │──→ Cursor Pro
 │  Tunnel       :32125 ══╪════════════════╪══ Gateway      :18789  │──→ OpenAI
 │  Tunnel       :18789 ══╪════════════════╪══ ConnectTCP           │──→ Anthropic
 │                        │   NOT TCP/IP    │                        │──→ Ollama
 │  (no network stack)    │                 │  (has network access)  │
 └────────────────────────┘                 └────────────────────────┘
              │                                          │
              └──────────── Xen Hypervisor ──────────────┘
                     Hardware-Enforced Isolation
```

Communication between dom0 and the agent VM uses **qrexec tunnels over Xen shared memory pages** (`vchan`), not TCP/IP networking. dom0 binds only to `127.0.0.1` — there is no network interface to attack.

### Deployment Modes

| Mode | Security | Access | Use case |
|------|----------|--------|----------|
| **Tunnel** (default) | Airgapped — dom0 only | `localhost:32125`, `localhost:18789` | Personal workstation |
| **Network** | LAN-reachable | `10.137.0.100:32125` from any VM/host | Shared team server |

## Defense in Depth — Four Security Layers

Each layer provides independent containment. Breaching one does not compromise the others.

```
┌──────────────────────────────────────┐
│      Layer 4: Token Auth             │  Gateway WebSocket authentication
├──────────────────────────────────────┤
│      Layer 3: Port Restrictions      │  ConnectTCP whitelist (32125, 18789)
├──────────────────────────────────────┤
│      Layer 2: Qrexec Policies        │  Tag-based declarative access control
├──────────────────────────────────────┤
│      Layer 1: Xen Hypervisor         │  Hardware memory isolation between VMs
└──────────────────────────────────────┘
```

| Layer | What It Stops | How |
|-------|--------------|-----|
| **L1: Xen Hypervisor** | VM escape, memory access | Hardware-enforced isolation — root in agent VM cannot touch dom0 |
| **L2: Qrexec Policies** | Unauthorized VM communication | Only `@tag:openclaw-client` VMs can connect; everything else denied |
| **L3: Port Restrictions** | Lateral movement | ConnectTCP handler only forwards to whitelisted ports |
| **L4: Token Auth** | Unauthorized dashboard access | Gateway requires token; default `dom0-local` for localhost tunnels |

### Threat Model

| Attack Vector | Mitigation |
|--------------|------------|
| Agent escapes container | Impossible — agent runs in a full Xen VM, not a container |
| Agent probes other VMs | Qrexec policy: deny by default, tag-based allow |
| Agent opens backdoor port | ConnectTCP only forwards whitelisted ports |
| Stolen WebSocket connection | Token authentication required |
| Agent exfiltrates data | Network policy + audit logging |
| Remote exploit on admin | dom0 has no network interface — physically impossible |

### Comparison with Alternatives

| Property | Docker | gVisor | **qubes-claw** |
|----------|--------|--------|----------------|
| Kernel isolation | No | Partial | **Yes (Xen)** |
| Memory isolation | No | No | **Yes (hardware)** |
| Airgapped admin | No | No | **Yes** |
| Network isolation | Partial | Partial | **Yes** |
| Multi-provider | Yes | Yes | **Yes** |
| Reboot persistence | Yes | Yes | **Yes** |
| Latency overhead | <1ms | ~5ms | **~4ms** |

## Performance

The qrexec tunnel adds ~4ms per API call — negligible against LLM inference times (500ms–30s). For streaming responses, overhead is connection-setup only.

| Path | Latency | Overhead |
|------|---------|----------|
| VM localhost (direct) | 1.2ms | — |
| dom0 → qrexec → VM | 4.8ms | +3.6ms |
| dom0 → tunnel → VM | 5.1ms | +3.9ms |

Resource footprint: ~400MB total beyond provider requirements (two socat processes + admin web on dom0, proxy + gateway on VM).

## Supported Providers

| Provider | Auth | Network | Models |
|----------|------|---------|--------|
| **Cursor Pro** | Session | HTTPS | Auto, GPT-5, Claude 4 |
| **OpenAI** | API key | HTTPS | GPT-4o, o1, o3-mini |
| **Anthropic** | API key | HTTPS | Sonnet 4, Opus 4 |
| **Ollama** | None | Local | Llama 3, Qwen, DeepSeek |

All providers expose a unified OpenAI-compatible API on port 32125. Switch providers by editing `~/.openclaw/openclaw.json` — no code changes needed.

## Quick Start

### 1. Dom0 setup

```bash
git clone https://github.com/GabrieleRisso/qubes-claw.git
cd qubes-claw

# Airgapped tunnel mode (recommended)
bash qubes-integration/scripts/setup-dom0.sh my-openclaw-vm fedora-41 sys-net 10.137.0.100 tunnel

# Or: LAN-reachable mode
bash qubes-integration/scripts/setup-dom0.sh my-openclaw-vm fedora-41 sys-net 10.137.0.100 network
```

### 2. VM setup

```bash
qvm-start my-openclaw-vm

# Pick your provider:
qvm-run -p my-openclaw-vm 'bash /path/to/qubes-claw/qubes-integration/scripts/setup-vm.sh cursor'
# Or: openai, anthropic, ollama
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

### 4. Access from dom0

```bash
curl http://127.0.0.1:32125/health                     # API health check
firefox http://127.0.0.1:18789#token=dom0-local          # Dashboard
curl http://127.0.0.1:32125/v1/chat/completions \        # Chat completion
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hello"}]}'
```

## Provider Configs

Example configs in `qubes-integration/examples/`:

| File | Provider | Auth |
|------|----------|------|
| `openclaw-cursor.json` | Cursor Pro (via proxy) | Cursor login |
| `openclaw-openai.json` | OpenAI API | `OPENAI_API_KEY` |
| `openclaw-anthropic.json` | Anthropic API | `ANTHROPIC_API_KEY` |
| `openclaw-ollama.json` | Ollama (local) | None |
| `openclaw-multi-provider.json` | All of the above | Mixed |

To switch providers:

```bash
cp qubes-integration/examples/openclaw-openai.json ~/.openclaw/openclaw.json
# Edit to add your API key, then restart:
systemctl --user restart openclaw-gateway
```

## Reboot Persistence

Everything auto-starts with zero manual intervention:

| Component | Where | Mechanism |
|-----------|-------|-----------|
| Agent VM | dom0 | `qvm-prefs autostart True` |
| Cursor proxy | VM | systemd user service + loginctl linger |
| Gateway | VM | systemd user service + loginctl linger |
| qrexec tunnels | dom0 | systemd system services |
| ConnectTCP handler | VM | `/etc/qubes-rpc/` (persistent on StandaloneVM) |
| Policies | dom0 | `/etc/qubes/policy.d/` |
| Admin web | dom0 | systemd system unit |

Boot sequence: **Xen → dom0 init → qubesd → VM autostart → systemd user services** — fully automatic.

## Adding Client VMs

Tag any VM as an OpenClaw client to give it API access:

```bash
# In dom0
qvm-tags my-other-vm add openclaw-client

# From that VM
curl http://10.137.0.100:32125/health   # network mode
# or through qrexec ConnectTCP           # tunnel mode
```

## Repo Layout

```
qubes-claw/
├── qubes-integration/
│   ├── scripts/
│   │   ├── setup-dom0.sh              # Dom0 installer (tunnel or network mode)
│   │   └── setup-vm.sh                # VM installer (provider-aware)
│   ├── systemd/                       # User service files
│   ├── dom0/
│   │   ├── openclaw-tunnel@.service   # Systemd template: socat→qrexec tunnel
│   │   ├── openclaw-tcp-forward       # Helper: qrexec-client wrapper
│   │   └── openclaw.conf              # Config: which VM to tunnel to
│   ├── vm/
│   │   └── qubes.ConnectTCP           # Qrexec handler: TCP forwarding
│   ├── policies/                      # Qrexec policy files
│   ├── examples/                      # Provider config templates
│   └── README.md                      # Detailed integration docs
├── paper/
│   ├── qubes-claw.tex                 # LaTeX source (TikZ diagrams, 50+ refs)
│   ├── qubes-claw.pdf                 # Compiled paper (~7 pages)
│   ├── posts.md                       # X/LinkedIn/Dev.to/HN/Reddit content
│   ├── blog-qubes-claw.md             # Website-ready blog post
│   ├── MANIFEST.md                    # Publication asset inventory
│   └── Makefile                       # Build: make all (PDF + PNGs + sync)
├── demo/
│   ├── qubes-claw-demo                # Screenshot/recording toolkit
│   ├── generate-diagrams.py           # Architecture diagram generator (Pillow)
│   ├── generate-posts.py              # Social media card generator (Pillow)
│   ├── architecture.png               # System architecture diagram
│   ├── persistence.png                # Reboot persistence diagram
│   └── security.png                   # Security layers diagram
├── openclaw/                          # openclaw-cursor proxy (submodule)
└── README.md                          # This file
```

## Non-Qubes (Docker)

```bash
cd openclaw
docker compose up -d
```

## Publications

The `paper/` directory contains a full academic paper and all associated marketing content. Run `make all` inside `paper/` to rebuild everything and sync to `~/Documents/qubes-claw/`.

| Asset | File | Description |
|-------|------|-------------|
| Paper (PDF) | [`paper/qubes-claw.pdf`](paper/qubes-claw.pdf) | ~7 pages, 50+ references (2025 included) |
| Blog post | [`paper/blog-qubes-claw.md`](paper/blog-qubes-claw.md) | Website-ready with frontmatter |
| Social content | [`paper/posts.md`](paper/posts.md) | X, LinkedIn, Dev.to, HN, Reddit |
| Architecture diagram | [`demo/architecture.png`](demo/architecture.png) | 1200x675, light academic palette |
| Security diagram | [`demo/security.png`](demo/security.png) | Four-layer defense visualization |
| Build guide | [`paper/MANIFEST.md`](paper/MANIFEST.md) | Complete asset inventory + deps |

## Links

- **OpenClaw docs:** [docs.openclaw.ai](https://docs.openclaw.ai/)
- **Qubes integration details:** [`qubes-integration/README.md`](qubes-integration/README.md)
- **Demo toolkit:** [`demo/README.md`](demo/README.md)
- **qvm-remote** (VM→dom0 execution): [github.com/GabrieleRisso/qvm-remote](https://github.com/GabrieleRisso/qvm-remote)
- **qubes-network-server:** [github.com/Rudd-O/qubes-network-server](https://github.com/Rudd-O/qubes-network-server)

## Citation

If you reference this work:

```bibtex
@misc{risso2026qubesclaw,
  author = {Risso, Gabriele},
  title  = {qubes-claw: Secure, Isolated AI Agent Infrastructure on Qubes OS},
  year   = {2026},
  url    = {https://github.com/GabrieleRisso/qubes-claw}
}
```
