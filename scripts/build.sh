#!/bin/bash
set -e

APP_NAME="CursorSubtitles"
BUILD_DIR=".build/release"

swift build -c release

rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"
cp "Info.plist" "${APP_NAME}.app/Contents/"

codesign --force --deep --sign - --identifier "com.cursor-subtitles.app" "${APP_NAME}.app"

echo "Built ${APP_NAME}.app"
echo "Run with: open ${APP_NAME}.app"
