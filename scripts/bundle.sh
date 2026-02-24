#!/bin/bash
set -e

APP_NAME="TmuxBar"
BUILD_DIR=".build/release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"

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

echo "Built $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
