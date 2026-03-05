#!/bin/bash
set -e

APP_NAME="Pubbles"
BUNDLE_ID="com.pubbles.app"

echo "Updating ${APP_NAME}..."

# Quit the app if running
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "Quitting ${APP_NAME}..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# Pull latest changes if tracking a remote branch
if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
    echo "Pulling latest changes..."
    git pull
else
    echo "No remote tracking branch — rebuilding current state."
fi

# Rebuild
echo "Building..."
./scripts/build.sh

# Check if signed
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Pubbles"; then
    echo ""
    echo "Signed build — permissions will persist."
    open "${APP_NAME}.app"
else
    echo ""
    echo "Unsigned build — resetting Accessibility permission..."
    tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
    open "${APP_NAME}.app"
    echo ""
    echo "Grant Accessibility permission when prompted."
    echo "The app will start automatically once you do."
fi

echo "Update complete."
