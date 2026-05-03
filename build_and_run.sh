#!/bin/zsh

# Build and run Snackbar
cd "$(dirname "$0")" || exit 1

echo "Building Snackbar..."
swift build --configuration debug

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Running Snackbar..."
./.build/debug/snackbar &

echo "Snackbar is running. Check the menu bar for the Snackbar icon."
echo "Press Ctrl+C to stop the app."

# Keep the script running so the app doesn't get killed
wait