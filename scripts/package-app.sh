#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$PROJECT_DIR/dist/YabaiBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [ "${UNIVERSAL_BINARY:-0}" = "1" ]; then
    set -- --arch arm64 --arch x86_64
else
    set --
fi

swift build --package-path "$PROJECT_DIR" -c release --product YabaiBar "$@"
swift build --package-path "$PROJECT_DIR" -c release --product yabai-barctl "$@"
BIN_DIR=$(swift build --package-path "$PROJECT_DIR" -c release --show-bin-path "$@")

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$BIN_DIR/YabaiBar" "$MACOS_DIR/YabaiBar"
cp "$BIN_DIR/yabai-barctl" "$MACOS_DIR/yabai-barctl"

if [ -n "${APP_VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$CONTENTS_DIR/Info.plist"
fi

if [ -n "${BUILD_NUMBER:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
fi

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$MACOS_DIR/yabai-barctl"
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$MACOS_DIR/YabaiBar"
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_DIR"
else
    codesign --force --sign - "$MACOS_DIR/yabai-barctl"
    codesign --force --sign - "$MACOS_DIR/YabaiBar"
    codesign --force --sign - "$APP_DIR"
fi

echo "$APP_DIR"
