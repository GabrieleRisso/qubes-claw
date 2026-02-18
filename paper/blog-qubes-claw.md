---
title: "Airgapped AI: Hypervisor-Isolated Infrastructure for LLM Agents on Qubes OS"
date: 2026-02-18
author: Gabriele Risso
tags: [security, ai, qubes-os, xen, open-source, llm-agents]
description: "An open-source framework for running autonomous LLM agents in Xen-isolated VMs with hardware-enforced containment and airgapped administration."
image: /images/qubes-claw-architecture.png
---

# Airgapped AI: Hypervisor-Isolated Infrastructure for LLM Agents on Qubes OS

Autonomous AI coding agents now routinely execute shell commands, modify source code, install packages, and manage credentials. They operate with developer-level privileges but run on probabilistic language models subject to hallucination, prompt injection, and data exfiltration.

The industry response, containerization, is proving inadequate. In November 2025 alone, three critical runc container escape CVEs were disclosed (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881), each exploiting mount race conditions for full container breakout. The 2025 OpenAgentSafety benchmark found unsafe behavior in **51-73% of safety-critical tasks** across five frontier LLMs.

**qubes-claw** takes a fundamentally different approach: each AI agent runs in a full Xen virtual machine. The administration panel runs on dom0, a domain with *no network interface*.

**Repository:** [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)

---

## Why Hypervisor Isolation?

Containers share the host kernel. A container escape gives the attacker the same access as the host process, including all other containers, the host filesystem, and the network stack. Approximately 400 syscalls are exposed to every container.

A hypervisor (Xen Type-1) interposes a hardware-enforced boundary. Each VM gets its own kernel, its own memory space, and its own device model. A compromised VM cannot access another VM's memory. This is enforced by the CPU's VT-x/VT-d extensions, not by software.

| Isolation | Boundary | Escape Impact | Attack Surface |
|-----------|----------|---------------|----------------|
| Docker | cgroups/namespaces | Full host access | ~400 syscalls |
| gVisor | User-space kernel | Limited host access | Reduced syscall set |
| **Xen VM** | **Hardware MMU** | **Nothing** (different address space) | **Hypercall ABI** |

For AI agents with shell access, this distinction is existential.

---

## Architecture

qubes-claw creates a StandaloneVM for AI agents with three components:

1. **Multi-Provider Proxy** (port 32125) -- Translates between agents and LLM providers. Supports OpenAI, Anthropic, Ollama, and any OpenAI-compatible API.
2. **Gateway Dashboard** (port 18789) -- WebSocket interface for real-time monitoring and administration.
3. **qubes.ConnectTCP handler** -- Bridges qrexec connections to localhost services.

On dom0, socat tunnels listen on 127.0.0.1 and forward through qrexec-client to the VM:

```
dom0 (airgapped)          <-- qrexec/vchan -->          Agent VM
+------------------+                          +------------------+
| Admin Web :9876  |                          | Proxy :32125     |
| Tunnel :32125    | ==== Xen shared mem ==== | Gateway :18789   |
| Tunnel :18789    |                          | ConnectTCP       |
+------------------+                          +------------------+
        |                                              |
    (no network)                              (HTTPS -> LLM APIs)
```

Communication between dom0 and the agent VM uses **qrexec**, Qubes's custom RPC framework built on Xen shared memory pages (vchan). This is not TCP/IP. There is no network stack involved. Every connection is mediated by declarative qrexec policies.

---

## Four Independent Security Layers

| Layer | Mechanism | What It Prevents |
|-------|-----------|-----------------|
| **L1: Xen Hypervisor** | Hardware memory isolation via VT-x/VT-d | VM escape, cross-VM memory access |
| **L2: Qrexec Policies** | Tag-based, declarative access control | Unauthorized VM-to-VM connections |
| **L3: Port Restrictions** | ConnectTCP whitelist (only ports 32125, 18789) | Service enumeration, lateral movement |
| **L4: Token Authentication** | WebSocket gateway authentication | Unauthenticated dashboard access |

Each layer is independent. Breaching one does not compromise the others. This follows the defense-in-depth principle formalized in NIST SP 800-53.

---

## Performance

The qrexec tunnel adds approximately **4ms** per request. For LLM inference requests that take 500ms to 30s, this overhead is negligible:

| Path | Latency | Overhead |
|------|---------|----------|
| VM localhost (direct) | 1.2ms | -- |
| dom0 -> qrexec -> VM | 4.8ms | +3.6ms |

For streaming responses, the overhead is connection-setup only. Subsequent chunks flow through the established vchan at near-native speed.

---

## Reboot Persistence

Everything auto-starts with zero manual intervention:

- **VM**: Qubes autostart flag
- **Services**: systemd user units + loginctl linger
- **Tunnels**: systemd system units (dom0)
- **Policies**: qrexec policy files (persistent by default)

A power cycle returns the full stack to operational state automatically.

---

## Research Context (2025)

The accompanying academic paper positions this work in the context of recent research:

- **IsolateGPT** (NDSS 2025) -- execution isolation for LLM agentic systems at the application layer
- **Progent** (2025) -- programmable privilege control for LLM agents using domain-specific policies
- **CaMeL** (2025) -- defeats prompt injection by architecturally separating control and data flows
- **OS-Harm** (2025) -- benchmark showing all frontier models remain vulnerable to prompt injection
- **OpenAgentSafety** (2025) -- 51-73% unsafe behavior rates across five frontier LLMs
- **QSB-108** (July 2025) -- Transitive Scheduler Attacks (XSA-471) on AMD Zen 3/4

qubes-claw operates at the hardware isolation layer, beneath all application-layer defenses. These approaches are complementary, not competing.

---

## Getting Started

```bash
# In dom0: create VM + tunnels + policies
bash setup-dom0.sh myvm fedora-41 sys-net 10.137.0.100 tunnel

# In the VM: install provider
bash setup-vm.sh openai    # or: anthropic, ollama
```

Two commands. Full stack deployed.

---

## The Paper

The repository includes a full academic paper (LaTeX source + compiled PDF) with:

- Formal threat model for autonomous LLM agents
- Hypervisor containment theorem
- Network isolation and policy completeness properties
- Latency benchmarks
- Comparison with Docker, gVisor, Firecracker
- 50+ cited references including 11 from 2025

**Paper:** [github.com/GabrieleRisso/qubes-claw/tree/main/paper](https://github.com/GabrieleRisso/qubes-claw/tree/main/paper)

**Repository:** [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)

---

*See also: [qvm-remote](https://github.com/GabrieleRisso/qvm-remote) -- the authenticated RPC framework that bootstraps this infrastructure from within a VM.*
