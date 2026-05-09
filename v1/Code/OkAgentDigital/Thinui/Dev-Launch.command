#!/bin/zsh

# =============================================================================
# 🎁 GiftWrapper Dev Launcher (Dogfooding)
# =============================================================================
# 
# Builds GiftWrapper from source and runs it in dev mode.
# Dogfooding tool for everyday development.
#
# Installation:
#   chmod +x Dev-Launch.command
#   ./Dev-Launch.command
#
# Commands:
#   ./Dev-Launch.command           # Build (if needed) and launch
#   ./Dev-Launch.command --stop    # Stop running GiftWrapper
#   ./Dev-Launch.command --status  # Check if running
#   ./Dev-Launch.command --rebuild # Force rebuild and relaunch
#   ./Dev-Launch.command --web     # Launch web version only (no Tauri)
#   ./Dev-Launch.command --logs    # Tail the log file
#   ./Dev-Launch.command --install-agent # Install launchd auto-launch agent
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
LOG_FILE="/tmp/giftwrapper-dev.log"
PID_FILE="/tmp/giftwrapper-dev.pid"
WEB_PORT=4687

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ️${NC}  $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()   { echo -e "${RED}❌${NC}  $*"; }

build() {
    local force="${1:-false}"
    if [ "$force" = "true" ] || [ ! -f "$PROJECT_DIR/src-tauri/target/debug/giftwrapper" ]; then
        info "Building GiftWrapper (debug mode)..."
        cd "$PROJECT_DIR" || exit 1
        
        # Build frontend
        info "→ Building frontend..."
        npm install --silent 2>&1 | tail -1
        npm run build 2>&1 | tail -3
        
        # Build Tauri backend
        info "→ Building Tauri backend..."
        cargo build --manifest-path src-tauri/Cargo.toml 2>&1 | tee -a "$LOG_FILE" | tail -5
        local exit_code=$?
        [ $exit_code -ne 0 ] && { err "Build failed."; return 1; }
        ok "Build complete."
    else
        info "Using existing build (pass --rebuild to force)."
    fi
}

launch() {
    local binary="$PROJECT_DIR/src-tauri/target/debug/giftwrapper"
    [ ! -f "$binary" ] && binary="$PROJECT_DIR/src-tauri/target/debug/app"
    [ ! -f "$binary" ] && { err "Binary not found."; return 1; }
    
    cd "$PROJECT_DIR" || exit 1
    "$binary" >> "$LOG_FILE" 2>&1 &
    local pid=$!; echo $pid > "$PID_FILE"
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        ok "GiftWrapper running (PID: $pid)"
        return 0
    else
        err "Failed to start. Logs:"; tail -5 "$LOG_FILE"; return 1
    fi
}

launch_web() {
    info "Starting web-only GiftWrapper on http://localhost:$WEB_PORT ..."
    cd "$PROJECT_DIR" || exit 1
    npx vite --port $WEB_PORT --host >> "$LOG_FILE" 2>&1 &
    local pid=$!; echo $pid > "$PID_FILE"
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        ok "GiftWrapper web running (PID: $pid) at http://localhost:$WEB_PORT"
        return 0
    else
        err "Failed to start web."; tail -5 "$LOG_FILE"; return 1
    fi
}

start() {
    [ -f "$PID_FILE" ] && { local pid=$(cat "$PID_FILE" 2>/dev/null); [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && { ok "Already running (PID: $pid)"; return 0; }; rm -f "$PID_FILE"; }
    local pid=$(pgrep -f "giftwrapper\|GiftWrapper" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    [ -n "$pid" ] && { echo "$pid" > "$PID_FILE"; ok "Already running (PID: $pid)"; return 0; }
    build || return 1; launch
}

stop() {
    local pid; [ -f "$PID_FILE" ] && { pid=$(cat "$PID_FILE" 2>/dev/null); rm -f "$PID_FILE"; }
    [ -z "$pid" ] && pid=$(pgrep -f "giftwrapper\|GiftWrapper\|vite" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    [ -z "$pid" ] && { warn "Not running."; return 0; }
    info "Stopping (PID: $pid)..."; kill "$pid" 2>/dev/null; sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    ok "Stopped."
}

status() {
    local pid=$(pgrep -f "giftwrapper\|GiftWrapper" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    if [ -n "$pid" ]; then
        ok "GiftWrapper RUNNING (PID: $pid)"
        command -v lsof &>/dev/null && lsof -i :$WEB_PORT 2>/dev/null | grep -q LISTEN && ok "Web: :$WEB_PORT" || warn "Web: not listening"
    else
        warn "NOT running."
    fi
}

logs() { [ -f "$LOG_FILE" ] && tail -f "$LOG_FILE" || warn "No log file."; }

rebuild() { build "true"; stop; sleep 1; launch; }

install_agent() {
    cat > "$HOME/Library/LaunchAgents/com.okagentdigital.giftwrapper.dev.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.okagentdigital.giftwrapper.dev</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>~/Code/OkAgentDigital/Thinui/Dev-Launch.command</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>/tmp/giftwrapper-launchagent.log</string>
    <key>StandardErrorPath</key><string>/tmp/giftwrapper-launchagent.log</string>
    <key>WorkingDirectory</key><string>~/Code/OkAgentDigital/Thinui</string>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$HOME/.cargo/bin</string></dict>
</dict></plist>
PLIST
    chmod 644 "$HOME/Library/LaunchAgents/com.okagentdigital.giftwrapper.dev.plist"
    launchctl load "$HOME/Library/LaunchAgents/com.okagentdigital.giftwrapper.dev.plist" 2>/dev/null
    ok "LaunchAgent installed. GiftWrapper will auto-start on login."
}

uninstall_agent() {
    local p="$HOME/Library/LaunchAgents/com.okagentdigital.giftwrapper.dev.plist"
    [ -f "$p" ] && { launchctl unload "$p" 2>/dev/null; rm "$p"; ok "Agent removed."; } || warn "No agent found."
}

echo ""; echo -e "${CYAN}┌─────────────────────────────────┐${NC}"
echo -e "${CYAN}│  🎁  ${NC}GiftWrapper Dev Mode${CYAN}             │${NC}"
echo -e "${CYAN}└─────────────────────────────────┘${NC}"; echo ""

case "${1:-start}" in
    start|--start) start ;;
    stop|--stop) stop ;;
    restart|--restart) stop; sleep 1; start ;;
    status|--status) status ;;
    logs|--logs) logs ;;
    rebuild|--rebuild) rebuild ;;
    web|--web) launch_web ;;
    install-agent) install_agent ;;
    uninstall-agent) uninstall_agent ;;
    *) echo "Usage: $0 {start|stop|restart|status|logs|rebuild|install-agent|uninstall-agent}"; exit 1 ;;
esac
echo ""; exit 0
