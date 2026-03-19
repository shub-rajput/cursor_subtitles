#!/bin/bash
set -e

APP_NAME="Pubbles"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null || echo "unknown")
DMG_NAME="${APP_NAME}_${VERSION}.dmg"
DMG_TEMP="dmg_temp"
DMG_RW="${APP_NAME}_rw.dmg"
VOLUME_NAME="${APP_NAME}"

# Ensure the .app bundle exists
if [ ! -d "${APP_NAME}.app" ]; then
    echo "Error: ${APP_NAME}.app not found. Run ./scripts/build.sh first."
    exit 1
fi

echo "Creating DMG for ${APP_NAME} v${VERSION}..."

# Clean up any previous artifacts
rm -rf "${DMG_TEMP}" "${DMG_RW}" "${DMG_NAME}"

# Create staging directory
mkdir -p "${DMG_TEMP}"

# Use ditto to copy the app bundle (preserves resource forks, metadata, codesigning)
ditto "${APP_NAME}.app" "${DMG_TEMP}/${APP_NAME}.app"

# Create symlink to Applications folder
ln -s /Applications "${DMG_TEMP}/Applications"

# Copy background image into a hidden folder
BG_IMAGE="Resources/Pubble-dmg-bg.png"
if [ -f "${BG_IMAGE}" ]; then
    mkdir -p "${DMG_TEMP}/.background"
    cp "${BG_IMAGE}" "${DMG_TEMP}/.background/bg.png"
fi

# Create the read-write DMG (size it generously for background + icons)
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDRW \
    -size 200m \
    "${DMG_RW}"

# Mount it to configure the window
MOUNT_DIR=$(hdiutil attach "${DMG_RW}" -readwrite -noverify | grep "/Volumes/${VOLUME_NAME}" | awk '{print $3}')

# Set Finder window appearance via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 200, 960, 680}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:bg.png"
        set position of item "${APP_NAME}.app" of container window to {140, 200}
        set position of item "Applications" of container window to {420, 200}
        close
    end tell
end tell
APPLESCRIPT

# Set the volume icon if we have one
if [ -f "Resources/AppIcon.icns" ]; then
    ditto "Resources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
    SetFile -c icnC "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
fi

sync
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed, read-only DMG
hdiutil convert "${DMG_RW}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"

# Clean up
rm -rf "${DMG_TEMP}" "${DMG_RW}"

echo "Created ${DMG_NAME}"
