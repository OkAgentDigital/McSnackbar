# 🍔 Snackbar - Project Structure

## 📁 Simplified Structure

```
Snackbar/
├── Package.swift            # Swift Package Manager configuration
├── Sources/
│   └── Snackbar/           # Main application source code
│       ├── Models/        # Data models
│       │   ├── Category.swift
│       │   ├── FeedEntry.swift
│       │   ├── Schedule.swift
│       │   └── Snack.swift
│       ├── Core/           # Core components
│       │   ├── AppDelegate.swift
│       │   ├── FeedManager.swift
│       │   ├── MenuBuilder.swift
│       │   ├── PermissionsManager.swift
│       │   ├── SnackExecutor.swift
│       │   └── SnackScheduler.swift
│       └── main.swift      # Entry point (empty - uses @main)
├── Resources/              # Application resources
│   ├── ABOUT.md           # About information
│   ├── categories.json    # Snack categories
│   └── snacks.json        # Built-in snacks
├── Snackbar.command       # Double-clickable launcher
├── launch.sh             # Original launch script
├── LAUNCH_INSTRUCTIONS.md # Launch instructions
├── PROJECT_STRUCTURE.md  # This file
├── README.md             # Project overview
└── SNACKBAR_SUMMARY.md    # Complete summary
```

## 🎯 Design Philosophy

**"One product with multiple 'snacks'"** - This structure reflects the core concept:

- **Snackbar** = The main application (menu bar app)
- **Snacks** = Individual automation scripts (AppleScript/shell)
- **Categories** = Organization system for snacks

## 🔧 Key Components

### Models
- **Snack**: Represents an individual automation script
- **Category**: Organizes snacks by type (Productivity, Communication, etc.)
- **Schedule**: Time-based execution rules
- **FeedEntry**: Execution logging and history

### Core Systems
- **AppDelegate**: Main application lifecycle manager
- **MenuBuilder**: Constructs the dynamic menu bar menu
- **SnackExecutor**: Executes AppleScript and shell scripts
- **FeedManager**: Logs execution history
- **SnackScheduler**: Handles scheduled execution
- **PermissionsManager**: Manages macOS permissions

### Resources
- **snacks.json**: Built-in automation scripts
- **categories.json**: Category definitions with emojis and colors
- **ABOUT.md**: Application information

## 🚀 Launch Methods

### 1. Double-Click (Recommended)
Double-click `Snackbar.command` in Finder

### 2. Terminal
```bash
cd /Users/fredbook/Code/Apps/Snackbar
./Snackbar.command
```

### 3. Direct Swift
```bash
cd /Users/fredbook/Code/Apps/Snackbar
swift run
```

## 📋 Development Workflow

### Build
```bash
swift build
```

### Run
```bash
swift run
```

### Clean
```bash
swift package clean
```

### Test
```bash
swift test
```

## 🎨 Architecture Principles

1. **Single Responsibility**: Each component has one clear purpose
2. **Modular Design**: Easy to add/remove features
3. **Resource Fallback**: Graceful degradation if resources missing
4. **Error Handling**: Comprehensive error management
5. **Extensibility**: Designed for future growth

## 🔮 Future Expansion

The structure supports adding:
- **New Snack Types**: Add to snacks.json or create programmatically
- **New Categories**: Add to categories.json
- **New Features**: Add new Core components
- **New Views**: Add SwiftUI windows as needed

## 📚 File Purpose Guide

- **Package.swift**: Swift Package Manager configuration
- **Snackbar.command**: User-friendly double-click launcher
- **launch.sh**: Original bash launch script
- **LAUNCH_INSTRUCTIONS.md**: Step-by-step launch guide
- **PROJECT_STRUCTURE.md**: This file - structure documentation
- **README.md**: Project overview and status
- **SNACKBAR_SUMMARY.md**: Complete feature summary

**Everything is organized, clean, and ready for expansion!** 🍔🚀