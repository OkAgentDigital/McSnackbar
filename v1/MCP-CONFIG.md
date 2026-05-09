# MCP Configuration Guide

## Overview

Snackbar connects to two MCP servers:
- **Snackbar** (port 8765) — built-in HTTP JSON-RPC server for snack execution, spool, vault, automation
- **Hivemind** (port 3010) — Rust-based MCP gateway with SSE transport for LLM, GitHub tools, task management

## Config Files (all must be consistent)

### 1. Xcode MCP Discovery (`~/Library/Developer/Xcode/MCP/snackbar.json`)
**Written by:** `MCPManager.writeXcodeMCPConfig()` on Snackbar launch
**Read by:** Xcode 26+ for external MCP server discovery
```json
{
  "mcpServers": {
    "snackbar": { "type": "http", "url": "http://localhost:8765" },
    "hivemind":  { "type": "sse",  "url": "http://localhost:3010/sse" }
  }
}
```

### 2. Xcode Claude Agent (`~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json`)
**Read by:** Xcode's internal Claude Code agent (Xcode 26.3+)
```json
{
  "projects": {
    "/Users/fredbook/Code/Apps/Snackbar": {
      "mcpServers": {
        "hivemind":  { "type": "sse",  "url": "http://localhost:3010/sse" },
        "snackbar":  { "type": "http", "url": "http://localhost:8765" }
      }
    }
  }
}
```

### 3. Claude Code Settings (`~/.claude/settings.json`)
**Managed by:** Claude Code CLI
```json
{
  "projects": {
    "/Users/fredbook/Code/Apps/Snackbar": {
      "mcpServers": {
        "hivemind":  { "type": "sse", "url": "http://localhost:3010/sse" },
        "snackbar":  { "type": "http", "url": "http://localhost:8765" }
      },
      "enabledMcpjsonServers": ["hivemind", "snackbar"]
    }
  }
}
```

### 4. Claude Local Settings (`~/.claude/settings.local.json`)
```json
{
  "mcpServers": {
    "hivemind":  { "type": "sse", "url": "http://localhost:3010/sse" },
    "snackbar":  { "type": "http", "url": "http://localhost:8765" }
  }
}
```

### 5. Project `.mcp.json` (`~/Code/Apps/Snackbar/.mcp.json`)
```json
{
  "mcpServers": {
    "snackbar": { "type": "http", "url": "http://localhost:8765" },
    "hivemind":  { "type": "sse",  "url": "http://localhost:3010/sse" }
  }
}
```

### 6. VS Code MCP (`~/Code/Apps/Snackbar/.vscode/mcp.json`)
```json
{
  "mcpServers": {
    "snackbar": { "type": "http", "url": "http://localhost:8765" },
    "hivemind":  { "type": "sse",  "url": "http://localhost:3010/sse" }
  }
}
```

### 7. Cline MCP (`~/.cline/data/settings/cline_mcp_settings.json`)
```json
{
  "mcpServers": {
    "snackbar": { "type": "http", "url": "http://localhost:8765" },
    "hivemind":  { "type": "sse",  "url": "http://localhost:3010/sse" }
  }
}
```

## Transport

| Server | Type | Endpoint |
|--------|------|----------|
| Snackbar | HTTP | `POST http://localhost:8765` (JSON-RPC) |
| Hivemind | SSE | `GET http://localhost:3010/sse` → `POST /messages` |

## Port Map

| Port | Service | Transport |
|------|---------|-----------|
| 8765 | Snackbar MCP | HTTP JSON-RPC |
| 3010 | Hivemind Rust | SSE + HTTP |
| 30000 | Legacy (deprecated) | — |
| 30010 | Old Python bridge (removed) | — |
| 18765 | Old Snackbar bridge (removed) | — |

## Launch Agents

| Label | Binary | Port | Auto-restart |
|-------|--------|------|--------------|
| `com.udos.hivemind-rust` | `hivemind-rust` | 3010 | ✅ |
| `com.udos.snackbar` | Snackbar.app | 8765 | ❌ (launched by user/app) |

## Old (Removed) Bridges

The following Python-based SSE bridges have been removed in favor of native SSE support:
- ~~`com.udos.hivemind-sse-bridge`** (port 30010) — old Python bridge to Ubuntu Hivemind
- ~~`com.udos.snackbar-sse-bridge`** (port 18765) — old Python bridge to Snackbar

Their launch agents are disabled (renamed to `.plist.disabled`).

## Troubleshooting

1. **Xcode can't find Hivemind:**
   - Check `~/Library/Developer/Xcode/MCP/snackbar.json` exists
   - Verify hivemind-rust is running: `lsof -i :3010`
   - Check `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json`
   - Restart Xcode

2. **Snackbar overwrites config:** The app calls `writeXcodeMCPConfig()` on launch.
   `MCPManager.generateXcodeMCPConfig()` now produces `"type": "sse"` for hivemind.

3. **Port conflicts:** Ensure old Python bridges aren't running:
   ```bash
   pgrep -f "hivemind-sse-bridge\|snackbar-sse-bridge"
   ```
   Should return nothing.

4. **Verify all endpoints:**
   ```bash
   curl http://localhost:3010/health          # Server status
   curl http://localhost:3010/status          # Full status
   curl -s http://localhost:3010/sse          # SSE (hangs = working)
   ```
