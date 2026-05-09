# 🗺️ Snackbar Roadmap

## Identity

**Snackbar is the native macOS execution spine of uDos.**  
One icon (🍔). One spool. Infinite snacks. One narrator.

It is a menu-bar-only macOS app that:
- Runs **snacks** (AppleScript/shell automations) from `.snack` YAML files
- Exposes an **MCP server** (port 8765, Apple 2024-11-05 spec) for agentic tool calling
- Maintains an **append-only spool ledger** (`replies.jsonl`) of all executions
- Manages **automation rules** (cron, snack-output, file-watch, keyboard-shortcut triggers)
- Schedules **tasks** with dependency ordering and retry logic
- Archives/restores snacks as **nuggets** (`.nug` gzipped tarballs)
- Integrates with **DevStudio** via iCloud sync, note management, and MCP client
- Bridges to **Hivemind** (Rust MCP gateway at `~/Code/OkAgentDigital/Hivemind`) for LLM backend access
- Proxies to **Ubuntu backend** (wizard@192.168.20.11) for Ollama + remote Hivemind

---

## Current State: v2.0 (Consolidated)

### ✅ Completed

| Area | Status | Details |
|------|--------|---------|
| **Snack Execution** | ✅ | AppleScript + shell runtimes, spool logging, rule evaluation |
| **MCP Server** | ✅ | Native Swift on port 8765, 9 tools + 4 resources, Apple 2024-11-05 spec |
| **Spool Ledger** | ✅ | Append-only JSONL at `~/Library/Application Support/Snackbar/replies.jsonl` |
| **Nugget Archives** | ✅ | Pack/unpack `.nug` gzipped tarballs with manifest + checksum |
| **Automation Rules** | ✅ | CRUD + cron/snack-output/file-watch/keyboard-shortcut triggers |
| **Task Scheduler** | ✅ | Ordered tasks with dependencies, retry, completion chaining |
| **Preferences UI** | ✅ | SwiftUI preferences window (General, Spool, Rules, Nuggets tabs) |
| **Hivemind Client** | ✅ | HTTP JSON-RPC MCP client for HivemindRust (port 30000) |
| **Ubuntu Proxy** | ✅ | SSH-based proxy to wizard@192.168.20.11 for Ollama + remote Hivemind |
| **Xcode Build Service** | ✅ | Build Xcode/Rust projects from menu bar |
| **Update Checker** | ✅ | GitHub release version check |
| **DevStudio Core** | ✅ | NoteManager, iCloudSync, MCPClient, DevStudioSkillTrigger, SyncStatusMonitor |
| **macOS Automations** | ✅ | Shortcuts, Intents, AppleScript handler |
| **Feed Manager** | ✅ | Execution logging + LeChat Pro API integration |

### 🏗️ In Progress

| Area | Status | Details |
|------|--------|---------|
| **Narrator Bridge** | 🔜 Planned | Bridge between Snackbar spool and Narrator agent |
| **Testing** | ✅ | 5 unit tests for Note model, build passes cleanly |

### ❌ Not Started

| Area | Details |
|------|---------|
| **Platform Expansion** | iOS, watchOS, web companions |
| **Collaboration** | Shared spools, multi-user rules |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Snackbar (macOS)                   │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Snack    │  │ MCP      │  │ Task Scheduler    │  │
│  │ Executor │  │ Server   │  │ + Rules Engine    │  │
│  │ :8765    │  │          │  │                   │  │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘  │
│       │              │                 │             │
│  ┌────▼──────────────▼─────────────────▼──────────┐  │
│  │              Spool (replies.jsonl)              │  │
│  └─────────────────────┬──────────────────────────┘  │
│                        │                             │
│  ┌─────────────────────▼──────────────────────────┐  │
│  │           Nugget Archives (.nug)                │  │
│  └─────────────────────────────────────────────────┘  │
│                                                        │
│  ┌─────────────────────────────────────────────────┐  │
│  │         DevStudio Integration (SnackbarCore)     │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │  │
│  │  │ iCloud   │  │ MCP      │  │ DevStudio    │  │  │
│  │  │ Sync     │  │ Client   │  │ SkillTrigger │  │  │
│  │  └──────────┘  └──────────┘  └──────────────┘  │  │
│  └─────────────────────────────────────────────────┘  │
└───────────────────────┬─────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│  Hivemind    │ │  Ubuntu  │ │  Xcode CLI   │
│  (Rust MCP)  │ │  Backend │ │  Build       │
│  :30000      │ │  :22 SSH │ │  Service     │
└──────────────┘ └──────────┘ └──────────────┘
```

### MCP Architecture (Dual Path)

1. **Primary**: Native Swift MCP Server on port **8765** — always available, no external dependencies
2. **Fallback**: Hivemind (Rust) MCP Gateway on port **30000** — for LLM/Ubuntu backend bridging

Both expose the same tool interface. Snackbar tries Hivemind first for LLM operations, falls back to native MCP for core snack/spool operations.

---

## Component Repositories

| Component | Location | Language |
|-----------|----------|----------|
| **Snackbar** | `~/Code/Apps/Snackbar` | Swift (macOS) |
| **Hivemind** | `~/Code/OkAgentDigital/Hivemind` | Rust |
| **Re3Engine** | `~/Code/OkAgentDigital/Re3Engine` | Python |
| **Thinui** | `~/Code/OkAgentDigital/Thinui` | Rust |
| **DevStudio** | `~/Code/DevStudio` | Swift |
| **uDosGo** | `~/Code/uDosGo` | Go |

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| v2.0 | Current | Consolidated architecture, native MCP server, spool ledger, nugget archives, rules engine, task scheduler, DevStudio integration |
| v1.0 | Previous | Original menu bar app with Hivemind/Ubuntu/Xcode integration, multiple target experiments |
