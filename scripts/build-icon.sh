#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$PROJECT_DIR/Resources/AppIcon.svg"
PNG="$PROJECT_DIR/Resources/AppIcon.png"
ICNS="$PROJECT_DIR/Resources/AppIcon.icns"
ICONSET="$PROJECT_DIR/Resources/AppIcon.iconset"

mkdir -p "$ICONSET"
find "$ICONSET" -type f -delete

sips -s format png "$SOURCE" --out "$PNG" >/dev/null
sips -z 16 16 "$PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$PNG" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ICNS"
find "$ICONSET" -type f -delete
rmdir "$ICONSET"

echo "$PNG"
echo "$ICNS"
