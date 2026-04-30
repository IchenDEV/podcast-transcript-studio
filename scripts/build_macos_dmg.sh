#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Podcast Transcript Studio"
APP_VERSION="${APP_VERSION:-0.1.0}"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
STAGING_DIR="${DIST_DIR}/dmg-staging"
DMG_VOLUME_NAME="${DMG_VOLUME_NAME:-$APP_NAME}"
DMG_NAME="${DMG_NAME:-PodcastTranscriptStudio-${APP_VERSION}.dmg}"
DMG_PATH="${DMG_PATH:-${DIST_DIR}/${DMG_NAME}}"
DMG_SHA256_PATH="${DMG_SHA256_PATH:-${DMG_PATH}.sha256}"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "missing hdiutil; DMG builds require macOS" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/build_macos_app.sh"

if [ ! -d "$APP_DIR" ]; then
  echo "missing app bundle: $APP_DIR" >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH" "$DMG_SHA256_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
find "$STAGING_DIR" -name ".DS_Store" -delete

hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"

(
  cd "$(dirname "$DMG_PATH")"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_SHA256_PATH")"
)

echo "built dmg: $DMG_PATH"
echo "built checksum: $DMG_SHA256_PATH"
