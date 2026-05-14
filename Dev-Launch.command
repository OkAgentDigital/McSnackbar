#!/bin/zsh

# =============================================================================
# 🍔 Snackbar Dev Launcher (v2)
# =============================================================================
#
# Builds Snackbar from source and runs it as a menu bar app.
# Creates a proper .app bundle wrapper for clean launching.
#
# Commands:
#   ./Dev-Launch.command           # Build (if needed) and launch
#   ./Dev-Launch.command --stop    # Stop running Snackbar
#   ./Dev-Launch.command --status  # Check if running
#   ./Dev-Launch.command --rebuild # Force rebuild and relaunch
#   ./Dev-Launch.command --logs    # Tail the log file
#   ./Dev-Launch.command --xcode   # Open in Xcode for archiving
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
LOG_FILE="/tmp/snackbar-dev.log"
PID_FILE="/tmp/snackbar-dev.pid"
BUNDLE_ID="com.udos.snackbar"

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

create_app_bundle() {
    local binary="$PROJECT_DIR/.build/arm64-apple-macosx/debug/Snackbar"
    local app_dir="$PROJECT_DIR/.build/Snackbar.app"

    if [ ! -f "$binary" ]; then
        err "Binary not found. Run build first."
        return 1
    fi

    # Create .app bundle structure
    mkdir -p "$app_dir/Contents/MacOS"
    mkdir -p "$app_dir/Contents/Resources"

    # Copy binary
    cp "$binary" "$app_dir/Contents/MacOS/Snackbar"

    # Convert SVG icons to PNG and copy to Resources
    # NSImage(contentsOf:) doesn't reliably load SVGs, so we use sips to render PNGs
    local icon_dir="$PROJECT_DIR/MacSnackbar/MacSnackbar/Assets.xcassets/Mono Icons"

    for svg in "$icon_dir"/*.imageset/*.svg; do
        local name=$(basename "$svg" .svg)
        local png_out="$app_dir/Contents/Resources/${name}.png"
        # sips can convert SVG to PNG on macOS
        sips -s format png "$svg" --out "$png_out" 2>/dev/null || {
            # Fallback: just copy the SVG
            cp "$svg" "$app_dir/Contents/Resources/"
        }
    done

    # Create Info.plist for the .app bundle
    cat > "$app_dir/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Snackbar</string>
    <key>CFBundleIdentifier</key>
    <string>com.udos.snackbar</string>
    <key>CFBundleName</key>
    <string>Snackbar</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Snackbar needs to control Reminders, Mail, Contacts, Notes, and Calendar to show your data.</string>
</dict>
</plist>
PLIST

    ok "App bundle created at $app_dir"
    echo "$app_dir"
}

launch() {
    build || return 1
    create_app_bundle || return 1

    local app_dir="$PROJECT_DIR/.build/Snackbar.app"

    # Launch via .app bundle (silent, no Dock icon, no terminal)
    open "$app_dir" -g

    sleep 2
    local pid=$(pgrep -f "Snackbar" 2>/dev/null | grep -v "Dev-Launch\|grep" | head -1)
    if [ -n "$pid" ]; then
        echo "$pid" > "$PID_FILE"
        ok "Snackbar running (PID: $pid) — menu bar icon should appear."
    else
        err "Snackbar failed to start. Check logs: $LOG_FILE"
        return 1
    fi
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

open_xcode() {
    info "Opening Snackbar in Xcode..."
    open "$PROJECT_DIR/MacSnackbar/MacSnackbar.xcodeproj"
    ok "Xcode opened. Use Product → Archive to build a distributable .app"
}


echo ""; echo -e "${CYAN}┌─────────────────────────────────┐${NC}"
echo -e "${CYAN}│  🍔  ${NC}Snackbar Dev Launcher${CYAN}            │${NC}"
echo -e "${CYAN}└─────────────────────────────────┘${NC}"; echo ""

case "${1:-start}" in
    start|--start) start ;;
    stop|--stop) stop ;;
    restart|--restart) stop; sleep 1; start ;;
    status|--status) status ;;
    logs|--logs) logs ;;
    rebuild|--rebuild) rebuild ;;
    xcode|--xcode) open_xcode ;;
    *) echo "Usage: $0 {start|stop|restart|status|logs|rebuild|xcode}"; exit 1 ;;
esac
echo ""; exit 0
