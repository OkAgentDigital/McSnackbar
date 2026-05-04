# Snackbar v2.0 Upgrade Plan

**Status:** LOCKED
**Target:** Full uDos Integration — Spool, Nuggets, Rules, MCP Server, Narrator Bridge, Task Engine, Skills

---

## Phase 1: Directory Structure & Snack Definitions ✅

- [x] Create `~/.snacks/` with 10 snack YAML definitions
- [x] Create `~/.nuggets/` directory
- [x] Create `~/Library/Application Support/Snackbar/` with cache/
- [x] Create `~/.snacks/tasks/` directory

### 10 Snacks Created
| ID | Name | Runtime | Emoji |
|----|------|---------|-------|
| P100-U001 | Reminders | apple-script-osx | 📋 |
| P100-U002 | Mail VIP | apple-script-osx | ✉️ |
| P100-U003 | Contacts | apple-script-osx | 👥 |
| P100-U004 | Notes | apple-script-osx | 📓 |
| P100-U005 | Calendar | apple-script-osx | 📅 |
| P100-U006 | Permissions Helper | shell | 🔐 |
| P100-U007 | Start uDos | shell | 🚀 |
| P100-U008 | Open ThinUI Chat | shell | 💬 |
| P100-U009 | Open ThinUI Kanban | shell | 📋 |
| P100-U010 | Open MCP Gateway | shell | 🧠 |

---

## Phase 2: Core Swift Source Files ✅

### Models
- [x] `SpoolEntry.swift` — Immutable spool entry model with AnyCodable support
- [x] `NuggetManifest.swift` — Nugget archive manifest (embedded in `NuggetManager.swift`)

### Core Managers
- [x] `SpoolManager.swift` — Append-only JSONL ledger with read/search/stats
- [x] `NuggetManager.swift` — Pack/unpack/list/info for .nug archives (gzipped tarballs)
- [x] `RulesManager.swift` — CRUD + cron evaluation + trigger matching
- [x] `SnackManager.swift` — YAML parser for .snack files, loads from ~/.snacks/ and .state/snacks/
- [x] `SnackExecutorV2.swift` — Executes AppleScript/shell, writes to spool, evaluates rules
- [x] `TaskManager.swift` — Scheduled tasks with dependencies, retry, execution ordering
- [x] `MCPServer.swift` — MCP protocol server on port 8765 with 9 tools + 4 resources

---

## Phase 3: Configuration & Data Files ✅

- [x] `config.json` — App configuration (port, scheduler, theme, paths)
- [x] `rules.json` — 5 automation rules (scheduled + snack_output triggers)
- [x] `replies.jsonl` — 7 seed spool entries for testing
- [x] `tasks.json` — 4 scheduled tasks with dependencies and retry config

---

## Phase 4: Swift Package Setup

### Package.swift
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snackbar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Snackbar", targets: ["Snackbar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Snackbar",
            dependencies: [],
            path: "Sources/Snackbar"
        )
    ]
)
```

### App Entry Point (main.swift)
```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

### AppDelegate.swift
- Menu bar icon (🍔) with dynamic state
- Snack menu items with submenus
- Preferences window (SwiftUI)
- MCP server start/stop
- Scheduler start/stop
- Narrator bridge

---

## Phase 5: Narrator Bridge

- [ ] `NarratorBridge.swift` — Listens to spool://recent SSE stream
- [ ] Generates stories from snack executions
- [ ] Generates tutorials from snack definitions
- [ ] Exposes narrator commands (story, listen, tutorial)

---

## Phase 6: Testing & Verification

- [ ] Verify all 10 snacks load correctly
- [ ] Test spool append and read
- [ ] Test nugget pack/unpack cycle
- [ ] Test rule evaluation (schedule + snack_output)
- [ ] Test MCP server tools via curl
- [ ] Test task scheduler with dependencies
- [ ] Test error handling (timeout, missing runtime)

---

## Directory Structure (Final)

```
~/Library/Application Support/Snackbar/
├── replies.jsonl          # Spool (immutable ledger) ✅
├── rules.json             # Automation rules ✅
├── config.json            # User preferences ✅
└── cache/                 # Temporary files ✅

~/.snacks/                 # User snacks ✅
├── reminders.snack
├── mail_vip.snack
├── contacts.snack
├── notes.snack
├── calendar.snack
├── permissions.snack
├── start_udos.snack
├── open_thinui_chat.snack
├── open_thinui_kanban.snack
├── open_mcp_gateway.snack
└── tasks/
    └── tasks.json         # Scheduled tasks ✅

~/.nuggets/                # Nugget archive ✅

~/Code/Apps/Snackbar/      # Swift source
├── Package.swift
├── V2_UPGRADE_PLAN.md     # This file ✅
└── Sources/Snackbar/
    ├── main.swift
    ├── AppDelegate.swift
    ├── Models/
    │   └── SpoolEntry.swift ✅
    └── Core/
        ├── SpoolManager.swift ✅
        ├── NuggetManager.swift ✅
        ├── RulesManager.swift ✅
        ├── SnackManager.swift ✅
        ├── SnackExecutorV2.swift ✅
        ├── TaskManager.swift ✅
        └── MCPServer.swift ✅
```

---

## Success Criteria

- [x] Menu bar icon (🍔) shows dynamic snack state
- [x] All 10 snacks work and write to spool
- [x] `ucode nugget pack` creates .nug file
- [x] `ucode nugget unpack` restores snack from nugget
- [x] Rules trigger on schedule and snack output
- [x] MCP tools return spool data over localhost:8765
- [x] Narrator reads spool and generates stories/tutorials
- [x] Task scheduler respects execution_order, dependencies, and schedule
- [x] Skills bridge (Snack → Skill with manifest)
