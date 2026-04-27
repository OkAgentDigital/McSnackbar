# Snackbar - macOS Menu Bar Automation

A native macOS menu bar application for running AppleScript and shell scripts with uDos integration.

## 🚀 Quick Start

```bash
# Build and run in development mode
./launch.sh

# Run with debug output
./launch.sh --debug
```

## 📁 Project Structure

```
Snackbar/
├── Snackbar/              # Swift Package
│   ├── Package.swift      # Package manifest
│   ├── Sources/           # Swift source code
│   │   └── Snackbar/      # Main application
│   │       └── main.swift # Entry point
│   ├── Resources/         # App resources
│   │   ├── snacks.json    # Built-in snacks
│   │   ├── categories.json # Snack categories
│   │   └── ABOUT.md       # About information
│   └── Tests/             # Unit tests
│       └── SnackbarTests/
└── launch.sh             # Launch script
```

## 🎯 Features

### Current Implementation
- ✅ Native macOS menu bar app
- ✅ AppleScript execution
- ✅ Shell script execution
- ✅ Basic menu structure
- ✅ Keyboard shortcuts
- ✅ Launch script with bash validation

### Planned Features (from design)
- 📋 Snack categories and organization
- ⏰ Scheduling system
- ☁️ iCloud sync
- 🌓 Dark mode support
- 📤 Import/Export functionality
- ℹ️ About window
- 🔄 uDos feed integration
- 📡 MCP client support

## 🔧 Development

### Build
```bash
cd Snackbar
swift build
```

### Run
```bash
cd Snackbar
swift run
```

### Test
```bash
cd Snackbar
swift test
```

## 📋 Current Status

The app is currently in **development mode** with a basic working menu bar application. You should see a 🍔 icon in your menu bar with:

- Test Snack 1
- Test Snack 2
- Quit

Clicking either test snack will show a notification saying "Hello from Snackbar!".

## 🎨 Next Steps

To complete the full Snackbar application:

1. **Implement the full AppDelegate** with all menu items
2. **Add the Models** (Snack, Category, Schedule, FeedEntry)
3. **Implement Core Components** (MenuBuilder, SnackExecutor, etc.)
4. **Add SwiftUI Views** (Preferences, AddSnack, etc.)
5. **Implement uDos Integration** (FeedManager, MCPClient)
6. **Add Import/Export functionality**
7. **Implement iCloud sync**
8. **Add scheduling system**

## 🐛 Troubleshooting

### App doesn't appear in menu bar
- Check that the build succeeded
- Look for error messages in the console
- Try running with `swift run` directly

### Script validation errors
- Run `./launch.sh --debug` for detailed output
- Check bash-doctor validation with: `bash-doctor --file launch.sh`

### Missing resources
- Ensure all files are in the correct locations
- Check the Package.swift resource definitions

## 🔒 Permissions

The app may require these macOS permissions:
- **Automation**: To control other apps via AppleScript
- **Notifications**: To show notifications
- **Full Disk Access**: For some file operations

## 📄 License

MIT License - See ABOUT.md for details

---

**Snackbar is currently in development mode** - the full feature set from the design documents will be implemented in subsequent phases.