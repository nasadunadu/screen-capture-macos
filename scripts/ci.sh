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

[[ " $ARCHITECTURES " == *" arm64 "* ]] || { echo "Missing arm64 slice" >&2; exit 1; }
[[ " $ARCHITECTURES " == *" x86_64 "* ]] || { echo "Missing x86_64 slice" >&2; exit 1; }
test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
plutil -lint "$APP/Contents/Resources/PrivacyInfo.xcprivacy"

echo "Validated ScreenCapture.app ($ARCHITECTURES)"
