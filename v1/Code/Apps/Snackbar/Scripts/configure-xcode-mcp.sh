#!/bin/bash
# =============================================================================
# ⚡ Snackbar Xcode MCP Configuration Script
# =============================================================================
#
# Configures Xcode to connect to Snackbar's MCP server and HivemindRust.
# Writes the MCP server config to the Xcode MCP directory.
#
# Usage:
#   ./Scripts/configure-xcode-mcp.sh              # Write config
#   ./Scripts/configure-xcode-mcp.sh --verify      # Check current config
#   ./Scripts/configure-xcode-mcp.sh --remove      # Remove config
#
# =============================================================================

set -euo pipefail

XCODE_MCP_DIR="$HOME/Library/Developer/Xcode/MCP"
CONFIG_FILE="$XCODE_MCP_DIR/snackbar.json"
SNACKBAR_DIR="$(cd "$(dirname "$0")/.." && pwd)"

info()  { echo -e "\033[0;36mℹ️\033[0m  $*"; }
ok()    { echo -e "\033[0;32m✅\033[0m $*"; }
warn()  { echo -e "\033[1;33m⚠️\033[0m  $*"; }
err()   { echo -e "\033[0;31m❌\033[0m  $*"; }

write_config() {
    mkdir -p "$XCODE_MCP_DIR"

    cat > "$CONFIG_FILE" << 'CONFIGEOF'
{
  "mcpServers": {
    "snackbar": {
      "type": "http",
      "url": "http://localhost:8765"
    },
    "hivemind": {
      "type": "http",
      "url": "http://localhost:3010/mcp"
    },
    "xcode": {
      "command": "xcrun",
      "args": ["mcpbridge"]
    }
  }
}
CONFIGEOF

    ok "Config written to $CONFIG_FILE"
    info "Restart Xcode to pick up changes."
    info ""
    info "Xcode will see these MCP servers:"
    info "  🍔 Snackbar  → http://localhost:8765  (snacks, spool, vault)"
    info "  🧠 Hivemind  → http://localhost:3010  (LLM, tools)"
    info "  ⚡ Xcode      → xcrun mcpbridge         (build, test)"
}

verify_config() {
    if [ -f "$CONFIG_FILE" ]; then
        ok "MCP config exists at $CONFIG_FILE"
        echo ""
        cat "$CONFIG_FILE"
        echo ""
        
        # Check if servers are actually running
        info "Checking server availability..."
        
        if curl -s -o /dev/null -w '%{http_code}' http://localhost:8765/ 2>/dev/null | grep -q 200; then
            ok "Snackbar MCP (:8765) — responding"
        else
            warn "Snackbar MCP (:8765) — not responding (running Snackbar?)"
        fi
        
        if curl -s -o /dev/null -w '%{http_code}' http://localhost:3010/health 2>/dev/null | grep -q 200; then
            ok "Hivemind MCP (:3010) — responding"
        else
            warn "Hivemind MCP (:3010) — not responding (run Dev-Launch to start it)"
        fi
    else
        warn "No MCP config found at $CONFIG_FILE"
        info "Run without arguments to create it."
    fi
}

remove_config() {
    if [ -f "$CONFIG_FILE" ]; then
        rm "$CONFIG_FILE"
        ok "Removed $CONFIG_FILE"
    else
        warn "No config to remove."
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-write}" in
    write|--write)
        write_config
        ;;
    verify|--verify|status|--status)
        verify_config
        ;;
    remove|--remove)
        remove_config
        ;;
    *)
        echo "Usage: $0 {write|verify|remove}"
        exit 1
        ;;
esac
