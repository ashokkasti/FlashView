#!/bin/bash

# Build the executable
swift build -c release

# Create the app bundle structure
APP_DIR="FlashView.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the executable
cp .build/release/FlashView "$MACOS_DIR/"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

# App Icon Generation and Logo
ASSETS_DIR="Sources/FlashView/Resources/Assets.xcassets"
if [ -d "$ASSETS_DIR" ]; then
    cp "$ASSETS_DIR/Logo.png" "$RESOURCES_DIR/" 2>/dev/null || true
    
    # Create temporary iconset
    ICONSET_DIR="/tmp/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    cp "$ASSETS_DIR/icon_16.png" "$ICONSET_DIR/icon_16x16.png" 2>/dev/null || true
    cp "$ASSETS_DIR/icon_32.png" "$ICONSET_DIR/icon_32x32.png" 2>/dev/null || true
    cp "$ASSETS_DIR/icon_64.png" "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null || true
    cp "$ASSETS_DIR/icon_128.png" "$ICONSET_DIR/icon_128x128.png" 2>/dev/null || true
    cp "$ASSETS_DIR/icon_256.png" "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ASSETS_DIR/icon_512.png" "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null || true

    # Generate icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
fi

echo "Successfully built $APP_DIR"
