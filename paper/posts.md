# qubes-claw — Social & Blog Posts

## X/Twitter Posts (3 posts, thread format)

### Post 1/3 — The Hook

🔒 I built an airgapped AI agent infrastructure on Qubes OS.

No containers. No shared kernels. Full Xen hypervisor isolation.

Your LLM agents get shell access, file systems, API keys — but they can NEVER escape their VM.

The admin panel runs on dom0 — zero network interfaces. Unhackable by design.

🧵 Thread ↓

github.com/GabrieleRisso/qubes-claw

---

### Post 2/3 — The Architecture

Here's how qubes-claw works:

• Agent VM runs OpenClaw (multi-provider proxy)
• dom0 connects via qrexec tunnels (Xen shared memory — NOT TCP/IP)
• Supports Cursor Pro, OpenAI, Anthropic, Ollama
• One-command setup: `bash setup-dom0.sh`

4 security layers:
1. Xen hypervisor (hardware memory isolation)
2. Qrexec policies (tag-based access control)
3. Port whitelisting (ConnectTCP)
4. Token authentication

Even root in the agent VM can't touch dom0.

[architecture diagram screenshot]

---

### Post 3/3 — Call to Action

Why this matters:

Docker shares your kernel (~400 syscalls exposed).
gVisor is partial isolation at best.
qubes-claw gives you Xen-level guarantees.

The paper covers:
• Full threat model
• Latency benchmarks (<5ms overhead)
• Multi-provider config
• Reboot persistence (zero-touch)

Open source. Ready to deploy.

⭐ github.com/GabrieleRisso/qubes-claw
📄 Paper: github.com/GabrieleRisso/qubes-claw/tree/main/paper

---

## LinkedIn Article

### Title: "Why I Run My AI Agents in Xen-Isolated VMs (And You Should Too)"

**The Problem**

AI coding agents now routinely execute shell commands, modify code, and manage credentials. We grant them the same access level as ourselves — but they run on probabilistic language models that can hallucinate dangerous commands, be manipulated through prompt injection, or exfiltrate data.

Docker? Shares the host kernel. SELinux? Can't stop exfiltration through legitimate channels. Air-gapping? Impractical when agents need API access.

**The Solution: qubes-claw**

I built qubes-claw — an open-source framework that runs AI agents in Xen-isolated VMs on Qubes OS. The key insight: the administration interface doesn't need network access. It only needs structured data from the agent VM, which Xen's shared memory transport (qrexec) provides with hardware-enforced guarantees.

**Architecture Highlights:**

- **Agent VM**: Runs OpenClaw's multi-provider proxy (Cursor Pro, OpenAI, Anthropic, Ollama) with network access to reach LLM APIs
- **dom0 (airgapped)**: Runs the admin web UI and tunnel endpoints. Has literally no network interface. Cannot be compromised remotely.
- **qrexec tunnels**: Replace TCP/IP with Xen shared memory pages. Every call is policy-controlled and auditable.

**Defense in Depth (4 Layers):**

1. Xen hypervisor — hardware memory isolation between VMs
2. Qrexec policy engine — tag-based, declarative access control
3. Port restrictions — ConnectTCP whitelist (only ports 32125, 18789)
4. Token authentication — WebSocket gateway auth

**Performance:**

The qrexec tunnel adds ~4ms per request — negligible against LLM inference times of 500ms–30s. For streaming, overhead is connection-setup only.

**Reboot Persistence:**

Everything auto-starts: VM (Qubes autostart), services (systemd + loginctl linger), tunnels (systemd system units), policies (qrexec). Zero manual intervention.

**Setup:**

```
# dom0
bash setup-dom0.sh myvm fedora-41 sys-net 10.137.0.100 tunnel

# VM
bash setup-vm.sh cursor
```

Two commands. That's it.

**The Paper:**

I've written a full academic paper covering the architecture, threat model, security analysis, latency benchmarks, and comparison with Docker/gVisor. Available in the repo.

**Links:**
- GitHub: github.com/GabrieleRisso/qubes-claw
- Paper (LaTeX + PDF): github.com/GabrieleRisso/qubes-claw/tree/main/paper

---

## Blog Post

### Title: "Airgapped AI: Running LLM Agents in Xen VMs with qubes-claw"

*How I built a secure, multi-provider AI agent infrastructure on Qubes OS with hardware-enforced isolation and zero-touch reboot persistence.*

#### The Trust Problem

When you let an AI agent run `rm -rf /`, modify your SSH keys, or curl arbitrary URLs, you're trusting a probabilistic model with your entire system. The standard response — "just use Docker" — ignores that Docker shares the host kernel, exposing ~400 syscalls as attack surface. A container escape gives the agent full host access.

I wanted something better.

#### Enter Qubes OS

Qubes OS runs each security domain in a separate Xen virtual machine. The control domain (dom0) has no network interface — it's physically impossible to compromise remotely. Inter-VM communication uses qrexec, a custom RPC framework over Xen shared memory pages, not TCP/IP.

This is the perfect foundation for AI agent isolation.

#### Architecture

qubes-claw creates a StandaloneVM for AI agents with three components:

1. **OpenClaw Proxy** (port 32125) — Translates between your agent and LLM providers. Supports Cursor Pro, OpenAI, Anthropic, and local Ollama.
2. **OpenClaw Gateway** (port 18789) — WebSocket dashboard for real-time monitoring and administration.
3. **qubes.ConnectTCP handler** — Bridges qrexec connections to localhost services.

On dom0, two socat tunnels listen on 127.0.0.1 and forward through qrexec-client to the VM. The admin web UI (port 9876) provides a unified control panel.

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

1. **Xen Hypervisor**: Hardware memory isolation. Root in the agent VM cannot access dom0.
2. **Qrexec Policies**: Declarative, tag-based. Only `@tag:openclaw-client` VMs can connect.
3. **Port Restrictions**: ConnectTCP only forwards to whitelisted ports.
4. **Token Auth**: Gateway requires authentication token.

Each layer is independent — breaching one doesn't compromise the others.

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

# In the VM: install your provider
bash setup-vm.sh cursor    # or: openai, anthropic, ollama
```

Everything persists across reboots automatically.

#### Read the Paper

I've published a full academic paper with formal threat model, TikZ architecture diagrams, latency benchmarks, and comparison tables. It's in the repo under `paper/`.

**GitHub:** [github.com/GabrieleRisso/qubes-claw](https://github.com/GabrieleRisso/qubes-claw)
