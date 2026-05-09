# 📋 Snackbar — Consolidated Architecture Summary

## Identity

**Snackbar is the native macOS execution spine of uDos.**  
One icon (🍔). One spool. Infinite snacks. One narrator.

It is a menu-bar-only macOS app that orchestrates automations (snacks), exposes an MCP server for agentic tool calling, maintains an append-only execution ledger, and integrates with DevStudio, Hivemind, and Ubuntu backends.

---

## Architecture Overview

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

---

## Package Targets

| Target | Type | Path | Purpose |
|--------|------|------|---------|
| **Snackbar** | Executable | `Sources/Snackbar/` | macOS menu bar app — MCP server, spool, executor, rules, scheduler |
| **SnackbarCore** | Library | `Sources/Core/` | DevStudio integration — iCloud sync, notes, MCP client, skill trigger |
| **SnackbarAutomations** | Library | `Sources/macOS/` | Shortcuts, Intents, AppleScript handler |
| **SnackbarTests** | Test | `Tests/` | Unit tests |

---

## Core Components

### Snackbar (Executable)

| Component | File | Purpose |
|-----------|------|---------|
| App Delegate | `AppDelegateV2.swift` | App lifecycle, menu bar setup, preferences window |
| MCP Server | `MCPServer.swift` | Native MCP server on port 8765 (Apple 2024-11-05 spec) |
| Snack Executor | `SnackExecutorV2.swift` | AppleScript + shell runtime for `.snack` YAML files |
| Snack Manager | `SnackManager.swift` | Snack CRUD, `.snack` YAML parsing, `SnackV2` model |
| Spool Manager | `SpoolManager.swift` | Append-only JSONL ledger at `~/Library/Application Support/Snackbar/replies.jsonl` |
| Rules Manager | `RulesManager.swift` | Automation rules CRUD + cron/snack-output/file-watch/keyboard-shortcut triggers |
| Task Manager | `TaskManager.swift` | Ordered task scheduling with dependencies, retry, completion chaining |
| Nugget Manager | `NuggetManager.swift` | Pack/unpack `.nug` gzipped tarballs with manifest + checksum |
| Hivemind Client | `HivemindClient.swift` | HTTP JSON-RPC MCP client → HivemindRust on port 30000 |
| Ubuntu Proxy | `UbuntuProxy.swift` | SSH proxy → wizard@192.168.20.11 for Ollama + remote Hivemind |
| Xcode Build Service | `XcodeBuildService.swift` | Build Xcode/Rust projects from menu bar |
| Update Checker | `UpdateChecker.swift` | GitHub release version check |
| Feed Manager | `FeedManager.swift` | Execution logging + LeChat Pro API integration |
| Menu Builder | `MenuBuilder.swift` | Menu bar construction |

### SnackbarCore (Library)

| Component | File | Purpose |
|-----------|------|---------|
| Note Manager | `NoteManager.swift` | Note CRUD + iCloud sync |
| iCloud Sync Manager | `iCloudSyncManager.swift` | iCloud sync orchestration |
| MCP Client | `MCPClient.swift` | MCP client for DevStudio |
| DevStudio Skill Trigger | `DevStudioSkillTrigger.swift` | Trigger DevStudio skills |
| DevStudio Config Manager | `DevStudioConfigManager.swift` | DevStudio configuration management |
| DevTools Manager | `DevToolsManager.swift` | DevTools orchestration |
| Sync Status Monitor | `SyncStatusMonitor.swift` | iCloud sync status tracking |

### SnackbarAutomations (Library)

| Component | File | Purpose |
|-----------|------|---------|
| Create Note Intent | `CreateNoteIntent.swift` | Shortcuts intent for note creation |
| Sync Notes Intent | `SyncNotesIntent.swift` | Shortcuts intent for note sync |
| Trigger DevStudio Skill Intent | `TriggerDevStudioSkillIntent.swift` | Shortcuts intent for skill triggering |
| AppleScript Handler | `SnackbarAppleScriptHandler.swift` | AppleScript handler |
| Shortcuts | `SnackbarShortcuts.swift` | Shortcuts integration |
| Content View | `ContentView.swift` | SwiftUI preferences view |
| App | `SnackbarApp.swift` | SwiftUI app entry |

---

## MCP Architecture (Dual Path)

1. **Primary**: Native Swift MCP Server on port **8765** — always available, no external dependencies
2. **Fallback**: Hivemind (Rust) MCP Gateway on port **30000** — for LLM/Ubuntu backend bridging

Both expose the same tool interface. Snackbar tries Hivemind first for LLM operations, falls back to native MCP for core snack/spool operations.

### MCP Tools (Native Swift, port 8765)

| Tool | Description |
|------|-------------|
| `run_snack` | Execute a snack by name |
| `list_snacks` | List all available snacks |
| `get_spool` | Read spool entries |
| `create_rule` | Create an automation rule |
| `list_rules` | List all automation rules |
| `delete_rule` | Delete an automation rule |
| `pack_nugget` | Archive a snack as a nugget |
| `unpack_nugget` | Restore a snack from a nugget |
| `list_nuggets` | List all nugget archives |

### MCP Resources (Native Swift, port 8765)

| Resource | Description |
|----------|-------------|
| `snackbar://spool/recent` | Recent spool entries |
| `snackbar://rules` | All automation rules |
| `snackbar://nuggets` | All nugget archives |
| `snackbar://status` | Snackbar runtime status |

---

## Data Flow

```
User/MCP Client
    │
    ▼
MCP Server (:8765) ───→ Hivemind Client (:30000) ───→ Ubuntu Proxy (:22)
    │                                                      │
    ▼                                                      ▼
Snack Executor ───→ Spool (replies.jsonl)          Ollama / Remote Hivemind
    │
    ▼
Rules Engine ───→ Task Scheduler ───→ Nugget Archives
```

---

## Component Repositories

| Component | Location | Language | Purpose |
|-----------|----------|----------|---------|
| **Snackbar** | `~/Code/Apps/Snackbar` | Swift (macOS) | Native macOS execution spine |
| **Hivemind** | `~/Code/OkAgentDigital/Hivemind` | Rust | MCP gateway + LLM orchestration |
| **Re3Engine** | `~/Code/OkAgentDigital/Re3Engine` | Python | Python-based agent tooling |
| **Thinui** | `~/Code/OkAgentDigital/Thinui` | Rust | UI framework |
| **DevStudio** | `~/Code/DevStudio` | Swift | IDE integration |
| **uDosGo** | `~/Code/uDosGo` | Go | Go-based services |

---

## Key Ports

| Service | Port | Protocol |
|---------|------|----------|
| MCP Server (native Swift) | 8765 | HTTP SSE (Apple 2024-11-05) |
| Hivemind (Rust MCP gateway) | 30000 | HTTP JSON-RPC |
| Ubuntu backend (SSH) | 22 | SSH |

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| v2.0 | Current | Consolidated architecture, native MCP server, spool ledger, nugget archives, rules engine, task scheduler, DevStudio integration |
| v1.0 | Previous | Original menu bar app with Hivemind/Ubuntu/Xcode integration, multiple target experiments |
