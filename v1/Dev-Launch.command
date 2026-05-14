#!/bin/zsh

# =============================================================================
# 🍔 Snackbar Dev Launcher
# =============================================================================
#
# Builds Snackbar from source and runs it in debug mode (no code signing).
# Dogfooding tool for everyday development.
#
# Installation:
#   chmod +x Dev-Launch.command
#   ./Dev-Launch.command
#
# To add to macOS Login Items:
#   System Settings → General → Login Items → Click + → Select this file
#   Or: ./Dev-Launch.command install-agent  (uses launchd)
#
# Commands:
#   ./Dev-Launch.command           # Build (if needed) and launch
#   ./Dev-Launch.command --stop    # Stop running Snackbar
#   ./Dev-Launch.command --status  # Check if running
#   ./Dev-Launch.command --rebuild # Force rebuild and relaunch
#   ./Dev-Launch.command --logs    # Tail the log file
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
SNACKBAR_BINARY="$PROJECT_DIR/.build/arm64-apple-macosx/debug/Snackbar"
SNACKBAR_APP="$PROJECT_DIR/Snackbar.app"
LOG_FILE="/tmp/snackbar-dev.log"
PID_FILE="/tmp/snackbar-dev.pid"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ️${NC}  $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()   { echo -e "${RED}❌${NC}  $*"; }

build() {
    local force="${1:-false}"
    if [ "$force" = "true" ] || [ ! -f "$SNACKBAR_BINARY" ]; then
        info "Building Snackbar (debug mode)..."
        cd "$PROJECT_DIR" || exit 1
        swift build --configuration debug 2>&1 | tee -a "$LOG_FILE"
        local exit_code=$?
        [ $exit_code -ne 0 ] && { err "Build failed."; return 1; }
        ok "Build complete."
    else
        info "Using existing build (pass --rebuild to force)."
    fi
}

launch() {
    # Build and update the .app bundle
    build || return 1
    # Update the .app bundle with the new binary and resources
    mkdir -p "$SNACKBAR_APP/Contents/MacOS"
    mkdir -p "$SNACKBAR_APP/Contents/Resources"
    cp "$SNACKBAR_BINARY" "$SNACKBAR_APP/Contents/MacOS/Snackbar"
    find "$PROJECT_DIR/Sources/Snackbar/Assets.xcassets" -name "*.svg" -exec cp {} "$SNACKBAR_APP/Contents/Resources/" \;
    # Launch via .app bundle (silent, no terminal)
    open "$SNACKBAR_APP" -g
    local pid=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    echo "$pid" > "$PID_FILE"
    ok "Snackbar running (PID: $pid) — menu bar icon should appear."
    return 0
}

start() {
    [ -f "$PID_FILE" ] && { local pid=$(cat "$PID_FILE" 2>/dev/null); [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && { ok "Already running (PID: $pid)"; return 0; }; rm -f "$PID_FILE"; }
    local pid=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    [ -n "$pid" ] && { echo "$pid" > "$PID_FILE"; ok "Already running (PID: $pid)"; return 0; }
    launch
}

stop() {
    local pid; [ -f "$PID_FILE" ] && { pid=$(cat "$PID_FILE" 2>/dev/null); rm -f "$PID_FILE"; }
    [ -z "$pid" ] && pid=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    [ -z "$pid" ] && { warn "Not running."; return 0; }
    info "Stopping (PID: $pid)..."; kill "$pid" 2>/dev/null; sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    ok "Stopped."
}

status() {
    local pid=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    if [ -n "$pid" ]; then
        ok "RUNNING (PID: $pid)"
        command -v lsof &>/dev/null && lsof -i :8765 2>/dev/null | grep -q LISTEN && ok "MCP: :8765" || warn "MCP: not listening"
    else
        warn "NOT running."
    fi
}

logs() { [ -f "$LOG_FILE" ] && tail -f "$LOG_FILE" || warn "No log file."; }

rebuild() { build "true"; stop; sleep 1; launch; }

install_agent() {
    cat > "$HOME/Library/LaunchAgents/com.udos.snackbar.dev.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.udos.snackbar.dev</string>
    <key>ProgramArguments</key>
    <array><string>/bin/zsh</string><string>-c</string><string>~/Code/Apps/Snackbar/Dev-Launch.command</string></array>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>/tmp/snackbar-launchagent.log</string>
    <key>StandardErrorPath</key><string>/tmp/snackbar-launchagent.log</string>
    <key>WorkingDirectory</key><string>~/Code/Apps/Snackbar</string>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin</string></dict>
</dict></plist>
PLIST
    chmod 644 "$HOME/Library/LaunchAgents/com.udos.snackbar.dev.plist"
    launchctl load "$HOME/Library/LaunchAgents/com.udos.snackbar.dev.plist" 2>/dev/null
    ok "LaunchAgent installed. Snackbar will auto-start on login."
}

uninstall_agent() {
    local p="$HOME/Library/LaunchAgents/com.udos.snackbar.dev.plist"
    [ -f "$p" ] && { launchctl unload "$p" 2>/dev/null; rm "$p"; ok "Agent removed."; } || warn "No agent found."
}

echo ""; echo -e "${CYAN}┌─────────────────────────────────┐${NC}"
echo -e "${CYAN}│  🍔  ${NC}Snackbar Dev Mode${CYAN}               │${NC}"
echo -e "${CYAN}└─────────────────────────────────┘${NC}"; echo ""

case "${1:-start}" in
    start|--start) start ;;
    stop|--stop) stop ;;
    restart|--restart) stop; sleep 1; start ;;
    status|--status) status ;;
    logs|--logs) logs ;;
    rebuild|--rebuild) rebuild ;;
    install-agent) install_agent ;;
    uninstall-agent) uninstall_agent ;;
    *) echo "Usage: $0 {start|stop|restart|status|logs|rebuild|install-agent|uninstall-agent}"; exit 1 ;;
esac
echo ""; exit 0
