#!/bin/bash
# Create Snackbar DMG for distribution

set -e

APP_NAME="Snackbar"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME} Installer"
TEMP_DMG="/tmp/${DMG_NAME}"

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Snackbar.app not found. Build it first."
    exit 1
fi

echo "📦 Creating DMG from: $APP_PATH"

# Create temporary DMG
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$TEMP_DMG"

# Move to output
mkdir -p ~/Code/Apps/Snackbar/dist
mv "$TEMP_DMG" ~/Code/Apps/Snackbar/dist/"$DMG_NAME"

echo "✅ DMG created: ~/Code/Apps/Snackbar/dist/${DMG_NAME}"
