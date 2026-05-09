#!/bin/bash
# =============================================================================
# 🍔 Snackbar Notarization Script
# =============================================================================
#
# Archives, signs, notarizes, and staples Snackbar for distribution.
#
# Prerequisites:
#   1. An active Apple Developer account (paid)
#   2. Xcode installed with command line tools
#   3. An App-Specific Password saved in your keychain:
#      xcrun notarytool store-credentials "AC_PASSWORD" \
#        --apple-id "your@email.com" \
#        --team-id "YOUR_TEAM_ID" \
#        --password "app-specific-password"
#
# Usage:
#   ./Scripts/notarize.sh                    # Full archive + notarize
#   ./Scripts/notarize.sh --skip-archive     # Notarize existing archive
#   ./Scripts/notarize.sh --status <uuid>    # Check notarization status
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="Snackbar"
PROJECT="$PROJECT_DIR/Snackbar.xcodeproj"
ARCHIVE_PATH="$PROJECT_DIR/build/Snackbar.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/Notarized"
EXPORT_OPTIONS="$SCRIPT_DIR/export-options.plist"
LOG_FILE="$PROJECT_DIR/build/notarize.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ️${NC}  $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()   { echo -e "${RED}❌${NC}  $*"; }

mkdir -p "$(dirname "$LOG_FILE")"

# ── Step 1: Archive ────────────────────────────────────────────────────

archive() {
    info "Archiving Snackbar (Release configuration)..."
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        clean archive \
        2>&1 | tee -a "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        ok "Archive created at $ARCHIVE_PATH"
    else
        err "Archive failed. Check $LOG_FILE for details."
        exit 1
    fi
}

# ── Step 2: Export for Notarization ────────────────────────────────────

export_app() {
    info "Exporting notarized app..."
    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        2>&1 | tee -a "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        ok "Exported to $EXPORT_PATH"
    else
        err "Export failed. Check $LOG_FILE for details."
        exit 1
    fi
}

# ── Step 3: Notarize ───────────────────────────────────────────────────

notarize() {
    local app_path="$EXPORT_PATH/$SCHEME.app"
    
    if [ ! -d "$app_path" ]; then
        err "App not found at $app_path. Run archive step first."
        exit 1
    fi

    info "Submitting $app_path for notarization..."
    info "This may take a few minutes..."

    # Compress the app for upload
    local zip_path="$EXPORT_PATH/$SCHEME.zip"
    ditto -c -k --keepParent "$app_path" "$zip_path"

    # Submit for notarization
    xcrun notarytool submit "$zip_path" \
        --keychain-profile "AC_PASSWORD" \
        --wait \
        2>&1 | tee -a "$LOG_FILE"

    local status=${PIPESTATUS[0]}
    if [ $status -eq 0 ]; then
        ok "Notarization submitted successfully!"
    else
        err "Notarization failed. Check $LOG_FILE for details."
        exit 1
    fi

    # Staple the ticket
    info "Stapling notarization ticket..."
    xcrun stapler staple "$app_path" 2>&1 | tee -a "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        ok "Notarization ticket stapled to $app_path"
    else
        warn "Stapling failed (may already be stapled)."
    fi

    # Verify
    info "Verifying notarization..."
    spctl --assess --verbose "$app_path" 2>&1 | tee -a "$LOG_FILE"
    
    ok "✅ Notarization complete! App is ready for distribution."
    echo ""
    echo "   📦 $app_path"
}

# ── Check Status ───────────────────────────────────────────────────────

check_status() {
    local uuid="$1"
    if [ -z "$uuid" ]; then
        err "Usage: $0 --status <submission-uuid>"
        exit 1
    fi
    xcrun notarytool info "$uuid" --keychain-profile "AC_PASSWORD"
}

# ── Main ───────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  🍔  Snackbar Notarization Tool${CYAN}            │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
echo ""

case "${1:-all}" in
    all|--all)
        archive
        export_app
        notarize
        ;;
    archive|--archive)
        archive
        ;;
    export|--export)
        export_app
        ;;
    notarize|--notarize)
        notarize
        ;;
    status|--status)
        check_status "${2:-}"
        ;;
    *)
        echo "Usage: $0 {all|archive|export|notarize|status}"
        exit 1
        ;;
esac

echo ""
exit 0
