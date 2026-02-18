# qubes-claw — Blog, Social & Sharing Resources

> Hypervisor-Isolated Infrastructure for Autonomous LLM Agents on Qubes OS
>
> **Repository:** [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)
> **Paper:** [github.com/GabrieleRisso/qubes-claw/tree/main/paper](https://github.com/GabrieleRisso/qubes-claw/tree/main/paper)

---

## X/Twitter Thread (3 posts)

### Post 1/3 — The Hook

Autonomous LLM agents get shell access, file systems, and API keys — but they run on probabilistic models that hallucinate dangerous commands and are vulnerable to prompt injection.

Docker? Shares the host kernel. Three critical runc container escape CVEs were disclosed in November 2025 (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881).

qubes-claw runs AI agents in Xen-isolated VMs. The admin panel runs on dom0 — zero network interfaces.

Thread ↓

github.com/GabrieleRisso/qubes-claw

### Post 2/3 — The Architecture

How qubes-claw works:

- Agent VM runs a multi-provider proxy (OpenAI, Anthropic, Ollama, etc.)
- dom0 connects via qrexec tunnels (Xen shared memory — NOT TCP/IP)
- One-command setup

4 security layers:
1. Xen hypervisor (hardware memory isolation)
2. Qrexec policies (tag-based access control)
3. Port whitelisting (ConnectTCP)
4. Token authentication

Even root in the agent VM cannot touch dom0.

2025 research shows 51–73% unsafe behavior in safety-critical agent tasks (OpenAgentSafety). Hypervisor isolation is no longer optional.

[attach: architecture diagram]

### Post 3/3 — The Paper + Call to Action

The academic paper covers:
- Formal threat model + hypervisor containment theorem
- Latency benchmarks (<5ms overhead)
- Multi-provider configuration
- Reboot persistence (zero-touch)
- 50+ cited sources including 2025 work:
  IsolateGPT (NDSS '25), Progent, CaMeL, OS-Harm, QSB-108

Open source. Full LaTeX source + diagrams in the repo.

Paper: github.com/GabrieleRisso/qubes-claw/tree/main/paper
Repo: github.com/GabrieleRisso/qubes-claw

---

## LinkedIn Article

### Title: "Hypervisor-Isolated LLM Agents: Why Xen Beats Containers for AI Security"

**The Problem**

Autonomous AI coding agents now routinely execute shell commands, modify source code, and manage credentials. They operate with the same privilege level as human developers — but they run on probabilistic language models vulnerable to prompt injection, hallucination, and data exfiltration.

The 2025 OpenAgentSafety benchmark found unsafe behavior in 51–73% of safety-critical tasks across five frontier LLMs. OS-Harm demonstrated that all tested models remain vulnerable to prompt injection and misuse scenarios. Meanwhile, three critical runc container escape CVEs (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881) disclosed in November 2025 remind us that same-kernel isolation remains fundamentally insufficient.

**The Solution: Hypervisor-Level Agent Isolation**

qubes-claw is an open-source framework that runs AI agents in Xen-isolated VMs on Qubes OS. The key architectural insight: the administration interface requires only structured data from the agent VM, which Xen's shared-memory transport (qrexec) provides with hardware-enforced guarantees. The admin panel runs on dom0 — a domain with literally no network interface.

**Architecture Highlights:**

- **Agent VM**: Runs a multi-provider proxy (OpenAI, Anthropic, Ollama, local models) with network access to LLM APIs only
- **dom0 (airgapped)**: Runs the admin web UI and tunnel endpoints. No network interface. Cannot be compromised remotely.
- **qrexec tunnels**: Replace TCP/IP with Xen shared memory pages. Every call is policy-controlled and auditable.

**Defense in Depth (4 Layers):**

| Layer | Mechanism | What It Stops |
|-------|-----------|---------------|
| L1 | Xen hypervisor | VM escape, memory access |
| L2 | Qrexec policy engine | Unauthorized connections |
| L3 | Port restrictions | Service enumeration |
| L4 | Token authentication | Unauthenticated access |

Each layer is independent — breaching one does not compromise the others.

**Performance:**

The qrexec tunnel adds ~4ms per request — negligible against LLM inference times of 500ms–30s.

**Positioning in the Research Landscape:**

The paper situates this work relative to IsolateGPT (NDSS 2025), which provides execution isolation for agentic systems; Progent (2025), the first privilege-control framework for LLM agents; and CaMeL (2025), which defeats prompt injection by separating control and data flows. qubes-claw operates at a lower level, providing the hardware-enforced foundation on which application-layer defenses can be composed.

**Links:**
- Repository: [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)
- Paper (LaTeX + PDF): [github.com/GabrieleRisso/qubes-claw/tree/main/paper](https://github.com/GabrieleRisso/qubes-claw/tree/main/paper)

---

## Blog Post (Website / Personal Blog)

### Title: "Airgapped AI: Running LLM Agents in Xen VMs with qubes-claw"

*An open-source framework for hypervisor-isolated autonomous LLM agent infrastructure on Qubes OS, with hardware-enforced containment and zero-touch reboot persistence.*

#### The Trust Problem in 2025

When an AI agent runs `rm -rf /`, modifies SSH keys, or curls arbitrary URLs, the system is trusting a probabilistic model with full host access. The standard response — "use Docker" — ignores a fundamental issue: Docker shares the host kernel, exposing approximately 400 syscalls as attack surface. A container escape gives the agent full host access.

This is not theoretical. In November 2025, three critical runc container escape CVEs were disclosed (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881), exploiting mount race conditions for full container breakout. The 2025 OpenAgentSafety benchmark found that 51–73% of safety-critical tasks exhibited unsafe behavior across five frontier LLMs. OS-Harm confirmed that all tested models remain vulnerable to prompt injection and misuse.

The conclusion is clear: same-kernel isolation is insufficient for autonomous AI agents.

#### Enter Qubes OS

Qubes OS runs each security domain in a separate Xen virtual machine. The control domain (dom0) has no network interface — it is physically impossible to compromise remotely. Inter-VM communication uses qrexec, a custom RPC framework over Xen shared memory pages, not TCP/IP.

This is the ideal foundation for AI agent isolation.

#### Architecture

qubes-claw creates a StandaloneVM for AI agents with three components:

1. **Multi-Provider Proxy** (port 32125) — Translates between agents and LLM providers. Supports OpenAI, Anthropic, Ollama, and other OpenAI-compatible endpoints.
2. **Gateway Dashboard** (port 18789) — WebSocket dashboard for real-time monitoring and administration.
3. **qubes.ConnectTCP handler** — Bridges qrexec connections to localhost services.

On dom0, socat tunnels listen on 127.0.0.1 and forward through qrexec-client to the VM. The admin web UI (port 9876) provides a unified control panel.

```
dom0 (airgapped)          ←— qrexec/vchan —→          Agent VM
┌──────────────────┐                          ┌──────────────────┐
│ Admin Web :9876  │                          │ Proxy :32125     │
│ Tunnel :32125    │ ════ Xen shared mem ═══ │ Gateway :18789   │
│ Tunnel :18789    │                          │ ConnectTCP       │
└──────────────────┘                          └──────────────────┘
        │                                              │
    (no network)                              (HTTPS → LLM APIs)
```

#### Security: Four Independent Layers

| Layer | Protection | Mechanism |
|-------|-----------|-----------|
| L1 | VM escape prevention | Xen hypervisor hardware memory isolation |
| L2 | Connection authorization | Qrexec declarative, tag-based policies |
| L3 | Service enumeration prevention | ConnectTCP port whitelist |
| L4 | Unauthenticated access prevention | Gateway token authentication |

Each layer is independent — breaching one does not compromise the others.

#### Performance

| Path | Latency | Overhead |
|------|---------|----------|
| VM localhost (direct) | 1.2ms | — |
| dom0 → qrexec → VM | 4.8ms | +3.6ms |

Negligible against LLM inference (500ms–30s).

#### Getting Started

```bash
# In dom0: create VM + tunnels + policies
bash setup-dom0.sh myvm fedora-41 sys-net 10.137.0.100 tunnel

# In the VM: install provider
bash setup-vm.sh openai    # or: anthropic, ollama
```

Everything persists across reboots automatically.

#### The Paper

The repository includes a full academic paper with formal threat model, TikZ architecture diagrams, latency benchmarks, and comparison tables. It cites 50+ sources including 2025 work from NDSS, NVD, and the Qubes Security Bulletin series.

**Repository:** [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)
**Paper:** [github.com/GabrieleRisso/qubes-claw/tree/main/paper](https://github.com/GabrieleRisso/qubes-claw/tree/main/paper)

---

## Dev.to / Medium Article

### Title: "Why Containers Are Not Enough: Hypervisor Isolation for AI Agents"

**Tags:** `#security` `#ai` `#qubes` `#opensource`

**TL;DR:** qubes-claw runs autonomous LLM agents in Xen-isolated VMs on Qubes OS. The admin panel runs on dom0 (no network interface). Four independent security layers. <5ms overhead. Zero-touch reboot persistence. Full academic paper included.

---

The AI agent security landscape in 2025 is sobering:

- **51–73% unsafe behavior** in safety-critical tasks (OpenAgentSafety benchmark)
- **All frontier models** remain vulnerable to prompt injection (OS-Harm benchmark)
- **Three critical runc container escapes** disclosed in November 2025

Containers share the host kernel. A container escape = full host access. For an AI agent with shell access, this is game over.

**qubes-claw** takes a different approach: each agent runs in a full Xen VM. The control plane runs on dom0 — a domain with *no network interface*. Communication uses Xen shared memory (qrexec), not TCP/IP.

**Why this matters for AI agent developers:**

1. **Agents get full shell access** inside their VM — unrestricted development capability
2. **Agents cannot escape** the VM — hardware-enforced by the Xen hypervisor
3. **Administration is airgapped** — dom0 has no NIC, period
4. **Multi-provider support** — OpenAI, Anthropic, Ollama, any OpenAI-compatible API
5. **Performance tax is minimal** — 4ms per qrexec hop vs 500ms–30s LLM inference

**The Research Context:**

The paper positions this work relative to:
- IsolateGPT (NDSS 2025) — application-layer execution isolation
- Progent (2025) — privilege-control policies for agents
- CaMeL (2025) — control/data flow separation against prompt injection

qubes-claw provides the hardware-enforced foundation layer beneath all of these.

**Links:**
- GitHub: [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)
- Paper: [github.com/GabrieleRisso/qubes-claw/tree/main/paper](https://github.com/GabrieleRisso/qubes-claw/tree/main/paper)

---

## Hacker News Submission

**Title:** qubes-claw: Hypervisor-isolated infrastructure for LLM agents on Qubes OS

**URL:** https://github.com/GabrieleRisso/qubes-claw

**Comment:**

qubes-claw runs autonomous AI agents in Xen-isolated VMs. The admin panel runs on dom0, which has no network interface.

The architecture: agent VM has shell access + LLM API access. dom0 connects to the VM via qrexec (Xen shared memory). Four independent security layers (hypervisor isolation, qrexec policies, port whitelisting, token auth).

Motivation: containers share the host kernel (three runc escape CVEs in November 2025 alone). For agents with shell access, same-kernel isolation is insufficient.

The repo includes a full academic paper with formal threat model, latency benchmarks (<5ms overhead), and 50+ references including 2025 publications from NDSS and NVD.

Pure open source. Works with OpenAI, Anthropic, Ollama, and any OpenAI-compatible API.

---

## Reddit Posts

### r/QubesOS

**Title:** qubes-claw: Running AI agents in Xen-isolated VMs with airgapped dom0 administration

qubes-claw is a framework for running autonomous LLM agents in StandaloneVMs on Qubes OS. The admin web UI runs on dom0 (no NIC), connected via qrexec tunnels.

Features:
- Multi-provider LLM proxy (OpenAI, Anthropic, Ollama)
- 4 security layers (Xen, qrexec policies, port whitelist, token auth)
- <5ms qrexec overhead
- Zero-touch reboot persistence (VM autostart + systemd + qrexec policies)
- Full academic paper with formal threat model

The paper cites QSB-108 (XSA-471, July 2025) and discusses microarchitectural side-channel considerations for the architecture.

GitHub: https://github.com/GabrieleRisso/qubes-claw

### r/LocalLLaMA

**Title:** Open-source framework for running AI agents in Xen-isolated VMs (Qubes OS) — supports Ollama, OpenAI, Anthropic

qubes-claw isolates autonomous AI agents in Xen VMs on Qubes OS. The admin panel runs on dom0 (physically airgapped — no network interface).

Why it matters: agents need shell access and API keys to be useful, but containers share the host kernel (three critical runc escape CVEs in Nov 2025). Xen provides hardware-enforced memory isolation.

Supports Ollama for local models. The proxy translates between any OpenAI-compatible API.

Full academic paper included with formal security analysis, latency benchmarks, and 50+ references.

GitHub: https://github.com/GabrieleRisso/qubes-claw

### r/netsec

**Title:** Academic paper: Hypervisor-isolated infrastructure for autonomous LLM agents (Xen/Qubes OS, 50+ refs including 2025 work)

A formal treatment of running autonomous AI agents in Xen-isolated VMs on Qubes OS. The paper covers:

- Threat model for autonomous LLM agents with shell access
- Hypervisor containment theorem
- Four independent defense layers
- Latency benchmarks (<5ms overhead)
- Comparison with Docker, gVisor, Firecracker
- 50+ citations including IsolateGPT (NDSS 2025), Progent, CaMeL, runc CVE-2025-* series, QSB-108

The architecture preserves the Qubes invariant that dom0 has no network interface while enabling full agent autonomy inside the VM.

Paper (LaTeX + PDF): https://github.com/GabrieleRisso/qubes-claw/tree/main/paper
Repo: https://github.com/GabrieleRisso/qubes-claw

---

## Image Assets

The following diagram PNGs are available in `demo/` for use in posts:

| File | Description | Recommended Use |
|------|-------------|-----------------|
| `architecture.png` | System architecture diagram | LinkedIn header, blog hero |
| `security.png` | Security layers diagram | X post 2, r/netsec |
| `persistence.png` | Reboot persistence flow | Blog detail section |

Social media cards are available in `~/Documents/qubes-claw/posts/`:

| File | Description |
|------|-------------|
| `post-1.png` | Architecture overview card |
| `post-2.png` | Security layers card |
| `post-3.png` | Performance metrics card |
