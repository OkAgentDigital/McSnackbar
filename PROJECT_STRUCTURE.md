# Snackbar Project Structure

```
Snackbar/
├── Package.swift                          # Swift Package Manager (3 targets + tests)
├── config.yaml                            # Runtime configuration
├── project.yml                            # XcodeGen project spec
│
├── Sources/
│   ├── Snackbar/                          # 🍔 macOS Menu Bar App (executable)
│   │   ├── main.swift                     # Entry point: NSApplication.run()
│   │   ├── Core/
│   │   │   ├── AppDelegateV2.swift        # App lifecycle, menu bar setup, preferences
│   │   │   ├── FeedManager.swift          # Execution logging + LeChat Pro API
│   │   │   ├── HivemindClient.swift       # HTTP JSON-RPC MCP client → HivemindRust:30000
│   │   │   ├── MCPServer.swift            # Native MCP server (port 8765, Apple 2024-11-05)
│   │   │   ├── MenuBuilder.swift          # Menu bar construction
│   │   │   ├── NuggetManager.swift        # .nug archive pack/unpack
│   │   │   ├── RulesManager.swift         # Automation rules CRUD + triggers
│   │   │   ├── SnackExecutorV2.swift      # AppleScript + shell runtime
│   │   │   ├── SnackManager.swift         # Snack CRUD, .snack YAML parsing
│   │   │   ├── SpoolManager.swift         # Append-only JSONL ledger
│   │   │   ├── TaskManager.swift          # Ordered task scheduling + retry
│   │   │   ├── UbuntuProxy.swift          # SSH proxy → wizard@192.168.20.11
│   │   │   ├── UpdateChecker.swift        # GitHub release version check
│   │   │   └── XcodeBuildService.swift    # Build Xcode/Rust projects
│   │   └── Models/
│   │       ├── SpoolEntry.swift           # Spool ledger entry model
│   │       └── uDosComponent.swift        # (deprecated — kept for reference)
│   │
│   ├── Core/                              # 📚 SnackbarCore Library
│   │   ├── Models/
│   │   │   ├── DevToolsConfig.swift       # DevStudio configuration model
│   │   │   └── Note.swift                 # Note model for iCloud sync
│   │   └── Services/
│   │       ├── DevStudioConfigManager.swift  # DevStudio config management
│   │       ├── DevStudioSkillTrigger.swift   # Trigger DevStudio skills
│   │       ├── DevToolsManager.swift         # DevTools orchestration
│   │       ├── MCPClient.swift               # MCP client for DevStudio
│   │       ├── NoteManager.swift             # Note CRUD + iCloud sync
│   │       ├── SyncStatusMonitor.swift       # iCloud sync status tracking
│   │       └── iCloudSyncManager.swift       # iCloud sync orchestration
│   │
│   └── macOS/                            # 🎯 SnackbarAutomations
│       ├── Automations/
│       │   ├── CreateNoteIntent.swift         # Shortcuts intent
│       │   ├── SnackbarAppleScriptHandler.swift # AppleScript handler
│       │   ├── SnackbarShortcuts.swift        # Shortcuts integration
│       │   ├── SyncNotesIntent.swift          # Shortcuts intent
│       │   └── TriggerDevStudioSkillIntent.swift # Shortcuts intent
│       └── UI/
│           ├── ContentView.swift              # SwiftUI preferences view
│           └── SnackbarApp.swift              # SwiftUI app entry
│
├── Resources/
│   ├── Info.plist                         # App info
│   ├── Snackbar.entitlements              # Sandbox entitlements
│   ├── Snackbar.sdef                      # Scripting definition
│   ├── SnackbarCore-Info.plist            # Core library info
│   ├── categories.json                    # Snack categories
│   ├── snacks.json                        # Default snacks
│   ├── ABOUT.md                           # About content
│   ├── AppIcon.icns                       # App icon
│   └── XcodeExternalAgent.plist           # Xcode agent config
│
├── Scripts/
│   ├── build-snackbar.sh                  # Build script
│   ├── bump-version.sh                    # Version bump
│   ├── create-dmg.sh                      # DMG packaging
│   └── deploy.sh                          # Deployment script
│
├── Tests/
│   └── NoteManagerTests.swift             # Unit tests
│
├── Snackbar.xcodeproj/                    # Xcode project (XcodeGen generated)
│
├── ROADMAP.md                             # 🗺️ Project roadmap
├── V2_UPGRADE_PLAN.md                     # ✅ V2 consolidation plan
├── CONSOLIDATED_SUMMARY.md                # 📋 Architecture summary
├── SNACKBAR_SUMMARY.md                    # 📝 Feature summary
├── CLAUDE.md                              # 🤖 AI assistant context
├── LAUNCH_INSTRUCTIONS.md                 # 🚀 Launch guide
└── README.md                              # 📖 Project readme
```

## Target Dependencies

```
Snackbar (executable)
  └── SnackbarCore (library)
       └── (none — pure Swift)

SnackbarAutomations (library)
  └── SnackbarCore (library)

SnackbarTests (test)
  └── SnackbarCore (library)
```

## Key Ports

| Service | Port | Protocol |
|---------|------|----------|
| MCP Server (native Swift) | 8765 | HTTP SSE (Apple 2024-11-05) |
| Hivemind (Rust MCP gateway) | 30000 | HTTP JSON-RPC |
| Ubuntu backend (SSH) | 22 | SSH |
