#!/bin/bash
set -e

APP_NAME="Pubbles"
BUNDLE_ID="com.pubbles.app"
BUILD_DIR=".build/release"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null || echo "unknown")

echo "Building ${APP_NAME} v${VERSION}..."

# Quit the app if running
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "Quitting ${APP_NAME}..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

swift build -c release

rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"
cp "Info.plist" "${APP_NAME}.app/Contents/"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp Resources/* "${APP_NAME}.app/Contents/Resources/" 2>/dev/null || true
if [ -d "Resources/themes" ]; then
    cp -r Resources/themes "${APP_NAME}.app/Contents/Resources/themes"
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -q "Pubbles"; then
    codesign --force --deep --sign "Pubbles" --identifier "com.pubbles.app" "${APP_NAME}.app"
    echo "Signed with Pubbles certificate."
else
    echo "No signing certificate found. App will work but may need permission re-granted after each rebuild."
    echo "See README for how to create a local signing certificate."
fi

echo "Built ${APP_NAME}.app v${VERSION}"

# Relaunch
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Pubbles"; then
    echo "Signed build — permissions will persist."
    open "${APP_NAME}.app"
else
    echo "Unsigned build — resetting Accessibility permission..."
    tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
    open "${APP_NAME}.app"
    echo "Grant Accessibility permission when prompted."
fi
