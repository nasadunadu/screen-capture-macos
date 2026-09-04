#!/bin/zsh

set -euo pipefail

if (( $# != 3 )); then
  echo "Usage: $0 /path/to/ScreenCapture.app KEYCHAIN_PROFILE /path/to/output" >&2
  exit 64
fi

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h:h}
APP=${1:A}
KEYCHAIN_PROFILE=$2
OUTPUT_DIR=${3:A}

test -d "$APP" || { echo "App bundle not found: $APP" >&2; exit 1; }
test -f "$APP/Contents/MacOS/ScreenCapture" || { echo "Unexpected app bundle: $APP" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

SIGNATURE=$(codesign -dv --verbose=4 "$APP" 2>&1)
echo "$SIGNATURE" | grep -q 'Authority=Developer ID Application:' || {
  echo "The app is not signed with a Developer ID Application certificate." >&2
  exit 1
}
SIGNING_AUTHORITY=$(echo "$SIGNATURE" | sed -n 's/^Authority=\(Developer ID Application:.*\)$/\1/p' | head -1)
test -n "$SIGNING_AUTHORITY" || { echo "Unable to determine the Developer ID signing identity." >&2; exit 1; }
security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_AUTHORITY\"" || {
  echo "The app uses $SIGNING_AUTHORITY, but its private key is not available in the local keychain." >&2
  echo "Create or import a local Developer ID Application identity before signing the DMG." >&2
  exit 1
}

codesign --verify --deep --strict --verbose=2 "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
BASENAME="ScreenCapture-$VERSION-macos-universal"
FINAL_DMG="$OUTPUT_DIR/$BASENAME.dmg"
FINAL_ZIP="$OUTPUT_DIR/$BASENAME.zip"
FINAL_DMG_CHECKSUM="$FINAL_DMG.sha256"
FINAL_ZIP_CHECKSUM="$FINAL_ZIP.sha256"

for output in "$FINAL_DMG" "$FINAL_ZIP" "$FINAL_DMG_CHECKSUM" "$FINAL_ZIP_CHECKSUM"; do
  test ! -e "$output" || { echo "Output already exists: $output" >&2; exit 1; }
done

TEMP_DIR=$(mktemp -d /tmp/screencapture-notary.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT
PACKAGE_DIR="$TEMP_DIR/package"
mkdir -p "$PACKAGE_DIR"

ENTITLEMENTS="$TEMP_DIR/entitlements.plist"
codesign -d --entitlements :- "$APP" >"$ENTITLEMENTS" 2>/dev/null || true
if plutil -extract com.apple.security.get-task-allow raw "$ENTITLEMENTS" 2>/dev/null | grep -q true; then
  echo "Release app contains com.apple.security.get-task-allow=true." >&2
  exit 1
fi

BIN="$APP/Contents/MacOS/ScreenCapture"
ARCHITECTURES=$(lipo -archs "$BIN")
[[ " $ARCHITECTURES " == *" arm64 "* ]] || { echo "Missing arm64 slice" >&2; exit 1; }
[[ " $ARCHITECTURES " == *" x86_64 "* ]] || { echo "Missing x86_64 slice" >&2; exit 1; }

UPLOAD_ZIP="$TEMP_DIR/ScreenCapture-notary-upload.zip"
ditto -c -k --keepParent "$APP" "$UPLOAD_ZIP"

echo "==> Submitting to Apple notarization"
xcrun notarytool submit "$UPLOAD_ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "==> Stapling and validating"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"

"$PROJECT_ROOT/scripts/release/package.sh" "$APP" "$PACKAGE_DIR"
PACKAGED_DMG="$PACKAGE_DIR/$BASENAME.dmg"
PACKAGED_ZIP="$PACKAGE_DIR/$BASENAME.zip"
PACKAGED_DMG_CHECKSUM="$PACKAGED_DMG.sha256"
PACKAGED_ZIP_CHECKSUM="$PACKAGED_ZIP.sha256"

echo "==> Signing final DMG"
codesign --force --timestamp --sign "$SIGNING_AUTHORITY" "$PACKAGED_DMG"
codesign --verify --verbose=2 "$PACKAGED_DMG"

echo "==> Notarizing final DMG"
xcrun notarytool submit "$PACKAGED_DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$PACKAGED_DMG"
xcrun stapler validate "$PACKAGED_DMG"
spctl --assess --type open --context context:primary-signature --verbose=4 "$PACKAGED_DMG"

(
  cd "$PACKAGE_DIR"
  shasum -a 256 "${PACKAGED_DMG:t}" >"${PACKAGED_DMG_CHECKSUM:t}"
)

mv "$PACKAGED_DMG" "$FINAL_DMG"
mv "$PACKAGED_ZIP" "$FINAL_ZIP"
mv "$PACKAGED_DMG_CHECKSUM" "$FINAL_DMG_CHECKSUM"
mv "$PACKAGED_ZIP_CHECKSUM" "$FINAL_ZIP_CHECKSUM"

echo "Created: $FINAL_DMG"
echo "Created: $FINAL_ZIP"
echo "Checksum: $FINAL_DMG_CHECKSUM"
echo "Checksum: $FINAL_ZIP_CHECKSUM"
