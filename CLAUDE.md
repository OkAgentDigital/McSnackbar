# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release --product Snackbar

# Run
swift run

# CI release build (requires Xcode project)
xcodebuild build -project Snackbar.xcodeproj -scheme Snackbar -configuration Release
```

## Architecture

Snackbar is a macOS menu bar app that lets users execute automation scripts ("snacks") via a status bar icon. It is pure AppKit — no SwiftUI in the active build target.

### Build target

`Package.swift` defines a single executable target (`Snackbar`) sourced from `Sources/Snackbar/`. Several other directories exist (`Sources/SimpleSnackbar/`, `Sources/CompleteSnackbar/`, `Sources/MainSpine/`, `Sources/EnhancedSnackbar/`, `Sources/Core/`, `Sources/macOS/`) but are excluded from the build — they are earlier implementation attempts.

### Execution flow

```
AppDelegate.applicationDidFinishLaunching
  ├── ConfigManager.shared         (singleton, loads YAML config)
  ├── MenuBuilder()                (loads snacks from bundle JSON + UserDefaults)
  ├── SnackScheduler()             (stub, no scheduling implemented yet)
  └── FeedManager()                (execution logger)

User clicks menu bar "🍔" icon
  └── MenuBuilder.buildMenu()      (builds NSMenu grouped by Category)
       └── user selects a snack
            └── SnackExecutor.run(snack)
                 ├── runtime == "appleScript"  → NSAppleScript.executeAndReturnError
                 └── runtime == "shell"        → Process (bash -c)
                      └── (NSApp.delegate as? AppDelegate)?.feedManager?.logExecution(FeedEntry)
                           (optional chain — silently no-ops if delegate cast fails)
```

### Snack data

- **Built-in snacks** are loaded from `Resources/snacks.json` (bundled). If bundle lookup fails, `MenuBuilder` falls back to `Resources/` relative to CWD, then to hardcoded defaults.
- **Custom snacks** are persisted in `UserDefaults` under the key `"customSnacks"`.
- Snacks belong to categories defined in `Resources/categories.json`. The six predefined category IDs are: `productivity`, `communication`, `organization`, `system`, `udos`, `custom`.

### Configuration

`ConfigManager` (singleton) reads a YAML config. It looks in `~/Code/Projects/Snackbar/config/config.yaml` first, then a local `config.yaml`. **Known bug:** `isLeChatEnabled()` casts the parsed value as `Bool`, but `parseYAML` stores all leaf values as `String`, so `enabled: true` in the config always returns `false` at runtime — LeChat logging can never be activated via config until this is fixed.

### Enabled/disabled state

Which snacks are "enabled" for "Run All" is stored in `UserDefaults` under `"enabledSnacks"` as an array of snack IDs. An empty array means all snacks run.

### Release pipeline

GitHub Actions (`.github/workflows/release.yaml`) triggers on `v*` tags: builds with xcodebuild, creates a DMG via `scripts/create-dmg.sh`, and publishes to GitHub Releases with auto-generated notes.
