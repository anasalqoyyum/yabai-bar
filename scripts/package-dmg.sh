#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")}
DMG="$PROJECT_DIR/dist/YabaiBar-$VERSION.dmg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/yabai-bar-dmg.XXXXXX")
CORE_VERSION_PATTERN='(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
PRERELEASE_IDENTIFIER='(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
BUILD_IDENTIFIER='[0-9A-Za-z-]+'
SEMVER_PATTERN="^$CORE_VERSION_PATTERN(-$PRERELEASE_IDENTIFIER(\.$PRERELEASE_IDENTIFIER)*)?(\+$BUILD_IDENTIFIER(\.$BUILD_IDENTIFIER)*)?$"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT HUP INT TERM

if ! printf '%s\n' "$VERSION" | grep -Eq "$SEMVER_PATTERN"; then
    echo "Invalid semantic version: $VERSION" >&2
    exit 1
fi

BUNDLE_VERSION=$(printf '%s\n' "$VERSION" | sed 's/[-+].*$//')
APP_VERSION="$BUNDLE_VERSION" "$PROJECT_DIR/scripts/package-app.sh"
ditto "$PROJECT_DIR/dist/YabaiBar.app" "$STAGING_DIR/YabaiBar.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "Yabai Bar" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG"

echo "$DMG"
