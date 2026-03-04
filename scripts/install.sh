#!/bin/bash
set -e

REPO="shub-rajput/cursor_subtitles"
APP_NAME="CursorSubtitles"
INSTALL_DIR="/Applications"

echo "Installing ${APP_NAME}..."

# Fetch latest release download URL
LATEST_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep '"browser_download_url"' \
  | grep '\.zip"' \
  | head -1 \
  | sed 's/.*"browser_download_url": "\(.*\)"/\1/')

if [ -z "$LATEST_URL" ]; then
  echo "Error: Could not find latest release. Check https://github.com/${REPO}/releases"
  exit 1
fi

# Download to temp dir
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading from ${LATEST_URL}..."
curl -fsSL "$LATEST_URL" -o "${TMP_DIR}/${APP_NAME}.zip"

echo "Unzipping..."
unzip -q "${TMP_DIR}/${APP_NAME}.zip" -d "$TMP_DIR"

APP_PATH=$(find "$TMP_DIR" -name "${APP_NAME}.app" -maxdepth 2 | head -1)
if [ -z "$APP_PATH" ]; then
  echo "Error: ${APP_NAME}.app not found in zip"
  exit 1
fi

# Remove quarantine attribute so macOS doesn't block launch
xattr -cr "$APP_PATH"

# Quit app if running
if pgrep -x "$APP_NAME" > /dev/null; then
  echo "Quitting ${APP_NAME}..."
  killall "$APP_NAME" 2>/dev/null || true
  sleep 1
fi

# Move to /Applications (replace existing)
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  echo "Replacing existing installation..."
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

mv "$APP_PATH" "${INSTALL_DIR}/"

echo "Installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo "Launching..."
open "${INSTALL_DIR}/${APP_NAME}.app"
