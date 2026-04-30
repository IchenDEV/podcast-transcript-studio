#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Podcast Transcript Studio"
EXECUTABLE_NAME="PodcastTranscriptStudioApp"
RESOURCE_BUNDLE_NAME="PodcastTranscriptStudio_PodcastTranscriptStudioCore.bundle"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PYTHON_HOME_SRC="${PYTHON_HOME_SRC:-/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9}"
PYTHON_SITE_PACKAGES_SRC="${PYTHON_SITE_PACKAGES_SRC:-$HOME/Library/Python/3.9/lib/python/site-packages}"

mkdir -p "$DIST_DIR"

swift build -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/${EXECUTABLE_NAME}"
RESOURCE_BUNDLE_PATH="${BIN_DIR}/${RESOURCE_BUNDLE_NAME}"

if [ ! -f "$EXECUTABLE_PATH" ]; then
  echo "missing executable: $EXECUTABLE_PATH" >&2
  exit 1
fi

if [ ! -d "$RESOURCE_BUNDLE_PATH" ]; then
  echo "missing resource bundle: $RESOURCE_BUNDLE_PATH" >&2
  exit 1
fi

if [ ! -d "$PYTHON_HOME_SRC" ]; then
  echo "missing python runtime source: $PYTHON_HOME_SRC" >&2
  exit 1
fi

if [ ! -d "$PYTHON_SITE_PACKAGES_SRC" ]; then
  echo "missing python site-packages source: $PYTHON_SITE_PACKAGES_SRC" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME"

BUNDLED_RESOURCE_ROOT="${RESOURCES_DIR}/${RESOURCE_BUNDLE_NAME}/Resources"
RUNTIME_DIR="${BUNDLED_RESOURCE_ROOT}/Runtime"
PYTHON_HOME_DST="${RUNTIME_DIR}/python-home"
PYTHON_SITE_PACKAGES_DST="${RUNTIME_DIR}/site-packages"
mkdir -p "$RUNTIME_DIR"
rm -rf "$PYTHON_HOME_DST" "$PYTHON_SITE_PACKAGES_DST"
ditto "$PYTHON_HOME_SRC" "$PYTHON_HOME_DST"
rsync -a --delete \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '*.pyo' \
  "$PYTHON_SITE_PACKAGES_SRC/" "$PYTHON_SITE_PACKAGES_DST/"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>ai.openclaw.PodcastTranscriptStudio</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

env \
  PYTHONHOME="$PYTHON_HOME_DST" \
  PYTHONPATH="$PYTHON_SITE_PACKAGES_DST" \
  PYTHONNOUSERSITE=1 \
  "$PYTHON_HOME_DST/bin/python3" -c 'import torch, torchaudio, transformers, pyannote.audio, faster_whisper; print("bundled python runtime OK")'

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "built app bundle: $APP_DIR"
