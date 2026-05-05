#!/bin/zsh

# 🎯 Snackbar Silent Launcher
# Opens the built .app bundle so it uses its Info.plist (LSUIElement = true)
# This means NO terminal window and NO dock icon — just the menu bar icon.
#
# Usage:
#   ./run_snackbar_silent.sh           # Build (if needed) and launch silently
#   ./run_snackbar_silent.sh --app     # Launch existing .app without rebuild
#   ./run_snackbar_silent.sh --raw     # Launch raw binary (shows terminal)
#   ./run_snackbar_silent.sh --stop    # Kill all Snackbar processes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ID="com.udos.snackbar"
LOG_DIR="$HOME/Library/Logs/Snackbar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/snackbar.log"

# ── Functions ──

build_if_needed() {
    local binary="./.build/arm64-apple-macosx/debug/Snackbar"
    [ -f "$binary" ] && return 0
    echo "Building Snackbar..."
    swift build --product Snackbar --configuration debug 2>&1 | tail -3
    return $?
}

launch_raw() {
    # Launch the raw binary directly (will show Terminal)
    local binary="./.build/arm64-apple-macosx/debug/Snackbar"
    [ -f "$binary" ] || binary="./.build/debug/Snackbar"
    [ ! -f "$binary" ] && { echo "Binary not found. Run 'swift build' first."; exit 1; }
    
    nohup "$binary" > "$LOG_FILE" 2>&1 &
    disown
    echo "✅ Snackbar launched (PID: $!) — raw mode (terminal visible)"
    echo "   Logs: $LOG_FILE"
}

launch_app() {
    # Use the SnackbarSilent.app wrapper (proper LSUIElement .app)
    local app_path="$SCRIPT_DIR/SnackbarSilent.app"
    
    if [ -d "$app_path" ]; then
        open "$app_path" -g  # -g = launch hidden (no activation)
        echo "✅ Snackbar launched via .app bundle (silent, no terminal)"
    else
        echo "⚠️ SnackbarSilent.app not found. Building .app..."
        # For now, use raw mode as fallback
        launch_raw
    fi
}

stop_snackbar() {
    local pids=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "run_\|grep")
    if [ -n "$pids" ]; then
        echo "Stopping Snackbar (PIDs: $(echo $pids | tr '\n' ' '))..."
        kill $pids 2>/dev/null
        sleep 1
        pids=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "run_\|grep")
        [ -n "$pids" ] && kill -9 $pids 2>/dev/null
        echo "✅ Stopped"
    else
        echo "ℹ️ Snackbar not running"
    fi
}

# ── Main ──

case "${1:-start}" in
    start|--app)
        build_if_needed || exit 1
        launch_app
        ;;
    raw|--raw)
        build_if_needed || exit 1
        launch_raw
        ;;
    stop|--stop)
        stop_snackbar
        ;;
    *)
        echo "Usage: $0 {start|--app|raw|--raw|stop|--stop}"
        exit 1
        ;;
esac
