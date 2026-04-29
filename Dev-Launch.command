#!/bin/bash

# Dev-Launch.command
# Snackbar Phase 1 Development Launcher
# Features: Auto-rebuild, logging, and dedicated for 6 snacks + menu items
#
# This launcher builds and runs the current development phase:
# - 6 original snacks in menu bar
# - Menu items: About, Settings, Close, Quit
# - Status bar menu with category organization

set -eo pipefail

# Configuration
APP_NAME="Snackbar"
SCHEME="Snackbar"
PROJECT="Snackbar.xcodeproj"
LOG_FILE="snackbar_dev.log"
BUILD_DIR="build/Dev"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="[$timestamp] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
    echo "[SUCCESS] $message" >> "$LOG_FILE"
}

warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  ${message}${NC}"
    echo "[WARNING] $message" >> "$LOG_FILE"
}

error() {
    local message="$1"
    echo -e "${RED}❌ ${message}${NC}"
    echo "[ERROR] $message" >> "$LOG_FILE"
}

# Initialize log file
log "========================================"
log "Snackbar Dev Launcher - Phase 1"
log "========================================"
log ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log "Working directory: $SCRIPT_DIR"

# Check for Swift
if ! command -v swift &> /dev/null; then
    error "Swift compiler not found!"
    error "Please run: xcode-select --install"
    exit 1
fi

log "Environment check passed"
log ""

# Determine build method: prefer xcodebuild if Xcode is available, fallback to SPM
USE_SPM=false
if command -v xcodebuild &> /dev/null && [ -d "/Applications/Xcode.app" ] || xcodebuild -version &>/dev/null 2>&1; then
    log "Using xcodebuild (Xcode detected)"
    USE_SPM=false
else
    log "Xcode not found — using Swift Package Manager (SPM) build"
    USE_SPM=true
fi

if [ "$USE_SPM" = false ]; then
    # Step 1: Clean previous builds
    log "Step 1: Cleaning previous builds..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        success "Cleaned previous build directory"
    else
        success "No previous build to clean"
    fi
    log ""

    # Step 2: Build via xcodebuild
    log "Step 2: Building Snackbar via xcodebuild..."
    log "Scheme: $SCHEME"
    log "Project: $PROJECT"

    echo "" >> "$LOG_FILE"
    echo "=== XCODEBUILD OUTPUT ===" >> "$LOG_FILE"

    if xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR" \
        clean build \
        >> "$LOG_FILE" 2>&1; then

        success "Build successful!"
        log "Build logs saved to: $LOG_FILE"
    else
        error "Build failed!"
        error "Check $LOG_FILE for details"
        echo ""
        tail -20 "$LOG_FILE"
        exit 1
    fi
    log ""

    # Step 3: Check if app bundle was created
    log "Step 3: Checking for app bundle..."
    if [ -d "$APP_BUNDLE" ]; then
        success "App bundle found at: $APP_BUNDLE"
    else
        # Try to find the built product
        warning "App bundle not in expected location, searching..."

        BUILT_APP=$(find "$BUILD_DIR" -name "*.app" -type d | head -1)

        if [ -n "$BUILT_APP" ]; then
            success "Found app at: $BUILT_APP"
            APP_BUNDLE="$BUILT_APP"
        else
            error "App bundle not found after build!"
            echo ""
            echo "Contents of build directory:"
            ls -la "$BUILD_DIR/" 2>/dev/null || echo "Build directory is empty"
            exit 1
        fi
    fi
    log ""

    # Step 4: Verify resources
    log "Step 4: Verifying resources..."
    RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

    if [ -f "$RESOURCES_DIR/snacks.json" ]; then
        success "snacks.json found in resources"
        SNACK_COUNT=$(grep -c '"id"' "Resources/snacks.json" || echo "0")
        log "Total snacks configured: $SNACK_COUNT"
    else
        warning "snacks.json not in resources (will use bundled version)"
    fi

    if [ -f "$RESOURCES_DIR/categories.json" ]; then
        success "categories.json found in resources"
    else
        warning "categories.json not in resources (will use bundled version)"
    fi
    log ""

    # Step 5: Launch via xcodebuild built app
    log "Step 5: Launching Snackbar app bundle..."
    echo "" >> "$LOG_FILE"
    echo "=== LAUNCHING APP ===" >> "$LOG_FILE"
    log "Launching: $APP_BUNDLE"
    open "$APP_BUNDLE"
else
    # SPM build path (used when Xcode is not available)
    log "Step 1: Building Snackbar via SPM..."

    echo "" >> "$LOG_FILE"
    echo "=== SWIFT BUILD OUTPUT ===" >> "$LOG_FILE"

    if swift build --target Snackbar >> "$LOG_FILE" 2>&1; then
        success "SPM build successful!"
    else
        error "SPM build failed!"
        error "Check $LOG_FILE for details"
        echo ""
        tail -20 "$LOG_FILE"
        exit 1
    fi
    log ""

    # Step 2: Launch via SPM
    log "Step 2: Launching Snackbar via SPM..."
    log "Features enabled:"
    log "  - 6 original snacks (Reminders, Mail VIP, Contacts, Notes, Calendar, Permissions)"
    log "  - Menu bar with status icon"
    log "  - Menu items: About, Settings, Close, Quit"
    log "  - Snacks organized by category"
    log ""

    echo "" >> "$LOG_FILE"
    echo "=== LAUNCHING VIA SPM ===" >> "$LOG_FILE"

    # Run in background so the launcher can track it
    swift run Snackbar &
    SPM_PID=$!
    echo "$SPM_PID" >> "$LOG_FILE"

    success "Snackbar launched via SPM (PID: $SPM_PID)"
fi

success "Snackbar launched!"
log ""
log "Look for the 🍔 icon in your menu bar!"
log ""
log "=== Dev Launcher Complete ==="
log "Log file: $(pwd)/$LOG_FILE"
log ""

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}✅ Snackbar Dev Launcher Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Click the menu bar icon to open the menu"
echo "  2. Test each of the 6 snacks"
echo "  3. Test About, Settings, Close, Quit menu items"
echo "  4. Check $LOG_FILE for debug information"
echo ""
