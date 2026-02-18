#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-vm.sh — Install OpenClaw + cursor proxy inside a Qubes AppVM
# Source: https://github.com/GabrieleRisso/openclaw-cursor
# ---------------------------------------------------------------------------

echo "=== OpenClaw + Cursor Proxy — VM Setup ==="
echo ""

if [ -f /usr/share/qubes/marker-vm ]; then
    VM_NAME=$(qubesdb-read /name 2>/dev/null || echo "unknown")
    echo "Qubes VM: $VM_NAME ($(qubesdb-read /qubes-vm-type 2>/dev/null || echo 'unknown type'))"
else
    echo "WARNING: Not a Qubes VM. Continuing anyway..."
fi
echo ""

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# 1. cursor-agent
if ! command -v cursor-agent &>/dev/null && ! command -v agent &>/dev/null; then
    echo "[1/6] Installing cursor-agent..."
    curl -fsSL https://cursor.com/install | bash
else
    echo "[1/6] cursor-agent OK"
fi

# 2. OpenClaw
if ! command -v openclaw &>/dev/null; then
    echo "[2/6] Installing OpenClaw..."
    curl -fsSL https://openclaw.ai/install.sh | bash 2>&1 || true
    grep -q 'npm-global' ~/.bashrc 2>/dev/null || \
        echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
    echo "[2/6] OpenClaw OK ($(openclaw --version))"
fi

# 3. Go
if ! command -v go &>/dev/null; then
    echo "[3/6] Installing Go..."
    sudo dnf install -y golang 2>/dev/null || sudo apt-get install -y golang 2>/dev/null || {
        echo "ERROR: Cannot install Go. See https://go.dev/dl/"
        exit 1
    }
else
    echo "[3/6] Go OK ($(go version | awk '{print $3}'))"
fi

# 4. Clone and build proxy
REPO_DIR="$HOME/openclaw-cursor"
echo "[4/6] Building proxy..."
if [ ! -d "$REPO_DIR" ]; then
    git clone https://github.com/GabrieleRisso/openclaw-cursor.git "$REPO_DIR"
fi
cd "$REPO_DIR"
git pull --ff-only 2>/dev/null || true
make build
make install-local

# 5. Configs
echo "[5/6] Generating configs..."
mkdir -p ~/.openclaw/logs ~/.openclaw/agents/main/agent ~/.openclaw/skills

if [ ! -f ~/.openclaw/cursor-proxy.json ]; then
    cat > ~/.openclaw/cursor-proxy.json <<'CONF'
{
  "port": 32125,
  "log_level": "info",
  "tool_mode": "openclaw",
  "timeout_ms": 300000,
  "default_model": "auto",
  "enable_thinking": true
}
CONF
fi

if [ ! -f ~/.openclaw/openclaw.json ]; then
    cat > ~/.openclaw/openclaw.json <<'CONF'
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
CONF
fi

if [ ! -f ~/.openclaw/agents/main/agent/auth-profiles.json ]; then
    cat > ~/.openclaw/agents/main/agent/auth-profiles.json <<'CONF'
{
  "profiles": {
    "cursor:default": { "type": "api_key", "provider": "cursor", "key": "placeholder" }
  }
}
CONF
fi

cp -r "$REPO_DIR/skills/cursor-proxy" ~/.openclaw/skills/ 2>/dev/null || true

# 6. Install systemd units (if available)
echo "[6/6] Installing systemd units..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="$SCRIPT_DIR/../systemd"
if [ -d "$SYSTEMD_DIR" ]; then
    mkdir -p ~/.config/systemd/user
    cp "$SYSTEMD_DIR"/*.service ~/.config/systemd/user/ 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    echo "   Installed to ~/.config/systemd/user/"
else
    echo "   Systemd dir not found, skipping"
fi

VM_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "unknown")

echo ""
echo "=== Setup complete ==="
echo ""
echo "Start services:"
echo "  openclaw-cursor login          # first time only"
echo "  openclaw-cursor start &"
echo "  openclaw gateway --port 18789 &"
echo ""
echo "Verify:"
echo "  curl http://127.0.0.1:32125/health"
echo ""
echo "From other VMs (via qubes.ConnectTCP):"
echo "  qvm-connect-tcp 32125:$(qubesdb-read /name 2>/dev/null || echo 'this-vm'):32125"
echo "  curl http://localhost:32125/health"
