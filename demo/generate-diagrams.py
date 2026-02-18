#!/usr/bin/env python3
"""Generate architecture diagrams for qubes-claw using Pillow.

Usage: python3 generate-diagrams.py <output-dir>

Produces three diagrams optimized for X/Twitter (1200x675, dark theme):
  1. architecture.png  — Full system architecture
  2. persistence.png   — Reboot survival chain
  3. security.png      — Isolation and security model
"""

import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1200, 675
BG = (15, 17, 23)
FG = (230, 237, 243)
SOFT = (139, 148, 158)
BLUE = (56, 132, 244)
GREEN = (63, 185, 80)
ORANGE = (227, 139, 40)
RED = (218, 54, 51)
PURPLE = (137, 87, 229)
BORDER = (48, 54, 61)
CARD_BG = (22, 27, 34)
ACCENT = (88, 166, 255)

FONT_PATHS = [
    "/usr/share/fonts/fira-code/FiraCode-Regular.ttf",
    "/usr/share/fonts/redhat/RedHatDisplay-Regular.otf",
    "/usr/share/fonts/redhat/RedHatDisplay-Bold.otf",
    "/usr/share/fonts/fira-code/FiraCode-Bold.ttf",
    "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf",
]


def load_font(style, size):
    idx = {"code": 0, "text": 1, "bold": 2, "code-bold": 3, "mono": 4}.get(style, 0)
    try:
        return ImageFont.truetype(FONT_PATHS[idx], size)
    except (OSError, IndexError):
        for p in FONT_PATHS:
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default()


def new_canvas():
    img = Image.new("RGB", (W, H), BG)
    return img, ImageDraw.Draw(img)


def draw_rounded_rect(draw, xy, fill, outline=None, radius=8):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=2)


def draw_box(draw, x, y, w, h, label, sublabel=None, color=BLUE, filled=False):
    fill = (*color, 30) if not filled else color
    bg = CARD_BG
    draw_rounded_rect(draw, (x, y, x + w, y + h), fill=bg, outline=color, radius=6)
    draw.line([(x, y + 1), (x + w, y + 1)], fill=color, width=3)

    fnt = load_font("bold", 14)
    draw.text((x + 12, y + 10), label, fill=FG, font=fnt)
    if sublabel:
        sfnt = load_font("code", 11)
        draw.text((x + 12, y + 30), sublabel, fill=SOFT, font=sfnt)


def draw_arrow(draw, x1, y1, x2, y2, color=SOFT, label=None, dashed=False):
    draw.line([(x1, y1), (x2, y2)], fill=color, width=2)
    dx = x2 - x1
    dy = y2 - y1
    length = (dx ** 2 + dy ** 2) ** 0.5
    if length > 0:
        ux, uy = dx / length, dy / length
        sz = 8
        px, py = x2 - ux * sz, y2 - uy * sz
        lx, ly = -uy * sz * 0.5, ux * sz * 0.5
        draw.polygon([(x2, y2), (int(px + lx), int(py + ly)),
                       (int(px - lx), int(py - ly))], fill=color)
    if label:
        mx, my = (x1 + x2) // 2, (y1 + y2) // 2
        fnt = load_font("code", 10)
        draw.text((mx + 4, my - 12), label, fill=SOFT, font=fnt)


def draw_title(draw, title, subtitle=None):
    fnt = load_font("bold", 22)
    draw.text((40, 24), title, fill=FG, font=fnt)
    if subtitle:
        sfnt = load_font("text", 13)
        draw.text((40, 54), subtitle, fill=SOFT, font=sfnt)
    draw.line([(40, 76), (W - 40, 76)], fill=BORDER, width=1)


def draw_badge(draw, x, y, text, color=GREEN):
    fnt = load_font("code", 10)
    bbox = fnt.getbbox(text)
    tw = bbox[2] - bbox[0] + 12
    th = bbox[3] - bbox[1] + 6
    draw_rounded_rect(draw, (x, y, x + tw, y + th), fill=color, radius=3)
    draw.text((x + 6, y + 2), text, fill=(255, 255, 255), font=fnt)
    return tw


def draw_watermark(draw):
    fnt = load_font("code", 10)
    draw.text((W - 200, H - 22), "github.com/GabrieleRisso/qubes-claw", fill=BORDER, font=fnt)


# ─── Diagram 1: Architecture ─────────────────────────────────────

def diagram_architecture(outdir):
    img, d = new_canvas()
    draw_title(d, "qubes-claw Architecture",
               "AI agents isolated in Qubes OS VM, administered from airgapped dom0")

    # dom0 box
    draw_rounded_rect(d, (40, 95, 560, 310), fill=CARD_BG, outline=BLUE, radius=8)
    fnt_h = load_font("bold", 15)
    d.text((55, 102), "dom0 (airgapped)", fill=BLUE, font=fnt_h)

    fnt_c = load_font("code", 12)
    items = [
        (":9876", "Admin Web UI", GREEN),
        (":32125", "Proxy tunnel", ACCENT),
        (":18789", "Gateway tunnel", ACCENT),
    ]
    for i, (port, desc, clr) in enumerate(items):
        y = 135 + i * 40
        d.text((70, y), f"localhost{port}", fill=clr, font=fnt_c)
        fnt_s = load_font("text", 11)
        d.text((250, y + 1), desc, fill=SOFT, font=fnt_s)

    # tunnel pipes
    fnt_s = load_font("code", 10)
    d.text((70, 268), "socat  ->  qrexec-client  ->  Xen shared memory", fill=SOFT, font=fnt_s)
    draw_badge(d, 430, 265, "no TCP/IP", color=GREEN)

    # qrexec arrow
    draw_arrow(d, 560, 200, 640, 200, color=ACCENT, label="qrexec")

    # VM box
    draw_rounded_rect(d, (640, 95, 1160, 420), fill=CARD_BG, outline=ORANGE, radius=8)
    d.text((655, 102), "openclaw-vm (StandaloneVM)", fill=ORANGE, font=fnt_h)

    svc_items = [
        ("openclaw-cursor proxy", ":32125", "OpenAI-compatible API"),
        ("openclaw gateway", ":18789", "Dashboard + WebSocket"),
        ("qubes.ConnectTCP", "", "qrexec TCP handler"),
    ]
    for i, (name, port, desc) in enumerate(svc_items):
        y = 135 + i * 45
        d.text((665, y), name, fill=FG, font=fnt_c)
        if port:
            draw_badge(d, 900, y, port, color=ORANGE)
        fnt_s = load_font("text", 10)
        d.text((665, y + 18), desc, fill=SOFT, font=fnt_s)

    # providers
    d.text((655, 285), "Providers:", fill=SOFT, font=load_font("bold", 12))
    providers = [
        ("Cursor Pro", BLUE), ("OpenAI", GREEN),
        ("Anthropic", ORANGE), ("Ollama", PURPLE),
    ]
    px = 665
    for name, clr in providers:
        bw = draw_badge(d, px, 308, name, color=clr)
        px += bw + 8

    # optional services
    d.text((655, 345), "Optional:", fill=SOFT, font=load_font("bold", 12))
    opts = [("Tailscale", PURPLE), ("WhatsApp", GREEN), ("Docker", BLUE)]
    px = 665
    for name, clr in opts:
        bw = draw_badge(d, px, 368, name, color=clr)
        px += bw + 8

    # bottom: reboot info
    draw_rounded_rect(d, (40, 440, 1160, 540), fill=CARD_BG, outline=GREEN, radius=8)
    d.text((55, 450), "Survives reboot", fill=GREEN, font=fnt_h)
    boot_items = [
        "VM autostart", "systemd user + linger", "dom0 tunnel services",
        "qrexec policies", "ConnectTCP handler",
    ]
    bx = 55
    for item in boot_items:
        bw = draw_badge(d, bx, 478, item, color=GREEN)
        bx += bw + 10

    # footer
    draw_rounded_rect(d, (40, 560, 1160, 640), fill=(20, 22, 28), outline=BORDER, radius=8)
    fnt_tag = load_font("bold", 18)
    d.text((60, 575), "qubes-claw", fill=ACCENT, font=fnt_tag)
    fnt_desc = load_font("text", 13)
    d.text((60, 600), "Run AI agents on Qubes OS with VM isolation and airgapped admin", fill=SOFT, font=fnt_desc)
    draw_badge(d, 900, 580, "open source", color=GREEN)
    draw_badge(d, 1000, 580, "multi-provider", color=PURPLE)

    draw_watermark(d)
    img.save(outdir / "architecture.png", "PNG")
    print(f"  architecture.png ({W}x{H})")


# ─── Diagram 2: Persistence ──────────────────────────────────────

def diagram_persistence(outdir):
    img, d = new_canvas()
    draw_title(d, "Reboot Persistence Chain",
               "Every component auto-starts — zero manual intervention after setup")

    cols = [
        ("dom0", BLUE, [
            ("VM autostart", "qvm-prefs autostart True"),
            ("Tunnel 32125", "openclaw-tunnel@32125.service"),
            ("Tunnel 18789", "openclaw-tunnel@18789.service"),
            ("Admin web", "qubes-global-admin-web.service"),
            ("qvm-remote", "qvm-remote-dom0.service"),
            ("Policies", "/etc/qubes/policy.d/"),
        ]),
        ("openclaw-vm", ORANGE, [
            ("Cursor proxy", "openclaw-cursor-proxy.service"),
            ("Gateway", "openclaw-gateway.service"),
            ("ConnectTCP", "/etc/qubes-rpc/qubes.ConnectTCP"),
            ("User linger", "loginctl enable-linger"),
            ("Config", "~/.openclaw/openclaw.json"),
        ]),
    ]

    fnt_h = load_font("bold", 15)
    fnt_c = load_font("code", 11)
    fnt_s = load_font("text", 11)

    for ci, (title, color, items) in enumerate(cols):
        bx = 50 + ci * 580
        draw_rounded_rect(d, (bx, 95, bx + 540, 560), fill=CARD_BG, outline=color, radius=8)
        d.text((bx + 15, 105), title, fill=color, font=fnt_h)

        for i, (label, detail) in enumerate(items):
            y = 140 + i * 65
            draw_rounded_rect(d, (bx + 15, y, bx + 525, y + 50),
                              fill=(30, 35, 42), outline=BORDER, radius=4)
            draw_badge(d, bx + 25, y + 8, "enabled", color=GREEN)
            d.text((bx + 110, y + 8), label, fill=FG, font=load_font("bold", 12))
            d.text((bx + 25, y + 28), detail, fill=SOFT, font=fnt_c)

    # boot sequence arrow at bottom
    draw_rounded_rect(d, (50, 575, 1150, 640), fill=(20, 22, 28), outline=BORDER, radius=8)
    fnt_flow = load_font("bold", 12)
    d.text((70, 585), "Boot sequence:", fill=ACCENT, font=fnt_flow)
    steps = ["Xen", "dom0", "qubesd", "VM start", "systemd user", "Services ready"]
    sx = 70
    for i, step in enumerate(steps):
        bw = draw_badge(d, sx, 608, step, color=BLUE if i < 3 else ORANGE)
        sx += bw + 6
        if i < len(steps) - 1:
            d.text((sx - 2, 608), "->", fill=SOFT, font=fnt_c)
            sx += 20

    draw_watermark(d)
    img.save(outdir / "persistence.png", "PNG")
    print(f"  persistence.png ({W}x{H})")


# ─── Diagram 3: Security ─────────────────────────────────────────

def diagram_security(outdir):
    img, d = new_canvas()
    draw_title(d, "Security Model",
               "Defense-in-depth: Xen isolation + qrexec policies + token auth + airgap")

    fnt_h = load_font("bold", 14)
    fnt_c = load_font("code", 11)
    fnt_s = load_font("text", 11)

    layers = [
        ("Xen Hypervisor", "Hardware-enforced VM isolation", RED, 90, 80),
        ("Qrexec Policies", "Tag-based access: only openclaw-client -> openclaw-server", ORANGE, 185, 80),
        ("Port Restrictions", "ConnectTCP allows only 32125 and 18789", BLUE, 280, 80),
        ("Token Auth", "Gateway WebSocket requires auth token", PURPLE, 375, 80),
    ]

    for label, desc, color, y, indent in layers:
        x = 50 + indent
        w = W - 100 - indent * 2
        draw_rounded_rect(d, (x, y, x + w, y + 70), fill=CARD_BG, outline=color, radius=6)
        d.line([(x, y + 1), (x + w, y + 1)], fill=color, width=3)
        d.text((x + 15, y + 12), label, fill=color, font=fnt_h)
        d.text((x + 15, y + 35), desc, fill=SOFT, font=fnt_s)

        num = str(layers.index((label, desc, color, y, indent)) + 1)
        draw_badge(d, x + w - 45, y + 12, f"Layer {num}", color=color)

    # airgap callout
    draw_rounded_rect(d, (50, 470, 570, 560), fill=CARD_BG, outline=GREEN, radius=6)
    d.text((65, 480), "Airgapped Admin (dom0)", fill=GREEN, font=fnt_h)
    d.text((65, 505), "dom0 has no network stack.", fill=SOFT, font=fnt_s)
    d.text((65, 523), "Tunnels use Xen shared memory (qrexec),", fill=SOFT, font=fnt_s)
    d.text((65, 541), "not TCP/IP. Zero attack surface.", fill=SOFT, font=fnt_s)

    # secrets callout
    draw_rounded_rect(d, (600, 470, 1150, 560), fill=CARD_BG, outline=RED, radius=6)
    d.text((615, 480), "Secrets Stay in VM", fill=RED, font=fnt_h)
    d.text((615, 505), "API keys live in ~/.openclaw/openclaw.json", fill=SOFT, font=fnt_s)
    d.text((615, 523), "inside the VM. Never in dom0, never in git.", fill=SOFT, font=fnt_s)
    d.text((615, 541), "Example configs use ${PLACEHOLDER} syntax.", fill=SOFT, font=fnt_s)

    # footer
    draw_rounded_rect(d, (50, 580, 1150, 645), fill=(20, 22, 28), outline=BORDER, radius=8)
    fnt_tag = load_font("bold", 18)
    d.text((70, 592), "qubes-claw", fill=ACCENT, font=fnt_tag)
    fnt_desc = load_font("text", 13)
    d.text((70, 617), "Security-first AI infrastructure on Qubes OS", fill=SOFT, font=fnt_desc)
    draw_badge(d, 950, 595, "airgapped", color=GREEN)
    draw_badge(d, 1040, 595, "open source", color=BLUE)

    draw_watermark(d)
    img.save(outdir / "security.png", "PNG")
    print(f"  security.png ({W}x{H})")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <output-dir>")
        sys.exit(1)

    outdir = Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)

    print("Generating diagrams...")
    diagram_architecture(outdir)
    diagram_persistence(outdir)
    diagram_security(outdir)
    print("Done.")


if __name__ == "__main__":
    main()
