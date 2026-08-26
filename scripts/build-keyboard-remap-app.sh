#!/bin/sh
# Builds the Keyboard Remap.app menu bar bundle from keyboard-remap.swift and
# installs it to ~/Applications. The app is not tied to any particular
# keyboard brand or model: which HID receiver it listens to is read from
# ~/Library/Application Support/macomrade/keyboard-remap.json at launch.
# Usage: scripts/build-keyboard-remap-app.sh
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
APP_NAME="Keyboard Remap"
DEST="$HOME/Applications/$APP_NAME.app"

rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS"

swiftc "$REPO_ROOT/scripts/keyboard-remap.swift" -o "$DEST/Contents/MacOS/$APP_NAME"
cp "$REPO_ROOT/templates/keyboard-remap-Info.plist" "$DEST/Contents/Info.plist"

# Keep the About dialog's version in sync with the repo's own VERSION file
# instead of a second hand-maintained copy in the Info.plist template.
REPO_VERSION=$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "0.0.0")
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $REPO_VERSION" "$DEST/Contents/Info.plist"

codesign --force --sign - "$DEST"

echo "Built and signed: $DEST"
