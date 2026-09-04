#!/bin/zsh

set -euo pipefail

if (( $# != 3 )); then
  echo "Usage: $0 /path/to/ScreenCapture.xcarchive TEAM_ID /path/to/output" >&2
  exit 64
fi

ARCHIVE=${1:A}
TEAM_ID=$2
OUTPUT_DIR=${3:A}
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export DEVELOPER_DIR

test -d "$ARCHIVE" || { echo "Archive not found: $ARCHIVE" >&2; exit 1; }
test -n "$TEAM_ID" || { echo "A Developer Program team ID is required." >&2; exit 1; }
test -d "$DEVELOPER_DIR" || { echo "Xcode developer directory not found: $DEVELOPER_DIR" >&2; exit 1; }

ARCHIVED_APP="$ARCHIVE/Products/Applications/ScreenCapture.app"
test -d "$ARCHIVED_APP" || { echo "ScreenCapture.app not found in archive: $ARCHIVE" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
FINAL_APP="$OUTPUT_DIR/ScreenCapture.app"
test ! -e "$FINAL_APP" || { echo "Output already exists: $FINAL_APP" >&2; exit 1; }

TEMP_DIR=$(mktemp -d /tmp/screencapture-xcode-notary.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT
UPLOAD_OPTIONS="$TEMP_DIR/UploadOptions.plist"
NOTARIZED_EXPORT="$TEMP_DIR/notarized"
EXPORT_LOG="$TEMP_DIR/export-notarized.log"

/usr/libexec/PlistBuddy -c 'Add :destination string upload' "$UPLOAD_OPTIONS"
/usr/libexec/PlistBuddy -c 'Add :method string developer-id' "$UPLOAD_OPTIONS"
/usr/libexec/PlistBuddy -c 'Add :signingCertificate string Developer ID Application' "$UPLOAD_OPTIONS"
/usr/libexec/PlistBuddy -c 'Add :signingStyle string automatic' "$UPLOAD_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$UPLOAD_OPTIONS"

echo "==> Uploading archive for Developer ID notarization"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$UPLOAD_OPTIONS" \
  -allowProvisioningUpdates

echo "==> Waiting for Apple notarization"
for attempt in {1..20}; do
  rm -rf "$NOTARIZED_EXPORT"
  if xcodebuild \
    -exportNotarizedApp \
    -archivePath "$ARCHIVE" \
    -exportPath "$NOTARIZED_EXPORT" \
    >"$EXPORT_LOG" 2>&1; then
    cat "$EXPORT_LOG"
    break
  fi

  if (( attempt == 20 )); then
    cat "$EXPORT_LOG" >&2
    echo "The notarized app was not available after 5 minutes. Check the archive in Xcode Organizer." >&2
    exit 1
  fi

  echo "Notarization is still processing (attempt $attempt/20); retrying in 15 seconds."
  sleep 15
done

NOTARIZED_APP="$NOTARIZED_EXPORT/ScreenCapture.app"
test -d "$NOTARIZED_APP" || { echo "Xcode did not export ScreenCapture.app." >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$NOTARIZED_APP"
xcrun stapler validate "$NOTARIZED_APP"
spctl --assess --type execute --verbose=4 "$NOTARIZED_APP"

mv "$NOTARIZED_APP" "$FINAL_APP"
echo "Exported notarized app: $FINAL_APP"
