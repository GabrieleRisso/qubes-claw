# Curated OpenClaw Plugins

Vetted plugins for the Qubes + OpenClaw setup. Install individually or use `install-plugins.sh`.

## Included Plugins

| Plugin | Category | Why |
|--------|----------|-----|
| Matrix | Channel | Decentralized comms, fits Qubes security model |
| PowerMem | Memory | AI-powered long-term memory with Ebbinghaus recall |
| MemOS Cloud | Memory | Cloud-backed persistent context across sessions |
| Voice Call | Voice | Phone call capabilities via Twilio/Telnyx/Plivo |
| Exoshell | Tools | Claude-powered development utilities |

## Quick install

```bash
bash install-plugins.sh          # install all curated plugins
bash install-plugins.sh matrix   # install just Matrix
```

## Manual install

```bash
openclaw plugins install @openclaw/matrix
openclaw plugins install powermem
openclaw plugins install github:MemTensor/MemOS-Cloud-OpenClaw-Plugin
openclaw plugins install @openclaw/voice-call
openclaw plugins install exoshell
```

## Plugin config

Each plugin may need config in `~/.openclaw/openclaw.json`. See examples below.

### Matrix

```json
{
  "plugins": ["@openclaw/matrix"],
  "matrix": {
    "homeserver": "https://matrix.org",
    "userId": "@yourbot:matrix.org",
    "accessToken": "YOUR_MATRIX_TOKEN",
    "allowedRooms": ["!roomid:matrix.org"]
  }
}
```

### Voice Call

```json
{
  "plugins": ["@openclaw/voice-call"],
  "voiceCall": {
    "provider": "twilio",
    "accountSid": "YOUR_SID",
    "authToken": "YOUR_TOKEN",
    "phoneNumber": "+1234567890"
  }
}
```
