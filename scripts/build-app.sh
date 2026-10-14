#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_EDITOR=false

usage() {
  cat <<'EOF'
Usage: scripts/build-app.sh [--skip-editor]

Builds the editor and a locally signed release app at dist/Jot.app.
Use --skip-editor only when Sources/Jot/Resources/Editor is already built.
Set JOT_BUILD_DIR to override the default temporary Swift build directory.
EOF
}

for argument in "$@"; do
  case "$argument" in
    --skip-editor) SKIP_EDITOR=true ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$argument" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'Jot requires macOS and the Xcode command line tools.\n' >&2
  exit 1
fi

cd "$PROJECT_ROOT"
TEMPORARY_ROOT="${TMPDIR:-/tmp}"
PROJECT_DIGEST="$(printf '%s' "$PROJECT_ROOT" | shasum -a 256 | cut -c 1-16)"
SCRATCH_PATH="${JOT_BUILD_DIR:-$TEMPORARY_ROOT/jot-build-$(id -u)-$PROJECT_DIGEST}"
mkdir -p "$SCRATCH_PATH/module-cache" "$SCRATCH_PATH/icon-module-cache" dist
SCRATCH_PATH="$(cd -- "$SCRATCH_PATH" && pwd -P)"
export CLANG_MODULE_CACHE_PATH="$SCRATCH_PATH/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$SCRATCH_PATH/module-cache"

if [[ "$SKIP_EDITOR" == false ]]; then
  command -v npm >/dev/null || { printf 'Install Node.js and npm to build the editor.\n' >&2; exit 1; }
  npm --prefix Editor ci --no-audit --no-fund
  npm --prefix Editor run build
fi

for editor_asset in index.html editor.js editor.css theme.css; do
  if [[ ! -f "Sources/Jot/Resources/Editor/$editor_asset" ]]; then
    printf 'Editor asset %s is missing. Run this script without --skip-editor.\n' "$editor_asset" >&2
    exit 1
  fi
done

if [[ ! -f Assets/AppIcon.icns || scripts/generate-icon.swift -nt Assets/AppIcon.icns ]]; then
  swift -module-cache-path "$SCRATCH_PATH/icon-module-cache" scripts/generate-icon.swift "$PROJECT_ROOT/Assets"
fi

swift build -c release --scratch-path "$SCRATCH_PATH" --disable-sandbox
BINARY_DIRECTORY="$(swift build -c release --scratch-path "$SCRATCH_PATH" --show-bin-path --disable-sandbox)"
APP_PATH="$PROJECT_ROOT/dist/Jot.app"
STAGING_DIRECTORY="$(mktemp -d "$TEMPORARY_ROOT/jot-package.XXXXXX")"
STAGING_PATH="$STAGING_DIRECTORY/Jot.app"
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT

mkdir -p "$STAGING_PATH/Contents/MacOS" "$STAGING_PATH/Contents/Resources"
cp "$BINARY_DIRECTORY/Jot" "$STAGING_PATH/Contents/MacOS/Jot"
cp Info.plist "$STAGING_PATH/Contents/Info.plist"
cp Assets/AppIcon.icns "$STAGING_PATH/Contents/Resources/AppIcon.icns"
cp THIRD_PARTY_NOTICES.txt "$STAGING_PATH/Contents/Resources/THIRD_PARTY_NOTICES.txt"
cp -R Sources/Jot/Resources/Editor "$STAGING_PATH/Contents/Resources/Editor"
cp -R Sources/Jot/Resources/Icons "$STAGING_PATH/Contents/Resources/Icons"

# Preserve SwiftPM's generated resource bundle for Bundle.module callers.
while IFS= read -r -d '' resource_bundle; do
  cp -R "$resource_bundle" "$STAGING_PATH/Contents/Resources/"
done < <(find "$BINARY_DIRECTORY" -maxdepth 1 -name '*.bundle' -type d -print0)

# FileProvider can attach Finder metadata in a synced source workspace. Remove
# only the two attributes forbidden by codesign from this generated staging app.
# Quarantine and all other attributes are left untouched.
xattr -dr com.apple.FinderInfo "$STAGING_PATH" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$STAGING_PATH" 2>/dev/null || true
plutil -lint "$STAGING_PATH/Contents/Info.plist"
codesign --force --deep --sign - "$STAGING_PATH"
codesign --verify --deep --strict "$STAGING_PATH"

rm -rf "$APP_PATH"
ditto "$STAGING_PATH" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
rm -rf "$STAGING_DIRECTORY"
trap - EXIT
printf '\nBuilt Jot: %s\n' "$APP_PATH"
