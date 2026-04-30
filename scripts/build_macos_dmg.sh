#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Podcast Transcript Studio"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
STAGING_DIR="${DIST_DIR}/dmg-staging"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"

"${ROOT_DIR}/scripts/build_macos_app.sh"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "built dmg: $DMG_PATH"
