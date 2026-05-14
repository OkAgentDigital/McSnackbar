#!/bin/zsh

# =============================================================================
# 🍔 Snackbar Dev Launcher
# =============================================================================
#
# Builds Snackbar from source and runs it silently (no .app bundle).
# Uses `swift run` so there's no Dock icon, no window popup.
#
# Auto-start on login:
#   ./Dev-Launch.command install-agent
#   (installs a LaunchAgent so Snackbar starts when you log in)
#
# Commands:
#   ./Dev-Launch.command           # Build (if needed) and launch
#   ./Dev-Launch.command --stop    # Stop running Snackbar
#   ./Dev-Launch.command --status  # Check if running
#   ./Dev-Launch.command --rebuild # Force rebuild and relaunch
#   ./Dev-Launch.command --logs    # Tail the log file
#   ./Dev-Launch.command install-agent   # Install login auto-start
#   ./Dev-Launch.command uninstall-agent # Remove login auto-start
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
LOG_FILE="/tmp/snackbar-dev.log"
PID_FILE="/tmp/snackbar-dev.pid"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ️${NC}  $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()   { echo -e "${RED}❌${NC}  $*"; }

build() {
    local force="${1:-false}"
    if [ "$force" = "true" ] || [ ! -f "$PROJECT_DIR/.build/arm64-apple-macosx/debug/Snackbar" ]; then
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
    build || return 1
    # Run directly — no .app bundle, no Dock icon, no window popup
    cd "$PROJECT_DIR" && swift run &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    sleep 2
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
    else
        warn "NOT running."
    fi
}

logs() { [ -f "$LOG_FILE" ] && tail -f "$LOG_FILE" || warn "No log file."; }

rebuild() { stop; sleep 1; build "true"; launch; }

install_agent() {
    local agent_path="$HOME/Library/LaunchAgents/com.udos.snackbar.dev.plist"
    cat > "$agent_path" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.udos.snackbar.dev</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>~/Code/Apps/Snackbar/Dev-Launch.command start 2>&amp;1 &gt;/tmp/snackbar-launchagent.log</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
    <key>StandardOutPath</key><string>/tmp/snackbar-launchagent.log</string>
    <key>StandardErrorPath</key><string>/tmp/snackbar-launchagent.log</string>
    <key>WorkingDirectory</key><string>~/Code/Apps/Snackbar</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin</string>
        <key>HOME</key><string>~</string>
    </dict>
</dict></plist>
PLIST
    chmod 644 "$agent_path"
    launchctl load "$agent_path" 2>/dev/null
    ok "LaunchAgent installed at $agent_path"
    ok "Snackbar will auto-start on login (silent, no Dock icon)."
}

uninstall_agent() {
    local p="$HOME/Library/LaunchAgents/com.udos.snackbar.dev.plist"
    if [ -f "$p" ]; then
        launchctl unload "$p" 2>/dev/null
        rm "$p"
        ok "LaunchAgent removed."
    else
        warn "No LaunchAgent found."
    fi
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
