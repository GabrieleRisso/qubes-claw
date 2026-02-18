# qubes-claw Demo Toolkit

Screen capture, architecture diagrams, and X/Twitter post generator for qubes-claw.

## Install (dom0)

```bash
# Copy the toolkit to dom0
sudo install -m 0755 qubes-claw-demo /usr/local/bin/
sudo install -m 0755 generate-diagrams.py /usr/local/bin/
sudo install -m 0755 generate-posts.py /usr/local/bin/
```

Or run directly from the repo checkout.

## Usage

Run from a **dom0 terminal** (needs DISPLAY access):

```bash
# Screenshots
qubes-claw-demo screenshot            # full screen
qubes-claw-demo window "Firefox" fw   # specific window

# Screen recording (30s default, Ctrl+C to stop)
qubes-claw-demo record 60

# Architecture diagrams (no DISPLAY needed)
qubes-claw-demo diagrams

# Full demo capture (interactive)
qubes-claw-demo demo

# Generate X/Twitter post images
qubes-claw-demo post all     # all 3 posts
qubes-claw-demo post 1       # just post 1
```

## Output

All files go to `~/qubes-claw-demo/`:

```
~/qubes-claw-demo/
├── screenshots/    .png screenshots
├── recordings/     .mp4 screen recordings
├── diagrams/       architecture/persistence/security .png
└── posts/          post-1.png, post-2.png, post-3.png
```

## Post content

| Post | Content | Caption suggestion |
|------|---------|-------------------|
| 1 | Architecture diagram | "Running AI agents on @QubesOS with VM isolation and airgapped admin. Multi-provider: Cursor, OpenAI, Anthropic, Ollama. Open source." |
| 2 | Side-by-side dashboards | "All green from airgapped dom0. Admin web + OpenClaw gateway, tunneled through Xen qrexec. No network exposure." |
| 3 | Terminal health checks | "Zero-trust AI infrastructure. Health checks from dom0 use Xen shared memory, not TCP/IP. Every component survives reboot." |

## Requirements

- dom0 with `scrot`, `ffmpeg`, `python3-pillow`, `xdotool`
- Fonts: Fira Code, Red Hat Display (both standard in Fedora)
