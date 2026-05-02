#!/bin/bash

# build-snackbar.sh
# Build and package Snackbar for macOS

set -e

echo "📦 Building Snackbar..."

# Check if we can use xcodebuild
if xcodebuild -version >/dev/null 2>&1; then
    echo "🔨 Using xcodebuild..."
    xcodebuild \
      -project Snackbar.xcodeproj \
      -scheme Snackbar \
      -configuration Release \
      -derivedDataPath .build \
      clean build
else
    echo "⚠️  xcodebuild not available, trying alternative build method..."
    echo "📦 Using Swift Package Manager..."
    
    # Try building with Swift Package Manager
    if [ -f "Package.swift" ]; then
        swift build -c release --product Snackbar
        
        # Create app bundle structure
        mkdir -p build/Release/Snackbar.app/Contents/MacOS
        cp .build/release/Snackbar build/Release/Snackbar.app/Contents/MacOS/
        
        # Create minimal Info.plist
        cat > build/Release/Snackbar.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Snackbar</string>
    <key>CFBundleIdentifier</key>
    <string>com.udos.Snackbar</string>
    <key>CFBundleName</key>
    <string>Snackbar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    else
        echo "❌ Neither xcodebuild nor Package.swift available"
        exit 1
    fi
fi

echo "✅ Build completed successfully!"

# Create output directory
mkdir -p build/Release

# Copy the app bundle
cp -r .build/Build/Products/Release/Snackbar.app build/Release/

echo "🎉 Snackbar.app is ready at build/Release/Snackbar.app"
