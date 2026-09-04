#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-"$PROJECT_ROOT/build/CI"}
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export DEVELOPER_DIR

cd "$PROJECT_ROOT"

echo "==> Toolchain"
xcodebuild -version
swift --version

echo "==> Static files"
plutil -lint \
  ScreenCapture/Resources/Info.plist \
  ScreenCapture/Resources/PrivacyInfo.xcprivacy
git diff --check

echo "==> Unit and regression tests"
xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  test

DEBUG_APP="$DERIVED_DATA_PATH/Build/Products/Debug/ScreenCapture.app"
DEBUG_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEBUG_APP/Contents/Info.plist")
DEBUG_DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$DEBUG_APP/Contents/Info.plist")
[[ "$DEBUG_BUNDLE_ID" == "com.nasa.ScreenCapture.debug" ]] || {
  echo "Debug builds must use an isolated TCC identity; found $DEBUG_BUNDLE_ID" >&2
  exit 1
}
[[ "$DEBUG_DISPLAY_NAME" == "ScreenCapture Dev" ]] || {
  echo "Unexpected Debug display name: $DEBUG_DISPLAY_NAME" >&2
  exit 1
}

echo "==> Static analysis"
xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  analyze

echo "==> Universal Release build"
xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS='arm64 x86_64' \
  build

APP="$DERIVED_DATA_PATH/Build/Products/Release/ScreenCapture.app"
BIN="$APP/Contents/MacOS/ScreenCapture"
ARCHITECTURES=$(lipo -archs "$BIN")
RELEASE_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")
RELEASE_DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Contents/Info.plist")

[[ " $ARCHITECTURES " == *" arm64 "* ]] || { echo "Missing arm64 slice" >&2; exit 1; }
[[ " $ARCHITECTURES " == *" x86_64 "* ]] || { echo "Missing x86_64 slice" >&2; exit 1; }
[[ "$RELEASE_BUNDLE_ID" == "com.nasa.ScreenCapture" ]] || {
  echo "Unexpected Release bundle identifier: $RELEASE_BUNDLE_ID" >&2
  exit 1
}
[[ "$RELEASE_DISPLAY_NAME" == "ScreenCapture" ]] || {
  echo "Unexpected Release display name: $RELEASE_DISPLAY_NAME" >&2
  exit 1
}
test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
plutil -lint "$APP/Contents/Resources/PrivacyInfo.xcprivacy"

echo "Validated ScreenCapture.app ($ARCHITECTURES)"
