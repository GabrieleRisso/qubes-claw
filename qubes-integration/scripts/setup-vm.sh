#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-vm.sh — Install OpenClaw inside a Qubes VM
#
# Supports multiple providers:
#   cursor   — Uses openclaw-cursor proxy (requires Cursor Pro subscription)
#   openai   — Direct OpenAI API (requires OPENAI_API_KEY)
#   anthropic— Direct Anthropic API (requires ANTHROPIC_API_KEY)
#   ollama   — Local models via Ollama (free, runs on same VM or LAN)
#
# Run inside the target VM (not dom0).
# ---------------------------------------------------------------------------

PROVIDER="${1:-cursor}"

echo "=== OpenClaw VM Setup (provider: $PROVIDER) ==="
echo ""

if [ ! -f /usr/share/qubes/marker-vm ]; then
    echo "WARNING: This doesn't look like a Qubes VM. Continuing anyway..."
fi

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# --- 1. Install socat (needed for qrexec tunnels) ---
if ! command -v socat &>/dev/null; then
    echo "[1/6] Installing socat..."
    sudo dnf install -y socat 2>/dev/null || sudo pacman -S --noconfirm socat 2>/dev/null || sudo apt-get install -y socat 2>/dev/null || true
else
    echo "[1/6] socat already installed"
fi

# --- 2. Install ConnectTCP handler ---
echo "[2/6] Installing ConnectTCP qrexec handler"
cat <<'HANDLER' | sudo tee /etc/qubes-rpc/qubes.ConnectTCP >/dev/null
#!/bin/sh
exec socat - "TCP:127.0.0.1:${QREXEC_SERVICE_ARGUMENT}"
HANDLER
sudo chmod +x /etc/qubes-rpc/qubes.ConnectTCP

# --- 3. Install OpenClaw ---
if ! command -v openclaw &>/dev/null; then
    echo "[3/6] Installing OpenClaw..."
    curl -fsSL https://openclaw.ai/install.sh | bash 2>&1 || true
    echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
else
    echo "[3/6] OpenClaw already installed ($(openclaw --version 2>/dev/null || echo 'unknown'))"
fi

# --- 4. Provider-specific setup ---
echo "[4/6] Setting up provider: $PROVIDER"
case "$PROVIDER" in
    cursor)
        if ! command -v cursor-agent &>/dev/null && ! command -v agent &>/dev/null; then
            echo "  Installing cursor-agent..."
            curl -fsSL https://cursor.com/install | bash
        fi

        if ! command -v go &>/dev/null; then
            echo "  Installing Go..."
            sudo dnf install -y golang 2>/dev/null || sudo pacman -S --noconfirm go 2>/dev/null || sudo apt-get install -y golang 2>/dev/null || {
                echo "ERROR: Cannot install Go. Install manually: https://go.dev/dl/"
                exit 1
            }
        fi

        REPO_DIR="$HOME/openclaw-cursor"
        if [ ! -d "$REPO_DIR" ]; then
            echo "  Cloning and building openclaw-cursor proxy..."
            git clone https://github.com/GabrieleRisso/openclaw-cursor.git "$REPO_DIR"
        fi
        cd "$REPO_DIR"
        make build
        make install-local
        ;;
    openai)
        if [ -z "${OPENAI_API_KEY:-}" ]; then
            echo "  Set OPENAI_API_KEY before running: export OPENAI_API_KEY=sk-..."
        fi
        ;;
    anthropic)
        if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
            echo "  Set ANTHROPIC_API_KEY before running: export ANTHROPIC_API_KEY=sk-ant-..."
        fi
        ;;
    ollama)
        if ! command -v ollama &>/dev/null; then
            echo "  Installing Ollama..."
            curl -fsSL https://ollama.ai/install.sh | bash
        fi
        echo "  Pull a model: ollama pull llama3.3:70b"
        ;;
    *)
        echo "  Unknown provider '$PROVIDER'. Using generic config."
        ;;
esac

# --- 5. Generate configs ---
echo "[5/6] Generating configs..."
mkdir -p ~/.openclaw/logs ~/.openclaw/agents/main/agent ~/.openclaw/skills

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
EXAMPLE_DIR=""
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/../examples" ]; then
    EXAMPLE_DIR="$SCRIPT_DIR/../examples"
fi

if [ ! -f ~/.openclaw/openclaw.json ]; then
    case "$PROVIDER" in
        cursor)    EXAMPLE_FILE="openclaw-cursor.json" ;;
        openai)    EXAMPLE_FILE="openclaw-openai.json" ;;
        anthropic) EXAMPLE_FILE="openclaw-anthropic.json" ;;
        ollama)    EXAMPLE_FILE="openclaw-ollama.json" ;;
        *)         EXAMPLE_FILE="openclaw-cursor.json" ;;
    esac

    if [ -n "$EXAMPLE_DIR" ] && [ -f "$EXAMPLE_DIR/$EXAMPLE_FILE" ]; then
        cp "$EXAMPLE_DIR/$EXAMPLE_FILE" ~/.openclaw/openclaw.json
        echo "  Config from example: $EXAMPLE_FILE"
    else
        cat > ~/.openclaw/openclaw.json <<'FALLBACK'
{
  "gateway": { "mode": "local", "port": 18789, "bind": "loopback" },
  "models": { "mode": "merge", "providers": {} },
  "agents": { "defaults": { "model": {} } }
}
FALLBACK
        echo "  Created minimal config — edit ~/.openclaw/openclaw.json to add your provider"
    fi
fi

if [ "$PROVIDER" = "cursor" ] && [ ! -f ~/.openclaw/cursor-proxy.json ]; then
    cat > ~/.openclaw/cursor-proxy.json <<'EOF'
{
  "port": 32125,
  "log_level": "info",
  "tool_mode": "openclaw",
  "timeout_ms": 300000,
  "default_model": "auto",
  "enable_thinking": true
}
EOF
fi

# --- 6. Install systemd user services ---
echo "[6/6] Installing systemd user services"
mkdir -p ~/.config/systemd/user

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/../systemd" ]; then
    if [ "$PROVIDER" = "cursor" ]; then
        cp "$SCRIPT_DIR/../systemd/openclaw-cursor-proxy.service" ~/.config/systemd/user/
    fi
    cp "$SCRIPT_DIR/../systemd/openclaw-gateway.service" ~/.config/systemd/user/
else
    cat > ~/.config/systemd/user/openclaw-gateway.service <<'GWEOF'
[Unit]
Description=OpenClaw Gateway (WebSocket + Dashboard)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/bin/sh -c "fuser -k 18789/tcp 2>/dev/null || true"
ExecStart=%h/.npm-global/bin/openclaw gateway --bind loopback
Restart=on-failure
RestartSec=5
Environment=PATH=%h/.local/bin:%h/.npm-global/bin:/usr/local/bin:/usr/bin
Environment=HOME=%h
Environment=NODE_NO_WARNINGS=1
WorkingDirectory=%h

[Install]
WantedBy=default.target
GWEOF
fi

loginctl enable-linger "$(whoami)" 2>/dev/null || true
systemctl --user daemon-reload

if [ "$PROVIDER" = "cursor" ]; then
    systemctl --user enable openclaw-cursor-proxy.service 2>/dev/null || true
fi
systemctl --user enable openclaw-gateway.service

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
case "$PROVIDER" in
    cursor)
        echo "  1. Log in:           openclaw-cursor login"
        echo "  2. Start proxy:      systemctl --user start openclaw-cursor-proxy"
        echo "  3. Start gateway:    systemctl --user start openclaw-gateway"
        echo "  4. Dashboard:        http://127.0.0.1:18789"
        ;;
    openai|anthropic)
        echo "  1. Set API key in:   ~/.openclaw/openclaw.json"
        echo "  2. Start gateway:    systemctl --user start openclaw-gateway"
        echo "  3. Dashboard:        http://127.0.0.1:18789"
        ;;
    ollama)
        echo "  1. Pull a model:     ollama pull llama3.3:70b"
        echo "  2. Start gateway:    systemctl --user start openclaw-gateway"
        echo "  3. Dashboard:        http://127.0.0.1:18789"
        ;;
esac
echo ""
echo "From dom0 (if using tunnel mode):"
echo "  curl http://127.0.0.1:32125/health"
echo "  firefox http://127.0.0.1:18789#token=dom0-local"
