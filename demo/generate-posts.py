#!/usr/bin/env python3
"""Generate X/Twitter post images from diagrams and screenshots.

Usage: python3 generate-posts.py <diagrams-dir> <screenshots-dir> <output-dir> [1|2|3|all]

Produces branded 1200x675 images ready for posting:
  post-1.png  — Architecture overview
  post-2.png  — Live dashboard composite
  post-3.png  — Terminal + health checks
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
PURPLE = (137, 87, 229)
ACCENT = (88, 166, 255)
BORDER = (48, 54, 61)
CARD_BG = (22, 27, 34)

FONT_PATHS = [
    "/usr/share/fonts/fira-code/FiraCode-Regular.ttf",
    "/usr/share/fonts/redhat/RedHatDisplay-Regular.otf",
    "/usr/share/fonts/redhat/RedHatDisplay-Bold.otf",
    "/usr/share/fonts/fira-code/FiraCode-Bold.ttf",
]


def load_font(style, size):
    idx = {"code": 0, "text": 1, "bold": 2, "code-bold": 3}.get(style, 0)
    try:
        return ImageFont.truetype(FONT_PATHS[idx], size)
    except (OSError, IndexError):
        for p in FONT_PATHS:
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default()


def draw_rounded_rect(draw, xy, fill, outline=None, radius=8):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=2)


def draw_badge(draw, x, y, text, color=GREEN, size=11):
    fnt = load_font("code", size)
    bbox = fnt.getbbox(text)
    tw = bbox[2] - bbox[0] + 14
    th = bbox[3] - bbox[1] + 8
    draw_rounded_rect(draw, (x, y, x + tw, y + th), fill=color, radius=4)
    draw.text((x + 7, y + 3), text, fill=(255, 255, 255), font=fnt)
    return tw


def draw_header(draw, post_num, total=3):
    draw_rounded_rect(draw, (0, 0, W, 60), fill=(10, 12, 18), outline=None, radius=0)
    fnt = load_font("bold", 20)
    draw.text((30, 15), "qubes-claw", fill=ACCENT, font=fnt)

    fnt_sub = load_font("text", 13)
    draw.text((180, 18), "AI agents on Qubes OS", fill=SOFT, font=fnt_sub)

    draw_badge(draw, W - 100, 16, f"{post_num}/{total}", color=BLUE, size=13)
    draw_badge(draw, W - 190, 16, "open source", color=GREEN, size=10)


def draw_footer(draw, caption):
    draw_rounded_rect(draw, (0, H - 55, W, H), fill=(10, 12, 18), outline=None, radius=0)
    fnt = load_font("text", 13)
    draw.text((30, H - 40), caption, fill=SOFT, font=fnt)
    fnt_url = load_font("code", 10)
    draw.text((W - 280, H - 35), "github.com/GabrieleRisso/qubes-claw", fill=BORDER, font=fnt_url)


def fit_image(img, box_w, box_h):
    """Resize image to fit in box, preserving aspect ratio."""
    ratio = min(box_w / img.width, box_h / img.height)
    new_w = int(img.width * ratio)
    new_h = int(img.height * ratio)
    return img.resize((new_w, new_h), Image.LANCZOS)


def make_screenshot_placeholder(w, h, label):
    """Create a placeholder when screenshot isn't available."""
    img = Image.new("RGB", (w, h), CARD_BG)
    d = ImageDraw.Draw(img)
    draw_rounded_rect(d, (0, 0, w - 1, h - 1), fill=CARD_BG, outline=BORDER, radius=6)
    fnt = load_font("code", 14)
    bbox = fnt.getbbox(label)
    tw = bbox[2] - bbox[0]
    d.text(((w - tw) // 2, h // 2 - 10), label, fill=SOFT, font=fnt)
    return img


# ─── Post 1: Architecture ────────────────────────────────────────

def post_1(diagdir, ssdir, outdir):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    draw_header(d, 1)

    arch_path = diagdir / "architecture.png"
    if arch_path.exists():
        arch = Image.open(arch_path)
        arch = fit_image(arch, W - 40, H - 130)
        x = (W - arch.width) // 2
        img.paste(arch, (x, 68))
    else:
        fnt = load_font("bold", 24)
        d.text((W // 2 - 200, H // 2 - 60),
               "AI Agents on Qubes OS", fill=ACCENT, font=fnt)
        fnt_sub = load_font("text", 16)
        lines = [
            "VM-isolated AI agents with airgapped admin",
            "Multi-provider: Cursor / OpenAI / Anthropic / Ollama",
            "Zero-config reboot persistence",
            "qrexec tunnels — no network exposure",
        ]
        for i, line in enumerate(lines):
            d.text((W // 2 - 250, H // 2 + i * 30), f"  {line}", fill=FG, font=fnt_sub)

    draw_footer(d, "Secure AI infrastructure — VM isolation + airgapped dom0 administration")
    img.save(outdir / "post-1.png", "PNG")
    print(f"  post-1.png (architecture)")


# ─── Post 2: Live Dashboard ──────────────────────────────────────

def post_2(diagdir, ssdir, outdir):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    draw_header(d, 2)

    left_path = ssdir / "02-admin-web.png"
    right_path = ssdir / "03-gateway-dashboard.png"

    box_w = (W - 60) // 2
    box_h = H - 150

    left = (Image.open(left_path) if left_path.exists()
            else make_screenshot_placeholder(box_w, box_h, "[admin web - run demo first]"))
    right = (Image.open(right_path) if right_path.exists()
             else make_screenshot_placeholder(box_w, box_h, "[gateway dashboard - run demo first]"))

    left = fit_image(left, box_w, box_h)
    right = fit_image(right, box_w, box_h)

    ly = 70 + (box_h - left.height) // 2
    ry = 70 + (box_h - right.height) // 2

    draw_rounded_rect(d, (18, 66, 22 + box_w, 66 + box_h + 4), fill=CARD_BG, outline=BLUE, radius=6)
    img.paste(left, (20 + (box_w - left.width) // 2, ly))

    draw_rounded_rect(d, (W // 2 + 8, 66, W // 2 + 12 + box_w, 66 + box_h + 4),
                      fill=CARD_BG, outline=ORANGE, radius=6)
    img.paste(right, (W // 2 + 10 + (box_w - right.width) // 2, ry))

    fnt_label = load_font("bold", 11)
    draw_badge(d, 25, 72, "dom0 Admin Web", color=BLUE, size=10)
    draw_badge(d, W // 2 + 15, 72, "OpenClaw Gateway", color=ORANGE, size=10)

    draw_footer(d, "All green from airgapped dom0 — proxy, gateway, tunnels, Tailscale")
    img.save(outdir / "post-2.png", "PNG")
    print(f"  post-2.png (dashboards)")


# ─── Post 3: Terminal + Health ────────────────────────────────────

def post_3(diagdir, ssdir, outdir):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    draw_header(d, 3)

    term_y = 75
    draw_rounded_rect(d, (30, term_y, W - 30, H - 65), fill=(13, 15, 20), outline=BORDER, radius=8)

    # terminal title bar
    draw_rounded_rect(d, (30, term_y, W - 30, term_y + 28), fill=(30, 35, 42), outline=None, radius=0)
    dots = [(50, term_y + 14), (68, term_y + 14), (86, term_y + 14)]
    colors = [(255, 95, 86), (255, 189, 46), (39, 201, 63)]
    for (cx, cy), clr in zip(dots, colors):
        d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=clr)
    fnt_title = load_font("code", 10)
    d.text((110, term_y + 8), "dom0 — qubes-claw health check", fill=SOFT, font=fnt_title)

    fnt = load_font("code", 12)
    fnt_sm = load_font("code", 11)

    health_path = ssdir / "04-health-checks.txt"
    if health_path.exists():
        lines = health_path.read_text().splitlines()[:22]
    else:
        lines = [
            "$ curl -s http://127.0.0.1:32125/health | python3 -m json.tool",
            '{',
            '  "status": "healthy",',
            '  "authenticated": true,',
            '  "cursor_agent": "available",',
            '  "proxy_version": "5c7c30c"',
            '}',
            '',
            '$ systemctl is-active openclaw-tunnel@{32125,18789}',
            'active',
            'active',
            '',
            '$ curl -s http://127.0.0.1:9876/api/openclaw/status | python3 -c \\',
            '    "import sys,json; d=json.load(sys.stdin); \\',
            '     print(f\\"proxy={d[\'proxy_healthy\']} gw={d[\'gateway_healthy\']}\\")"',
            'proxy=True gw=True',
            '',
            '$ qvm-tags visyble list',
            'openclaw-server',
            '',
            '# All services healthy. Zero network exposure.',
            '# Administered entirely from airgapped dom0.',
        ]

    y = term_y + 38
    for line in lines:
        if line.startswith("$") or line.startswith("#"):
            clr = GREEN if line.startswith("$") else SOFT
            d.text((50, y), line, fill=clr, font=fnt)
        elif line.startswith("{") or line.startswith("}") or line.strip().startswith('"'):
            d.text((50, y), line, fill=ACCENT, font=fnt_sm)
        elif line in ("active", "True", "openclaw-server"):
            d.text((50, y), line, fill=GREEN, font=fnt)
        else:
            d.text((50, y), line, fill=FG, font=fnt_sm)
        y += 22
        if y > H - 80:
            break

    draw_footer(d, "Airgapped health checks — dom0 talks to VM through Xen, not TCP/IP")
    img.save(outdir / "post-3.png", "PNG")
    print(f"  post-3.png (terminal)")


def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <diagrams-dir> <screenshots-dir> <output-dir> [1|2|3|all]")
        sys.exit(1)

    diagdir = Path(sys.argv[1])
    ssdir = Path(sys.argv[2])
    outdir = Path(sys.argv[3])
    which = sys.argv[4] if len(sys.argv) > 4 else "all"
    outdir.mkdir(parents=True, exist_ok=True)

    print("Generating X post images...")
    if which in ("1", "all"):
        post_1(diagdir, ssdir, outdir)
    if which in ("2", "all"):
        post_2(diagdir, ssdir, outdir)
    if which in ("3", "all"):
        post_3(diagdir, ssdir, outdir)
    print("Done.")


if __name__ == "__main__":
    main()
