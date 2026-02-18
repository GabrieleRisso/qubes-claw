#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-vm.sh — Install OpenClaw + cursor proxy inside a Qubes AppVM
# Run inside the target VM (not dom0)
# ---------------------------------------------------------------------------

echo "=== OpenClaw + Cursor Proxy — Qubes VM Setup ==="
echo ""

# Check we're in a Qubes VM
if [ ! -f /usr/share/qubes/marker-vm ]; then
    echo "WARNING: This doesn't look like a Qubes VM. Continuing anyway..."
fi

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# 1. Install cursor-agent
if ! command -v cursor-agent &>/dev/null && ! command -v agent &>/dev/null; then
    echo "[1/5] Installing cursor-agent..."
    curl -fsSL https://cursor.com/install | bash
else
    echo "[1/5] cursor-agent already installed"
fi

# 2. Install OpenClaw
if ! command -v openclaw &>/dev/null; then
    echo "[2/5] Installing OpenClaw..."
    curl -fsSL https://openclaw.ai/install.sh | bash 2>&1 || true
    echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
    echo "[2/5] OpenClaw already installed ($(openclaw --version))"
fi

# 3. Check for Go
if ! command -v go &>/dev/null; then
    echo "[3/5] Go not found. Installing..."
    sudo dnf install -y golang 2>/dev/null || sudo apt-get install -y golang 2>/dev/null || {
        echo "ERROR: Cannot install Go. Install manually from https://go.dev/dl/"
        exit 1
    }
else
    echo "[3/5] Go already installed ($(go version))"
fi

# 4. Clone and build the proxy
REPO_DIR="$HOME/openclaw-cursor"
if [ ! -d "$REPO_DIR" ]; then
    echo "[4/5] Cloning and building openclaw-cursor proxy..."
    git clone https://github.com/GabrieleRisso/openclaw-cursor.git "$REPO_DIR"
    cd "$REPO_DIR"
    make build
    make install-local
else
    echo "[4/5] Proxy already cloned at $REPO_DIR"
    cd "$REPO_DIR"
    make build
    make install-local
fi

# 5. Generate configs
echo "[5/5] Generating configs..."
mkdir -p ~/.openclaw/logs ~/.openclaw/agents/main/agent ~/.openclaw/skills

# Proxy config
if [ ! -f ~/.openclaw/cursor-proxy.json ]; then
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

# OpenClaw config
if [ ! -f ~/.openclaw/openclaw.json ]; then
    cat > ~/.openclaw/openclaw.json <<'EOF'
{
  "gateway": { "mode": "local", "port": 18789 },
  "models": {
    "mode": "merge",
    "providers": {
      "cursor": {
        "baseUrl": "http://127.0.0.1:32125/v1",
        "api": "openai-completions",
        "models": [
          { "id": "auto", "name": "Cursor Auto", "contextWindow": 200000, "maxTokens": 8192 },
          { "id": "opus-4.6", "name": "Claude 4.6 Opus", "contextWindow": 200000, "maxTokens": 8192 },
          { "id": "opus-4.6-thinking", "name": "Claude 4.6 Opus (Thinking)", "reasoning": true, "contextWindow": 200000, "maxTokens": 8192 },
          { "id": "gpt-5.3-codex", "name": "GPT-5.3 Codex", "contextWindow": 200000, "maxTokens": 8192 }
        ]
      }
    }
  },
  "agents": { "defaults": { "model": { "primary": "cursor/auto" } } }
}
EOF
fi

# Auth profile placeholder
if [ ! -f ~/.openclaw/agents/main/agent/auth-profiles.json ]; then
    cat > ~/.openclaw/agents/main/agent/auth-profiles.json <<'EOF'
{
  "profiles": {
    "cursor:default": { "type": "api_key", "provider": "cursor", "key": "placeholder" }
  }
}
EOF
fi

# Copy skill
cp -r "$REPO_DIR/skills/cursor-proxy" ~/.openclaw/skills/ 2>/dev/null || true

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Log in:    openclaw-cursor login"
echo "  2. Start:     openclaw-cursor start &"
echo "  3. Gateway:   openclaw gateway --port 18789"
echo "  4. Dashboard: http://$(hostname -I | awk '{print $1}'):18789/"
echo ""
echo "From other VMs:  curl http://$(hostname -I | awk '{print $1}'):32125/health"
