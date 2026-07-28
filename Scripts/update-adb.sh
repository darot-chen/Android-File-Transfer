#!/bin/sh
# Downloads the official Google Android platform-tools `adb` binary for macOS
# and stages it at AndroidFileTransfer/Resources/adb, ad-hoc signed and
# stripped of the quarantine attribute so it can be spawned locally.
#
# Re-run this whenever you want to refresh to the latest platform-tools.
set -e
cd "$(dirname "$0")/.."

URL="https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
DEST="AndroidFileTransfer/Resources/adb"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading platform-tools from $URL"
curl -fsSL "$URL" -o "$TMP_DIR/platform-tools.zip"

echo "Extracting adb"
unzip -q "$TMP_DIR/platform-tools.zip" "platform-tools/adb" -d "$TMP_DIR"

cp "$TMP_DIR/platform-tools/adb" "$DEST"
chmod +x "$DEST"

echo "Stripping quarantine attribute"
xattr -cr "$DEST"

echo "Ad-hoc code-signing adb"
codesign --force --sign - "$DEST"

echo "Verifying architecture"
lipo -info "$DEST"

echo "Done: $DEST"
