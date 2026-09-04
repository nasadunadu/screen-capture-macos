#!/bin/zsh

set -euo pipefail

if (( $# != 2 )); then
  echo "Usage: $0 /path/to/ScreenCapture.app /path/to/output" >&2
  exit 64
fi

APP=${1:A}
OUTPUT_DIR=${2:A}

test -d "$APP" || { echo "App bundle not found: $APP" >&2; exit 1; }
test -f "$APP/Contents/MacOS/ScreenCapture" || { echo "Unexpected app bundle: $APP" >&2; exit 1; }

INFO_PLIST="$APP/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
[[ -n "$VERSION" && "$VERSION" != *[^A-Za-z0-9.-]* ]] || {
  echo "Unsafe bundle version: $VERSION" >&2
  exit 1
}

BIN="$APP/Contents/MacOS/ScreenCapture"
ARCHITECTURES=$(lipo -archs "$BIN")
[[ " $ARCHITECTURES " == *" arm64 "* ]] || { echo "Missing arm64 slice" >&2; exit 1; }
[[ " $ARCHITECTURES " == *" x86_64 "* ]] || { echo "Missing x86_64 slice" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"

BASENAME="ScreenCapture-$VERSION-macos-universal"
DMG="$OUTPUT_DIR/$BASENAME.dmg"
ZIP="$OUTPUT_DIR/$BASENAME.zip"
DMG_CHECKSUM="$DMG.sha256"
ZIP_CHECKSUM="$ZIP.sha256"

for output in "$DMG" "$ZIP" "$DMG_CHECKSUM" "$ZIP_CHECKSUM"; do
  test ! -e "$output" || { echo "Output already exists: $output" >&2; exit 1; }
done

TEMP_DIR=$(mktemp -d /tmp/screencapture-package.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

STAGING_DIR="$TEMP_DIR/ScreenCapture $VERSION"
TEMP_DMG="$TEMP_DIR/$BASENAME.dmg"
TEMP_ZIP="$TEMP_DIR/$BASENAME.zip"
TEMP_DMG_CHECKSUM="$TEMP_DMG.sha256"
TEMP_ZIP_CHECKSUM="$TEMP_ZIP.sha256"
mkdir -p "$STAGING_DIR"
ditto "$APP" "$STAGING_DIR/ScreenCapture.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating DMG"
hdiutil create \
  -quiet \
  -fs HFS+ \
  -format UDZO \
  -volname "ScreenCapture $VERSION" \
  -srcfolder "$STAGING_DIR" \
  "$TEMP_DMG"
hdiutil verify "$TEMP_DMG" >/dev/null

echo "==> Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$TEMP_ZIP"
unzip -tq "$TEMP_ZIP" >/dev/null

(
  cd "$TEMP_DIR"
  shasum -a 256 "${TEMP_DMG:t}" >"${TEMP_DMG_CHECKSUM:t}"
  shasum -a 256 "${TEMP_ZIP:t}" >"${TEMP_ZIP_CHECKSUM:t}"
)

mv "$TEMP_DMG" "$DMG"
mv "$TEMP_ZIP" "$ZIP"
mv "$TEMP_DMG_CHECKSUM" "$DMG_CHECKSUM"
mv "$TEMP_ZIP_CHECKSUM" "$ZIP_CHECKSUM"

echo "Created: $DMG"
echo "Created: $ZIP"
echo "Checksum: $DMG_CHECKSUM"
echo "Checksum: $ZIP_CHECKSUM"
