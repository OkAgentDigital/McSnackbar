#!/bin/bash

# Snackbar Launcher
# Double-click this file to launch Snackbar

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

echo "🍔 Launching Snackbar..."
echo "Building application..."

# Build the app
swift build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Starting Snackbar..."
    
    # Run the app in background
    swift run &
    
    echo "🚀 Snackbar is now running!"
    echo "Look for the 🍔 icon in your menu bar."
    echo "Features:"
    echo "  - Organized snacks by category"
    echo "  - Run All Enabled (⌘R)"
    echo "  - Add New Snack (⌘N)"
    echo "  - Import/Export (⌘⇧E)"
    echo "  - About & Preferences"
else
    echo "❌ Build failed. Check the console for errors."
    exit 1
fi

# Keep terminal open briefly to show messages
sleep 3