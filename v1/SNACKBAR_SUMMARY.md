# 🍔 Snackbar — Feature Summary

## What is Snackbar?

Snackbar is a **menu-bar-only macOS app** that serves as the execution spine of the uDos ecosystem. It runs automations ("snacks"), exposes an MCP server for AI agents, maintains an append-only execution ledger, and integrates with DevStudio, Hivemind, and Ubuntu backends.

## Core Features

### 🥜 Snack Execution
- Run AppleScript and shell automations from `.snack` YAML files
- Two runtimes: AppleScript (`osa_script`) and shell (`zsh`)
- Execution logging to spool ledger
- Rule evaluation after execution

### 🔌 MCP Server (Native Swift)
- Port **8765**, Apple 2024-11-05 SSE spec
- **9 tools**: `run_snack`, `list_snacks`, `get_spool`, `create_rule`, `list_rules`, `delete_rule`, `pack_nugget`, `unpack_nugget`, `list_nuggets`
- **4 resources**: `snackbar://spool/recent`, `snackbar://rules`, `snackbar://nuggets`, `snackbar://status`
- Dual path: native Swift (primary) + Hivemind Rust gateway (fallback)

### 📜 Spool Ledger
- Append-only JSONL at `~/Library/Application Support/Snackbar/replies.jsonl`
- Each entry: timestamp, snack name, status, output, duration
- Read via MCP resource or direct file access

### 📦 Nugget Archives
- Pack/unpack `.nug` gzipped tarballs
- Manifest + SHA256 checksum per archive
- List all nuggets via MCP resource

### 🤖 Automation Rules
- CRUD for automation rules
- Trigger types: cron, snack-output, file-watch, keyboard-shortcut
- Rule evaluation after each snack execution

### 📋 Task Scheduler
- Ordered tasks with dependencies
- Retry logic with configurable attempts
- Completion chaining

### 🔗 DevStudio Integration (SnackbarCore)
- iCloud sync for notes
- Note CRUD via MCP client
- DevStudio skill triggering
- Sync status monitoring

### 🌐 External Integrations
- **Hivemind** (Rust MCP gateway, port 30000): LLM backend access
- **Ubuntu Proxy** (SSH, wizard@192.168.20.11): Ollama + remote Hivemind
- **Xcode Build Service**: Build Xcode/Rust projects from menu bar
- **Update Checker**: GitHub release version check
- **Feed Manager**: Execution logging + LeChat Pro API

### 🎯 macOS Automations
- Shortcuts intents: CreateNote, SyncNotes, TriggerDevStudioSkill
- AppleScript handler
- SwiftUI preferences window (General, Spool, Rules, Nuggets tabs)

## Architecture

```
Snackbar (macOS menu bar app)
├── Snackbar (executable) — MCP server, spool, executor, rules, scheduler
├── SnackbarCore (library) — DevStudio integration
└── SnackbarAutomations (library) — Shortcuts, Intents, AppleScript
```

## Quick Start

```bash
# Build and run
cd ~/Code/Apps/Snackbar
swift build
swift run

# Or use the build script
./build_and_run.sh
```

## Configuration

See `config.yaml` for runtime configuration options.
