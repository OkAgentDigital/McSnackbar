#!/bin/zsh

# Run Snackbar directly from the build directory
cd "$(dirname "$0")" || exit 1

# Find the Snackbar executable
if [ -f "./.build/arm64-apple-macosx/debug/Snackbar" ]; then
    echo "Starting Snackbar from ./.build/arm64-apple-macosx/debug/Snackbar"
    ./.build/arm64-apple-macosx/debug/Snackbar &
    echo "Snackbar is running. Check the menu bar for the Snackbar icon."
    echo "Press Ctrl+C to stop the app."
    wait
elif [ -f "./.build/debug/Snackbar" ]; then
    echo "Starting Snackbar from ./.build/debug/Snackbar"
    ./.build/debug/Snackbar &
    echo "Snackbar is running. Check the menu bar for the Snackbar icon."
    echo "Press Ctrl+C to stop the app."
    wait
else
    echo "Error: Snackbar executable not found. Please build the project first."
    echo "Run: swift build --product Snackbar --configuration debug"
    exit 1
fi