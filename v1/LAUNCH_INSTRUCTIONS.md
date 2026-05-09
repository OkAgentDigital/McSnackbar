# 🍔 Snackbar Launch Instructions

## Quick Launch

**Double-click** the `Snackbar.command` file in Finder to launch Snackbar Pro.

## Alternative Launch Methods

### Terminal Launch
```bash
cd /Users/fredbook/Code/Apps/Snackbar
./launch_pro.sh
```

### Direct Swift Launch
```bash
cd /Users/fredbook/Code/Apps/Snackbar/SnackbarPro
swift run
```

## What to Expect

1. **Build Process**: The app will compile (takes a few seconds)
2. **Menu Bar Icon**: A 🍔 (hamburger) icon appears in your menu bar
3. **Full Menu**: Click the icon to see all features organized by category

## Features Available

- **⚡ Run All Enabled** - Execute all enabled snacks at once
- **➕ Add New Snack** - Placeholder (shows what this feature will do)
- **📁 Import/Export** - Placeholder (shows what this feature will do)
- **📋 Productivity Snacks** - Reminders, Notes, Calendar
- **💬 Communication Snacks** - Mail VIP, Contacts
- **⚙️ System Snacks** - Permissions Helper
- **ℹ️ About Snackbar** - Shows version information
- **⚙️ Preferences** - Placeholder (shows what this feature will do)

## Troubleshooting

### App doesn't appear
- Check Terminal for error messages
- Run `pkill -f "Snackbar"` to kill any stuck processes
- Try launching again

### Menu bar icon missing
- The app might need accessibility permissions
- Check System Preferences > Security & Privacy > Privacy > Automation

### Build errors
- Make sure you have Xcode command line tools installed
- Run `xcode-select --install` if needed

## Stopping the App

Click **Quit** in the Snackbar menu, or run:
```bash
pkill -f "Snackbar"
```

---

**Enjoy your expanded Snackbar!** 🎉
When you're ready to implement the remaining features (SwiftUI views, uDos integration, etc.), just let me know!