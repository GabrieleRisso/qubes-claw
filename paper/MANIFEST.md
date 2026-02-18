# qubes-claw Publication Assets

## Build Requirements

| Dependency | Package (Fedora) | Purpose |
|------------|-----------------|---------|
| `pdflatex` | `texlive-latex` | Compile LaTeX paper |
| `python3` | `python3` | Run diagram/post generators |
| `Pillow` | `python3-pillow` | Image generation library |
| TikZ packages | `texlive-pgf`, `texlive-tikz` | LaTeX diagrams |
| `amssymb` | `texlive-amsfonts` | Math symbols |

## Build

```bash
cd paper/
make all      # Build everything and sync to ~/Documents
make paper    # Just recompile the PDF
make diagrams # Just regenerate diagram PNGs
make posts    # Just regenerate social media cards
make sync     # Copy outputs to ~/Documents/qubes-claw/
```

## Generated Files

### Paper (`paper/`)

| File | Type | Description |
|------|------|-------------|
| `qubes-claw.tex` | LaTeX source | Main paper (TikZ diagrams embedded) |
| `qubes-claw.pdf` | PDF | Compiled paper (~7 pages, 50+ references) |
| `posts.md` | Markdown | Social media content: X threads, LinkedIn, Dev.to, HN, Reddit |
| `blog-qubes-claw.md` | Markdown | Website-ready blog post with frontmatter |
| `Makefile` | Make | Build automation for all assets |

### Diagrams (`demo/`)

| File | Dimensions | Description | Use |
|------|-----------|-------------|-----|
| `architecture.png` | 1200x675 | System architecture (dom0 + VM + qrexec) | README, LinkedIn header |
| `persistence.png` | 1200x675 | Reboot persistence chain | Blog detail |
| `security.png` | 1200x675 | Four security layers | X post, r/netsec |

### Social Media Cards (`~/Documents/qubes-claw/posts/`)

| File | Dimensions | Description | Platform |
|------|-----------|-------------|----------|
| `post-1.png` | 1200x675 | Architecture overview | X post 1/3 |
| `post-2.png` | 1200x675 | Dashboard composite | X post 2/3 |
| `post-3.png` | 1200x675 | Terminal health checks | X post 3/3 |

### Content Formats in `posts.md`

| Format | Audience | Length |
|--------|----------|--------|
| X/Twitter thread (3 posts) | General tech | ~280 chars each |
| LinkedIn article | Professional network | ~800 words |
| Blog post | Website visitors | ~1200 words |
| Dev.to / Medium article | Developer community | ~600 words |
| Hacker News submission | HN community | Title + comment |
| Reddit posts (3 subreddits) | r/QubesOS, r/LocalLLaMA, r/netsec | ~200 words each |

## Synced Output (`~/Documents/qubes-claw/`)

```
~/Documents/qubes-claw/
├── qubes-claw.pdf          # Paper
├── qubes-claw.tex          # Source
├── posts.md                # Social media content
├── blog-qubes-claw.md      # Blog post
├── diagrams/
│   ├── architecture.png
│   ├── persistence.png
│   └── security.png
└── posts/
    ├── post-1.png
    ├── post-2.png
    └── post-3.png
```

## Citation

```bibtex
@misc{risso2026qubesclaw,
  author = {Risso, Gabriele},
  title  = {qubes-claw: Secure, Isolated AI Agent Infrastructure on Qubes OS},
  year   = {2026},
  url    = {https://github.com/GabrieleRisso/qubes-claw}
}
```
