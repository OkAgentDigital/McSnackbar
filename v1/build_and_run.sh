#!/bin/zsh

# Build and run Snackbar (silent mode — no terminal window)
cd "$(dirname "$0")" || exit 1

echo "Building Snackbar..."
swift build --configuration debug

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Running Snackbar (silent mode)..."
exec "$(dirname "$0")/run_snackbar_silent.sh" start
