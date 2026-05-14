# 🍔 Snackbar

A **menu-bar-only macOS app** that runs automations ("snacks") — AppleScripts on a timer — and displays their output as badges in the menu bar.

## Features

- **Menu bar badges** — monitor Reminders, Mail, Contacts, Notes, Calendar at a glance
- **Silent background operation** — no Dock icon, no windows, no popups
- **Sliding refresh intervals** — set per-snack from 5s to 5min
- **Spool viewer** — execution log with search, filter, and export
- **Launch at Startup** — native macOS login item (SMAppService)
- **Automatic updates** — periodic GitHub release check with download prompt
- **Append-only logging** — all executions recorded to JSONL spool

## Snacks

| Snack | Default | Script |
|-------|---------|--------|
| Reminders | Off | Counts incomplete reminders |
| Mail VIP | Off | Counts unread VIP emails |
| Contacts | Off | Lists VIP contacts |
| Notes | Off | Counts total notes |
| Calendar | Off | Counts today's events |

All snacks are **disabled by default**. Enable them from the menu bar to grant Automation permissions when first used.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.3+

## Quick Start

```bash
git clone https://github.com/OkAgentDigital/Snackbar.git
cd Snackbar
./Dev-Launch.command
```

## Commands

| Command | What it does |
|---|---|
| `./Dev-Launch.command` | Build & launch |
| `./Dev-Launch.command --stop` | Stop Snackbar |
| `./Dev-Launch.command --status` | Check if running |
| `./Dev-Launch.command --rebuild` | Force rebuild + relaunch |
| `./Dev-Launch.command --logs` | Tail logs |
| `./Dev-Launch.command install-agent` | Auto-start on login |
| `./Dev-Launch.command uninstall-agent` | Remove auto-start |

## Permissions

When you enable a snack for the first time, macOS will prompt you to grant **Automation** permission for Snackbar to control the target app. Grant these in:

**System Settings → Privacy & Security → Automation**

## Development

```bash
swift build
swift run
```

No Xcode project — pure SwiftPM. All source in `Sources/Snackbar/`.

## License

MIT — Copyright © 2025 uDos
