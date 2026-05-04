# Snackbar — AI Context

## Identity

**Snackbar is the native macOS execution spine of uDos.**  
One icon (🍔). One spool. Infinite snacks. One narrator.

It is a menu-bar-only macOS app that orchestrates automations (snacks), exposes an MCP server for agentic tool calling, maintains an append-only execution ledger, and integrates with DevStudio, Hivemind, and Ubuntu backends.

## Package Structure

```
Package.swift — 4 targets:
├── Snackbar (executable)       → Sources/Snackbar/
├── SnackbarCore (library)      → Sources/Core/
├── SnackbarAutomations (library) → Sources/macOS/
└── SnackbarTests (test)        → Tests/
```

## Key Files

| File | Purpose |
|------|---------|
| `Sources/Snackbar/main.swift` | Entry point |
| `Sources/Snackbar/Core/AppDelegateV2.swift` | App lifecycle |
| `Sources/Snackbar/Core/MCPServer.swift` | MCP server (port 8765) |
| `Sources/Snackbar/Core/SnackExecutorV2.swift` | AppleScript + shell runtime |
| `Sources/Snackbar/Core/SnackManager.swift` | Snack CRUD + YAML parsing |
| `Sources/Snackbar/Core/SpoolManager.swift` | Append-only JSONL ledger |
| `Sources/Snackbar/Core/RulesManager.swift` | Automation rules |
| `Sources/Snackbar/Core/TaskManager.swift` | Task scheduler |
| `Sources/Snackbar/Core/NuggetManager.swift` | .nug archives |
| `Sources/Snackbar/Core/HivemindClient.swift` | MCP client → Hivemind:30000 |
| `Sources/Snackbar/Core/UbuntuProxy.swift` | SSH proxy → 192.168.20.11 |
| `Sources/Snackbar/Core/XcodeBuildService.swift` | Xcode/Rust build service |
| `Sources/Snackbar/Core/UpdateChecker.swift` | GitHub release checker |
| `Sources/Snackbar/Core/FeedManager.swift` | Execution logging + LeChat Pro |
| `Sources/Snackbar/Core/MenuBuilder.swift` | Menu bar construction |
| `Sources/Core/Services/NoteManager.swift` | Note CRUD + iCloud sync |
| `Sources/Core/Services/iCloudSyncManager.swift` | iCloud sync orchestration |
| `Sources/Core/Services/MCPClient.swift` | MCP client for DevStudio |
| `Sources/Core/Services/DevStudioSkillTrigger.swift` | DevStudio skill trigger |
| `Sources/macOS/Automations/CreateNoteIntent.swift` | Shortcuts intent |
| `Sources/macOS/Automations/SyncNotesIntent.swift` | Shortcuts intent |
| `Sources/macOS/Automations/TriggerDevStudioSkillIntent.swift` | Shortcuts intent |
| `Sources/macOS/UI/ContentView.swift` | SwiftUI preferences |
| `Sources/macOS/UI/SnackbarApp.swift` | SwiftUI app entry |

## MCP Architecture (Dual Path)

1. **Primary**: Native Swift MCP Server on port **8765** — always available, no external dependencies
2. **Fallback**: Hivemind (Rust) MCP Gateway on port **30000** — for LLM/Ubuntu backend bridging

## Key Ports

| Service | Port | Protocol |
|---------|------|----------|
| MCP Server (native Swift) | 8765 | HTTP SSE (Apple 2024-11-05) |
| Hivemind (Rust MCP gateway) | 30000 | HTTP JSON-RPC |
| Ubuntu backend (SSH) | 22 | SSH |

## Component Repositories

| Component | Location | Language |
|-----------|----------|----------|
| **Snackbar** | `~/Code/Apps/Snackbar` | Swift (macOS) |
| **Hivemind** | `~/Code/OkAgentDigital/Hivemind` | Rust |
| **Re3Engine** | `~/Code/OkAgentDigital/Re3Engine` | Python |
| **Thinui** | `~/Code/OkAgentDigital/Thinui` | Rust |
| **DevStudio** | `~/Code/DevStudio` | Swift |
| **uDosGo** | `~/Code/uDosGo` | Go |

## Build & Run

```bash
cd ~/Code/Apps/Snackbar
swift build
swift test
swift run
# Or: ./build_and_run.sh
```

## Key Config

- `config.yaml` — runtime configuration
- `Resources/snacks.json` — default snacks
- `Resources/categories.json` — snack categories
