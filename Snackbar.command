#!/bin/bash

# Snackbar.command
# Double-clickable launcher for Snackbar (SPM build)
# Launches the full-featured Snackbar app via Swift Package Manager

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🍔 Snackbar Launcher"
echo "==================="
echo ""

# Open Terminal so the user sees output
if [ -z "$TERM_PROMPT" ] && [ -z "$TERM_PROGRAM" ]; then
    # Launched from Finder — reopen in Terminal
    osascript -e "tell application \"Terminal\" to do script \"cd '$SCRIPT_DIR' && echo '🍔 Snackbar - Building...' && swift run Snackbar\""
    exit 0
fi

echo "Building Snackbar via Swift..."

if swift run Snackbar 2>&1; then
    echo ""
    echo "✅ Snackbar launched! Look for the 🍔 icon in your menu bar."
else
    echo ""
    echo "❌ Build failed. Check the error messages above."
    echo "Make sure you have Swift 5.7+ installed (run: xcode-select --install)"
    read -r -p "Press Enter to close..."
    exit 1
fi
