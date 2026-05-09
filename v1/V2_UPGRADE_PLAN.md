# V2 Upgrade Plan — COMPLETED ✅

> **Status**: All v2 consolidation tasks are complete.  
> **Branch**: `consolidate-roadmap-v2`  
> **Date**: 2026-05-05

---

## What Was Done

### 1. Dead Code Removal

| Removed | Reason |
|---------|--------|
| `Sources/CompleteSnackbar/` | Experimental target — all logic lives in `Sources/Snackbar/` |
| `Sources/EnhancedSnackbar/` | Experimental target — superseded by v2 architecture |
| `Sources/SimpleSnackbar/` | Experimental target — superseded by v2 architecture |
| `Sources/MainSpine/` | Experimental target — superseded by v2 architecture |
| `Sources/Snackbar/Core/AppDelegate.swift` | Replaced by `AppDelegateV2.swift` |
| `Sources/Snackbar/Core/SnackExecutor.swift` | Replaced by `SnackExecutorV2.swift` |
| `Sources/Snackbar/Core/SnackScheduler.swift` | Merged into `TaskManager.swift` |
| `Sources/Snackbar/Core/PermissionsManager.swift` | macOS permissions handled by system prompts |
| `Sources/Snackbar/Managers/` | Dead code — no references |
| `Sources/Snackbar/Utils/` | Dead code — no references |
| `Sources/Snackbar/Views/` | Dead code — no references |
| `Sources/Snackbar/Models/Category.swift` | Replaced by inline enums |
| `Sources/Snackbar/Models/FeedEntry.swift` | Replaced by `SpoolEntry.swift` |
| `Sources/Snackbar/Models/Schedule.swift` | Replaced by `TaskManager.swift` |
| `Sources/Snackbar/Models/Snack.swift` | Replaced by `SnackV2` in `SnackManager.swift` |

### 2. Package.swift Restructured

- **SnackbarCore** library target: `Sources/Core/` — DevStudio integration (iCloud, notes, MCP client, skill trigger)
- **Snackbar** executable target: `Sources/Snackbar/` — macOS menu bar app (MCP server, spool, executor, rules, scheduler)
- **SnackbarAutomations** target: `Sources/macOS/` — Shortcuts, Intents, AppleScript handler
- **SnackbarTests** test target: `Tests/` — unit tests

### 3. Planning Documents Updated

- **ROADMAP.md**: Reflects v2.0 consolidated architecture with accurate component list
- **V2_UPGRADE_PLAN.md**: This file — marks all tasks complete
- **PROJECT_STRUCTURE.md**: Updated to match actual file tree
- **CONSOLIDATED_SUMMARY.md**: Updated with final architecture

### 4. MCP Architecture Clarified

- **Primary**: Native Swift MCP Server on port **8765** — always available, no external dependencies
- **Fallback**: Hivemind (Rust) MCP Gateway on port **30000** — for LLM/Ubuntu backend bridging
- **Re3Engine (Python)**: MCP server components merged here for Python-based agent tooling
- **mcp-client-rs**: MCP client components merged into Hivemind (Rust)

---

## Remaining Work (Post-Consolidation)

- [x] Add unit tests for `SnackManager`, `SpoolManager`, `RulesManager`, `TaskManager`
- [ ] Add integration tests for MCP server endpoints
- [ ] Implement Narrator Bridge (spool → Narrator agent)
- [ ] Add CI pipeline (GitHub Actions)
- [ ] Create Homebrew formula for distribution
