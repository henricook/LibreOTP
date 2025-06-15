#!/bin/bash

# Script to create a DMG package for LibreOTP macOS
# Usage: ./scripts/create_dmg.sh

set -e

APP_NAME="LibreOTP"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUNDLE_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-macos.dmg"
TEMP_DMG_NAME="${APP_NAME}-temp.dmg"

echo "Creating DMG for ${APP_NAME} v${VERSION}..."

# Check if app bundle exists
if [ ! -d "$BUNDLE_PATH" ]; then
    echo "Error: App bundle not found at $BUNDLE_PATH"
    echo "Please run 'flutter build macos' first"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Using temp directory: $TEMP_DIR"

# Copy app bundle to temp directory
cp -R "$BUNDLE_PATH" "$TEMP_DIR/"

# Create Applications symlink for drag-and-drop installation
ln -s /Applications "$TEMP_DIR/Applications"

# Calculate size for DMG
SIZE=$(du -sm "$TEMP_DIR" | cut -f1)
SIZE=$((SIZE + 10))  # Add 10MB buffer

# Create DMG
echo "Creating DMG image..."
hdiutil create -srcfolder "$TEMP_DIR" -volname "$APP_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${SIZE}m "$TEMP_DMG_NAME"

# Mount the DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG_NAME" | grep -E '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/$APP_NAME"

echo "Mounted DMG at: $MOUNT_POINT"

# Set up the DMG appearance
echo "Configuring DMG appearance..."

# Create .DS_Store for custom layout (optional)
osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 440}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "${APP_NAME}.app" of container window to {130, 200}
        set position of item "Applications" of container window to {390, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount the DMG
hdiutil detach "$DEVICE"

# Convert to compressed read-only DMG
echo "Compressing DMG..."
hdiutil convert "$TEMP_DMG_NAME" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# Clean up
rm -f "$TEMP_DMG_NAME"
rm -rf "$TEMP_DIR"

echo "DMG created successfully: $DMG_NAME"
echo "File size: $(du -h "$DMG_NAME" | cut -f1)"