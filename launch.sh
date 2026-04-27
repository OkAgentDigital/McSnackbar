#!/bin/bash

# Snackbar Launch Script
# Usage: ./launch.sh [--debug]

set -eo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the Snackbar directory
cd "$SCRIPT_DIR"

# Check if config.yaml exists
if [ ! -f "config.yaml" ]; then
    echo "❌ Configuration file config.yaml not found!"
    echo "   Please create a config.yaml file with your LeChat Pro API key."
    exit 1
fi

# Verify LeChat API configuration
if ! grep -q "lechat:" config.yaml; then
    echo "⚠️  Warning: LeChat API configuration not found in config.yaml"
    echo "   Snackbar will run without LeChat integration."
fi

# Check if --debug flag is passed
DEBUG_MODE=false
if [[ "$1" == "--debug" ]]; then
    DEBUG_MODE=true
    echo "🔍 Debug mode enabled"
fi

# Build the app
echo "🛠️ Building Snackbar..."
swift build

# Run the app
echo "🚀 Launching Snackbar..."
if [ "$DEBUG_MODE" = true ]; then
    swift run
else
    # Run in background so the terminal is free
    swift run >/dev/null 2>&1 &
    echo "✅ Snackbar is running in the background"
    echo "   Look for the 🍔 icon in your menu bar!"
fi