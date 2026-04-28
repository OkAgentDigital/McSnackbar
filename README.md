# 🍔 Snackbar for macOS

**Phase 1: Lightweight menu bar automation tool with 6 built-in snacks.**

## ✨ Features (Phase 1 - Current)
- Native macOS menu bar app (Swift/AppKit)
- **6 Original Snacks** - Pre-configured automations:
  - 📋 Reminders
  - ✉️ Mail VIP
  - 👥 Contacts
  - 📓 Notes
  - 📅 Calendar
  - 🔐 Permissions Helper
- Status bar menu with category organization
- Menu items: About, Settings, Close, Quit
- Run All Enabled functionality

## 🚀 Quick Start

### Prerequisites
- Xcode 14.0+
- macOS 12.0+ (Monterey or later)
- Swift 5.7+

### Launch Using Dev Launcher

Double-click **`Dev-Launch.command`** in Finder, or run from Terminal:

```bash
./Dev-Launch.command
```

This will:
- Clean previous builds
- Build the app using xcodebuild
- Launch Snackbar in Debug mode
- Save logs to `snackbar_dev.log`

### Manual Build

1. Open the Xcode project:
   ```bash
   open Snackbar.xcodeproj
   ```

2. Select the **Snackbar** scheme

3. Build and run (⌘R)

4. Click the **🍔** or **note.text** icon in your menu bar

## 📋 Usage

### Accessing Snacks
1. Click the menu bar icon
2. Navigate to a category (Productivity, Communication, System)
3. Click any snack to execute it

### Batch Execution
- Click **⚡ Run All Enabled** to execute all 6 snacks sequentially
- Each snack will show a notification upon completion

### Menu Items
- **⚡ Run All Enabled** - Execute all enabled snacks
- **➕ Add New Snack...** - Add custom snacks (Coming Soon)
- **📁 Import/Export...** - Manage snack collections (Coming Soon)
- **ℹ️ About Snackbar** - Show version and info
- **⚙️ Settings...** - Open preferences (Coming Soon)
- **🔒 Close** - Close the menu
- **✕ Quit** - Quit the application

## 📊 Snacks Reference

### Productivity
| Snack | Description | Runtime |
|-------|-------------|---------|
| **Reminders** | Opens Reminders app | AppleScript |
| **Notes** | Opens Notes app | AppleScript |
| **Calendar** | Opens Calendar app | AppleScript |

### Communication
| Snack | Description | Runtime |
|-------|-------------|---------|
| **Mail VIP** | Counts VIP emails in inbox | AppleScript |
| **Contacts** | Opens Contacts app | AppleScript |

### System
| Snack | Description | Runtime |
|-------|-------------|---------|
| **Permissions Helper** | Opens macOS Permissions settings | Shell |

## 📁 Project Structure

```
Snackbar/
├── Dev-Launch.command          # ✅ Primary launcher (Phase 1)
├── Snackbar.xcodeproj           # Xcode project
├── Package.swift                # Swift Package Manager config
├── Resources/
│   ├── snacks.json             # 6 pre-configured snacks
│   ├── categories.json          # Snack category definitions
│   ├── Info.plist              # App metadata
│   └── Snackbar.sdef           # AppleScript support
│
├── Sources/
│   ├── Snackbar/               # Core implementation
│   │   ├── Core/
│   │   │   ├── AppDelegate.swift     # App entry point
│   │   │   ├── MenuBuilder.swift     # Status bar menu
│   │   │   ├── SnackExecutor.swift   # Snack execution
│   │   │   ├── FeedManager.swift     # Execution logging
│   │   │   └── SnackScheduler.swift  # Future: Scheduled execution
│   │   └── Models/
│   │       ├── Snack.swift           # Snack data model
│   │       ├── Category.swift        # Category definitions
│   │       └── Schedule.swift        # Scheduling support
│   └── macOS/
│       ├── UI/
│       │   ├── SnackbarApp.swift    # SwiftUI app (alternate)
│       │   └── ContentView.swift     # Main UI (alternate)
│       └── Automations/              # App Intents
│
├── DevStudio/                   # DevStudio integration configs
├── Scripts/                     # Build and utility scripts
├── CONSOLIDATED_SUMMARY.md      # Current implementation details
└── ROADMAP.md                   # Development roadmap
```

### Key Files
| File | Purpose |
|------|---------|
| `AppDelegate.swift` | Main app delegate, status bar setup |
| `MenuBuilder.swift` | Builds status bar menu with snacks |
| `SnackExecutor.swift` | Executes AppleScript and Shell snacks |
| `Snack.swift` | Data model for snacks |
| `Category.swift` | Category definitions and colors |
| `snacks.json` | JSON config for 6 built-in snacks |
| `categories.json` | Category definitions |

## 📁 Resources

### snacks.json
Contains 6 pre-configured snacks organized by category:
- **productivity**: Reminders, Notes, Calendar
- **communication**: Mail VIP, Contacts
- **system**: Permissions Helper

Each snack has:
- `id` - Unique identifier
- `name` - Display name
- `description` - Help text
- `emoji` - Menu icon
- `code` - Execution code (AppleScript or Shell)
- `runtime` - "appleScript" or "shell"
- `categoryId` - Category grouping
- `isEnabled` - Whether snack is active

### categories.json
Defines 5 categories:
- Productivity (🚀, #FF6B6B)
- Communication (💬, #4ECDC4)
- Organization (📂, #45B7D1)
- System (⚙️, #96CEB4)
- Custom (✨, #FFEAA7)

## 🔧 Development

### DevStudio Integration (Phase 2)
> Note: iCloud sync, MCP integration, and advanced features are planned for Phase 2

Config files are synced between:
- `~/.config/udos/snackbar.yaml` (Snackbar)
- `~/Code/DevStudio/configs/snackbar.yaml` (DevStudio)

Example Phase 2 config:
```yaml
# Snackbar Configuration (Phase 2)
lechat:
  enabled: true
  api_key: "your-key"
  api_url: "https://api.lechat.ai"

sync:
  icloud: true
  vault_path: "~/Vault/notes/"
```

### Building

#### Build for Release
```bash
xcodebuild -project Snackbar.xcodeproj -scheme Snackbar -configuration Release
```

#### Build & Run (Debug)
Use the Dev-Launch.command or:
```bash
xcodebuild -project Snackbar.xcodeproj -scheme Snackbar -configuration Debug
```

## 📊 Development Status

### Phase 1: Consolidation ✅ COMPLETE
- [x] Unified codebase (MainSpine merged)
- [x] 6 original snacks working
- [x] Menu bar with status icon
- [x] Menu items: About, Settings, Close, Quit
- [x] Category organization
- [x] Dev-Launch.command with logging and auto-rebuild

### Phase 2: Polish (Planned)
- [ ] Snack execution logging
- [ ] Improved error messages
- [ ] Snack enable/disable
- [ ] UI polish
- [ ] Preferences system
- [ ] About window
- [ ] Import/export snacks

### Phase 3: Advanced Features (Future)
- [ ] iCloud sync for notes
- [ ] DevStudio MCP integration
- [ ] New snack types
- [ ] Scheduled execution

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## 📄 License

MIT
