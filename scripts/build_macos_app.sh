#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Podcast Transcript Studio"
EXECUTABLE_NAME="PodcastTranscriptStudioApp"
RESOURCE_BUNDLE_NAME="PodcastTranscriptStudio_PodcastTranscriptStudioCore.bundle"
APP_ICON_NAME="AppIcon"
APP_ICON_SRC="${APP_ICON_SRC:-${ROOT_DIR}/assets/${APP_ICON_NAME}.icns}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-ai.openclaw.PodcastTranscriptStudio}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VERIFY_PYTHON_IMPORTS="${VERIFY_PYTHON_IMPORTS:-torch torchaudio transformers pyannote.audio faster_whisper huggingface_hub}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "missing python executable: $PYTHON_BIN" >&2
  exit 1
fi

detect_python_home() {
  "$PYTHON_BIN" - <<'PY'
import sys
print(sys.base_prefix)
PY
}

detect_python_site_packages() {
  "$PYTHON_BIN" - <<'PY'
from pathlib import Path
import site
import sys
import sysconfig

candidates = []
try:
    candidates.extend(site.getsitepackages())
except Exception:
    pass

user_site = site.getusersitepackages()
if sys.prefix == sys.base_prefix:
    ordered = [user_site] + candidates
else:
    ordered = candidates + [user_site]

for candidate in ordered:
    path = Path(candidate)
    if path.exists():
        print(path)
        break
else:
    print(Path(sysconfig.get_paths()["purelib"]))
PY
}

check_broken_symlinks() {
  local root="$1"
  local broken=0
  while IFS= read -r -d '' link_path; do
    local target
    local resolved
    target="$(readlink "$link_path")"
    if [[ "$target" = /* ]]; then
      resolved="$target"
    else
      resolved="$(dirname "$link_path")/$target"
    fi
    if [ ! -e "$resolved" ]; then
      echo "broken symlink: $link_path -> $target" >&2
      broken=1
    fi
  done < <(find "$root" -type l -print0)
  return "$broken"
}

PYTHON_HOME_SRC="${PYTHON_HOME_SRC:-$(detect_python_home)}"
PYTHON_SITE_PACKAGES_SRC="${PYTHON_SITE_PACKAGES_SRC:-$(detect_python_site_packages)}"

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

if [ ! -f "$APP_ICON_SRC" ]; then
  echo "missing app icon: $APP_ICON_SRC" >&2
  echo "run scripts/generate_app_icon.py to create it" >&2
  exit 1
fi

if [ ! -d "$PYTHON_HOME_SRC" ]; then
  echo "missing python runtime source: $PYTHON_HOME_SRC" >&2
  exit 1
fi

if [ ! -x "$PYTHON_HOME_SRC/bin/python3" ]; then
  echo "missing python runtime executable: $PYTHON_HOME_SRC/bin/python3" >&2
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
cp "$APP_ICON_SRC" "$RESOURCES_DIR/${APP_ICON_NAME}.icns"

BUNDLED_RESOURCE_ROOT="${RESOURCES_DIR}/${RESOURCE_BUNDLE_NAME}/Resources"
RUNTIME_DIR="${BUNDLED_RESOURCE_ROOT}/Runtime"
PYTHON_HOME_DST="${RUNTIME_DIR}/python-home"
PYTHON_SITE_PACKAGES_DST="${RUNTIME_DIR}/site-packages"
mkdir -p "$RUNTIME_DIR"
rm -rf "$PYTHON_HOME_DST" "$PYTHON_SITE_PACKAGES_DST"
ditto "$PYTHON_HOME_SRC" "$PYTHON_HOME_DST"
find "$PYTHON_HOME_DST" -path "*/site-packages" -type l -delete
rsync -aL --delete \
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
  <string>${BUNDLE_IDENTIFIER}</string>
  <key>CFBundleIconFile</key>
  <string>${APP_ICON_NAME}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

if [ "${SKIP_PYTHON_RUNTIME_CHECK:-0}" != "1" ]; then
  env \
    PYTHONHOME="$PYTHON_HOME_DST" \
    PYTHONPATH="$PYTHON_SITE_PACKAGES_DST" \
    PYTHONNOUSERSITE=1 \
    "$PYTHON_HOME_DST/bin/python3" - "$VERIFY_PYTHON_IMPORTS" <<'PY'
import importlib
import sys

missing = []
for module_name in sys.argv[1].split():
    try:
        importlib.import_module(module_name)
    except Exception as exc:
        missing.append(f"{module_name}: {exc}")

if missing:
    raise SystemExit("bundled python runtime check failed:\n" + "\n".join(missing))

print("bundled python runtime OK")
PY
else
  echo "skipped bundled python runtime check"
fi

check_broken_symlinks "$APP_DIR"

if [ "${SKIP_CODESIGN:-0}" != "1" ]; then
  codesign --force --deep --sign "${CODESIGN_IDENTITY:--}" "$APP_DIR"
  codesign --verify --deep --strict "$APP_DIR"
else
  echo "skipped codesign"
fi

echo "built app bundle: $APP_DIR"
