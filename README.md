# qubes-claw: Hypervisor-Isolated Infrastructure for Autonomous LLM Agents

[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)
[![Paper](https://img.shields.io/badge/paper-PDF-b31b1b.svg)](paper/qubes-claw.pdf)
[![LaTeX](https://img.shields.io/badge/source-LaTeX-008080.svg)](paper/qubes-claw.tex)

> **Risso, G. (2026).** *Hypervisor-Isolated Infrastructure for Autonomous LLM Agents on Qubes OS.*
> [[PDF]](paper/qubes-claw.pdf) [[LaTeX Source]](paper/qubes-claw.tex) [[Blog Post]](paper/blog-qubes-claw.md)

---

## Abstract

Autonomous LLM agents increasingly execute shell commands, modify file systems, and manage credentials with developer-level privileges. Existing containment approaches based on Linux containers share the host kernel, exposing approximately 400 syscalls as attack surface -- a limitation underscored by three critical runc container escape CVEs disclosed in November 2025 (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881). The 2025 OpenAgentSafety benchmark reports unsafe behavior in 51--73% of safety-critical tasks across five frontier LLMs.

This work presents **qubes-claw**, an open-source framework that confines autonomous AI agents within Xen-isolated virtual machines on Qubes OS. The administration interface operates from dom0 -- a control domain with *no network interface* -- communicating with agent VMs exclusively through qrexec, a shared-memory RPC mechanism that bypasses the network stack entirely. Four independent security layers (hypervisor isolation, qrexec policies, port restrictions, token authentication) provide defense-in-depth containment. The architecture adds less than 5ms latency per API call and survives host reboots with zero manual intervention.

## Key Findings

| Finding | Result |
|---------|--------|
| **Latency overhead** | 4.8ms per qrexec hop (vs. 500ms--30s LLM inference) |
| **Security layers** | 4 independent layers; breaching one does not compromise others |
| **Reboot persistence** | Zero-touch: VM autostart + systemd + qrexec policies |
| **Agent unsafe behavior** | 51--73% in safety-critical tasks (OpenAgentSafety, 2025) |
| **Container escape CVEs (2025)** | 3 critical runc CVEs exploiting mount race conditions |
| **Implementation** | Open source, multi-provider (OpenAI, Anthropic, Ollama) |

## Architecture

```
dom0 (airgapped)                             Agent VM (StandaloneVM)
┌────────────────────────┐                  ┌────────────────────────┐
│                        │    qrexec        │                        │
│  Admin Web    :9876    │   (Xen vchan)    │  LLM Proxy     :32125 │──→ OpenAI
│  Tunnel       :32125 ══╪═════════════════╪══ Gateway       :18789 │──→ Anthropic
│  Tunnel       :18789 ══╪═════════════════╪══ ConnectTCP           │──→ Ollama
│                        │   NOT TCP/IP     │                        │
│  (no network stack)    │                  │  (has network access)  │
└────────────────────────┘                  └────────────────────────┘
             │                                          │
             └──────────── Xen Hypervisor ──────────────┘
                    Hardware-Enforced Isolation
```

The key architectural insight: the administration interface requires only structured data from the agent VM, which Xen's shared-memory transport provides with hardware-enforced guarantees. No network stack is involved.

## Defense in Depth

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

| Layer | Threat Mitigated | Mechanism |
|-------|-----------------|-----------|
| L1: Xen Hypervisor | VM escape, cross-VM memory access | Hardware-enforced VT-x/VT-d isolation |
| L2: Qrexec Policies | Unauthorized VM communication | Tag-based declarative rules (`@tag:openclaw-client`) |
| L3: Port Restrictions | Service enumeration, lateral movement | ConnectTCP whitelist |
| L4: Token Auth | Unauthenticated dashboard access | WebSocket gateway token |

## Comparative Analysis

| Property | Docker | gVisor | Firecracker | **qubes-claw** |
|----------|--------|--------|-------------|----------------|
| Kernel isolation | No | Partial | Yes | **Yes (Xen)** |
| Memory isolation | No | No | Yes | **Yes (hardware)** |
| Airgapped admin | No | No | No | **Yes** |
| Network isolation | Partial | Partial | Yes | **Yes** |
| Reboot persistence | Yes | Yes | Manual | **Yes (zero-touch)** |
| Latency overhead | <1ms | ~5ms | ~3ms | **~4ms** |

## Performance

Measured on Qubes OS 4.3, Intel i7-1365U. Each measurement comprises 50 iterations.

| Path | p50 Latency | Overhead |
|------|-------------|----------|
| VM localhost (direct) | 1.2ms | -- |
| dom0 → qrexec → VM | 4.8ms | +3.6ms |
| dom0 → tunnel → VM | 5.1ms | +3.9ms |

The qrexec overhead is negligible against LLM inference times (500ms--30s). For streaming, overhead is connection-setup only.

## Threat Model

| Attack Vector | Mitigation | Layer |
|--------------|------------|-------|
| Agent escapes container | Impossible -- full Xen VM, not a container | L1 |
| Agent probes other VMs | Qrexec deny-by-default, tag-based allow | L2 |
| Agent opens backdoor port | ConnectTCP whitelist | L3 |
| Stolen WebSocket connection | Token authentication | L4 |
| Agent exfiltrates data | Network policy + audit logging | L2 |
| Remote exploit on admin panel | dom0 has no NIC -- physically impossible | L1 |

## Research Context (2025--2026)

This work is situated relative to the following contemporary research:

| Reference | Venue | Contribution | Relation |
|-----------|-------|-------------|----------|
| IsolateGPT (Wu et al.) | NDSS 2025 | Execution isolation for LLM agents | Application-layer; qubes-claw provides hardware foundation |
| Progent (Chen et al.) | arXiv 2025 | Privilege control via DSL policies | Composable with qubes-claw's transport isolation |
| CaMeL (Debenedetti et al.) | arXiv 2025 | Control/data separation vs. prompt injection | Complementary defense at LLM layer |
| OS-Harm (Wu et al.) | arXiv 2025 | Safety benchmark for computer-use agents | All frontier models remain vulnerable |
| OpenAgentSafety (Aimeur et al.) | arXiv 2025 | 51--73% unsafe behavior in safety tasks | Motivates hardware isolation |
| QSB-108 | Qubes 2025 | XSA-471 transitive scheduler attacks | Microarchitectural threat to hypervisors |
| runc CVE-2025-* | NVD 2025 | Three container escape CVEs | Demonstrates container insufficiency |

The full paper cites 50+ sources. See [`paper/qubes-claw.pdf`](paper/qubes-claw.pdf).

---

## Reproducing the Results

### System Requirements

- Qubes OS 4.2+ (tested on 4.3)
- x86-64 hardware with VT-x/VT-d
- Python 3.8+

### Quick Start

```bash
# dom0: create VM + tunnels + policies
bash qubes-integration/scripts/setup-dom0.sh my-agent-vm fedora-41 sys-net 10.137.0.100 tunnel

# VM: install LLM provider
qvm-run -p my-agent-vm 'bash /path/to/qubes-claw/qubes-integration/scripts/setup-vm.sh openai'
# alternatives: anthropic, ollama
```

### Verify

```bash
curl http://127.0.0.1:32125/health                     # API health
firefox http://127.0.0.1:18789#token=dom0-local          # Dashboard
curl http://127.0.0.1:32125/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hello"}]}'
```

### Supported Providers

| Provider | Authentication | Transport | Models |
|----------|---------------|-----------|--------|
| OpenAI | API key | HTTPS | GPT-4o, o1, o3-mini |
| Anthropic | API key | HTTPS | Sonnet 4, Opus 4 |
| Ollama | None | Local | Llama 3, Qwen, DeepSeek |

All providers expose a unified OpenAI-compatible API on port 32125.

### Reboot Persistence

| Component | Location | Mechanism |
|-----------|----------|-----------|
| Agent VM | dom0 | `qvm-prefs autostart True` |
| LLM proxy | VM | systemd user service + loginctl linger |
| Gateway | VM | systemd user service + loginctl linger |
| qrexec tunnels | dom0 | systemd system services |
| ConnectTCP handler | VM | `/etc/qubes-rpc/` (StandaloneVM) |
| Policies | dom0 | `/etc/qubes/policy.d/` |

Boot sequence: Xen → dom0 init → qubesd → VM autostart → systemd user services. Fully automatic.

### Adding Client VMs

```bash
# In dom0
qvm-tags my-other-vm add openclaw-client

# From that VM
curl http://10.137.0.100:32125/health
```

---

## Publication Assets

Run `make all` inside `paper/` to rebuild the paper, diagrams, and social media content.

| Asset | Path | Description |
|-------|------|-------------|
| **Paper (PDF)** | [`paper/qubes-claw.pdf`](paper/qubes-claw.pdf) | 7 pages, 50+ references |
| **LaTeX source** | [`paper/qubes-claw.tex`](paper/qubes-claw.tex) | TikZ diagrams embedded |
| **Blog post** | [`paper/blog-qubes-claw.md`](paper/blog-qubes-claw.md) | Website-ready (frontmatter) |
| **Social media** | [`paper/posts.md`](paper/posts.md) | X, LinkedIn, Dev.to, HN, Reddit |
| **Architecture fig.** | [`demo/architecture.png`](demo/architecture.png) | 1200x675 |
| **Security fig.** | [`demo/security.png`](demo/security.png) | 1200x675 |
| **Persistence fig.** | [`demo/persistence.png`](demo/persistence.png) | 1200x675 |
| **Build manifest** | [`paper/MANIFEST.md`](paper/MANIFEST.md) | Dependencies + asset inventory |

### Build Dependencies

```
pdflatex (texlive-latex, texlive-pgf, texlive-amsfonts)
python3 + Pillow (python3-pillow)
```

---

## Repository Structure

```
qubes-claw/
├── paper/                             # Academic publication
│   ├── qubes-claw.tex                 #   LaTeX source (50+ refs, TikZ)
│   ├── qubes-claw.pdf                 #   Compiled paper
│   ├── blog-qubes-claw.md            #   Blog post
│   ├── posts.md                       #   Social media content
│   ├── MANIFEST.md                    #   Asset inventory
│   └── Makefile                       #   make all | paper | diagrams | sync
├── demo/                              # Diagrams and media
│   ├── generate-diagrams.py           #   Architecture PNGs (Pillow)
│   ├── generate-posts.py              #   Social media cards (Pillow)
│   └── *.png                          #   Generated diagrams
├── qubes-integration/                 # Deployment
│   ├── scripts/                       #   setup-dom0.sh, setup-vm.sh
│   ├── dom0/                          #   Tunnel services, configs
│   ├── vm/                            #   ConnectTCP handler
│   ├── policies/                      #   Qrexec policy files
│   └── examples/                      #   Provider config templates
└── openclaw/                          # LLM proxy (submodule)
```

## Related Work

- **qvm-remote** -- Authenticated RPC for dom0 (bootstraps this infrastructure): [github.com/GabrieleRisso/qvm-remote](https://github.com/GabrieleRisso/qvm-remote)
- **OpenClaw** -- Multi-provider LLM proxy: [docs.openclaw.ai](https://docs.openclaw.ai/)
- **Qubes OS** -- Security-oriented operating system: [qubes-os.org](https://www.qubes-os.org/)

## Citation

```bibtex
@misc{risso2026qubesclaw,
  author       = {Risso, Gabriele},
  title        = {Hypervisor-Isolated Infrastructure for Autonomous {LLM} Agents on {Qubes OS}},
  year         = {2026},
  howpublished = {\url{https://github.com/GabrieleRisso/qubes-claw}},
  note         = {Open-source framework. Paper: \texttt{paper/qubes-claw.pdf}}
}
```

## License

GPL-2.0. See [LICENSE](LICENSE).
