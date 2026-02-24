#!/bin/bash
set -e

APP_NAME="TmuxBar"
BUILD_DIR=".build/release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"

# Gracefully quit the running app (exact name match only, won't kill terminal sessions)
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "Stopping running $APP_NAME..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"
cp Sources/TmuxBar/Info.plist "$BUNDLE_DIR/Contents/"

echo "Code signing..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "Launching $APP_NAME..."
open "$BUNDLE_DIR"

echo "Done."
