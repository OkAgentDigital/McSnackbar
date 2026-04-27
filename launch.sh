#!/bin/bash

# Snackbar Launch Script
# Usage: ./launch.sh [--debug] [--build]
#   --debug: Run in debug mode (no background)
#   --build: Build the app before launching (optional)

set -eo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the Snackbar directory
cd "$SCRIPT_DIR"

# Check for configuration in central location or locally
CENTRAL_CONFIG="$HOME/Code/Projects/Snackbar/config/config.yaml"
LOCAL_CONFIG="$SCRIPT_DIR/config.yaml"

if [ -f "$CENTRAL_CONFIG" ]; then
    CONFIG_PATH="$CENTRAL_CONFIG"
elif [ -f "$LOCAL_CONFIG" ]; then
    CONFIG_PATH="$LOCAL_CONFIG"
else
    echo "❌ Configuration file not found at $CENTRAL_CONFIG or $LOCAL_CONFIG!"
    echo "   Please create a config.yaml file with your LeChat Pro API key."
    exit 1
fi

# Verify LeChat API configuration
if ! grep -q "lechat:" "$CONFIG_PATH"; then
    echo "⚠️  Warning: LeChat API configuration not found in config.yaml"
    echo "   Snackbar will run without LeChat integration."
fi

# Check if --debug or --build flag is passed
DEBUG_MODE=false
BUILD_MODE=false
if [[ "$1" == "--debug" ]]; then
    DEBUG_MODE=true
    echo "🔍 Debug mode enabled"
elif [[ "$1" == "--build" ]]; then
    BUILD_MODE=true
    echo "🛠️ Build mode enabled"
fi

# Build the app if --build flag is passed
if [ "$BUILD_MODE" = true ]; then
    echo "🛠️ Building Snackbar..."
    swift build
fi

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