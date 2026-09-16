#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${CODESIGN_IDENTITY:?Set CODESIGN_IDENTITY to a Developer ID Application identity.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an xcrun notarytool keychain profile.}"
VERSION=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")}

APP_VERSION="$VERSION" "$PROJECT_DIR/scripts/package-app.sh"
ARCHIVE="$PROJECT_DIR/dist/YabaiBar-$VERSION.zip"
rm -f "$ARCHIVE"
ditto -c -k --keepParent "$PROJECT_DIR/dist/YabaiBar.app" "$ARCHIVE"
xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$PROJECT_DIR/dist/YabaiBar.app"
xcrun stapler validate "$PROJECT_DIR/dist/YabaiBar.app"
rm -f "$ARCHIVE"
ditto -c -k --keepParent "$PROJECT_DIR/dist/YabaiBar.app" "$ARCHIVE"
echo "$ARCHIVE"
