#!/bin/zsh

# Run Snackbar silently - no terminal window after launch
# Uses nohup and redirects output to a log file

cd "$(dirname "$0")" || exit 1

BINARY=""
LOG_DIR="$HOME/Library/Logs/Snackbar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/snackbar.log"

if [ -f "./.build/arm64-apple-macosx/debug/Snackbar" ]; then
    BINARY="./.build/arm64-apple-macosx/debug/Snackbar"
elif [ -f "./.build/debug/Snackbar" ]; then
    BINARY="./.build/debug/Snackbar"
else
    echo "Error: Snackbar executable not found." >> "$LOG_FILE"
    exit 1
fi

# Launch with nohup, detach from terminal
nohup "$BINARY" > "$LOG_FILE" 2>&1 &
disown

echo "Snackbar launched silently (PID: $!)"
echo "Logs: $LOG_FILE"
