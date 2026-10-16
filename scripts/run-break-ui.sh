#!/bin/bash
set -euo pipefail

# A separate debug app: no production notes, shortcut, or preference changes.
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH_PATH="${TMPDIR:-/tmp}/jot-break-ui-build-$(id -u)"
OUTPUT_APP_PATH="$PROJECT_ROOT/dist/Jot UI Lab.app"
STAGING_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/jot-ui-lab.XXXXXX")"
APP_PATH="$STAGING_DIRECTORY/Jot UI Lab.app"
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT
mkdir -p "$SCRATCH_PATH/module-cache" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
export CLANG_MODULE_CACHE_PATH="$SCRATCH_PATH/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$SCRATCH_PATH/module-cache"
cd "$PROJECT_ROOT"
swift build -c debug --scratch-path "$SCRATCH_PATH" --disable-sandbox
BINARY_DIRECTORY="$(swift build -c debug --scratch-path "$SCRATCH_PATH" --show-bin-path --disable-sandbox)"
cp "$BINARY_DIRECTORY/Jot" "$APP_PATH/Contents/MacOS/Jot"
cp -R Sources/Jot/Resources/Editor "$APP_PATH/Contents/Resources/"
cp -R Sources/Jot/Resources/Icons "$APP_PATH/Contents/Resources/"
cp Assets/AppIcon.icns "$APP_PATH/Contents/Resources/"
cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.arthur.jot.break-ui</string>
<key>CFBundleName</key><string>Jot UI Lab</string>
<key>CFBundleExecutable</key><string>Jot</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>JotBreakUILab</key><true/>
</dict></plist>
PLIST
xattr -dr com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP_PATH" 2>/dev/null || true
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$PROJECT_ROOT/dist"
rm -rf "$OUTPUT_APP_PATH"
ditto "$APP_PATH" "$OUTPUT_APP_PATH"
codesign --verify --deep --strict "$OUTPUT_APP_PATH"
rm -rf "$STAGING_DIRECTORY"
trap - EXIT
printf '\nUI lab: %s\n' "$OUTPUT_APP_PATH"
exec "$OUTPUT_APP_PATH/Contents/MacOS/Jot" --break-ui "$@"
