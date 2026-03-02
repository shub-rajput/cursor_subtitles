#!/bin/bash
set -e

APP_NAME="CursorSubtitles"
BUILD_DIR=".build/release"

swift build -c release

rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"
cp "Info.plist" "${APP_NAME}.app/Contents/"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp Resources/* "${APP_NAME}.app/Contents/Resources/"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "CursorSubtitles"; then
    codesign --force --deep --sign "CursorSubtitles" --identifier "com.cursor-subtitles.app" "${APP_NAME}.app"
    echo "Signed with CursorSubtitles certificate."
else
    echo "No signing certificate found. App will work but may need permission re-granted after each rebuild."
    echo "See README for how to create a local signing certificate."
fi

echo "Built ${APP_NAME}.app"
echo "Run with: open ${APP_NAME}.app"
