#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_BUILD=false
BUILD_ARGUMENTS=()

usage() {
  cat <<'EOF'
Usage: scripts/build-dmg.sh [--skip-build | --skip-editor]

Build Jot and create a compressed, read-only DMG with an Applications shortcut.
--skip-build packages the existing dist/Jot.app without rebuilding it.
--skip-editor rebuilds the native app using existing editor resources.
This does not perform Developer ID signing or Apple notarization.
EOF
}

for argument in "$@"; do
  case "$argument" in
    --skip-build) SKIP_BUILD=true ;;
    --skip-editor) BUILD_ARGUMENTS+=(--skip-editor) ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$argument" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != Darwin ]]; then
  printf 'DMG packaging requires macOS.\n' >&2
  exit 1
fi

if [[ "$SKIP_BUILD" == false ]]; then
  "$PROJECT_ROOT/scripts/build-app.sh" ${BUILD_ARGUMENTS[@]+"${BUILD_ARGUMENTS[@]}"}
fi

APP_PATH="$PROJECT_ROOT/dist/Jot.app"
if [[ ! -d "$APP_PATH" ]]; then
  printf 'Missing dist/Jot.app. Run this script without --skip-build.\n' >&2
  exit 1
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
  printf 'App version must contain only numbers and dots.\n' >&2
  exit 1
fi
ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/Jot")"
case "$ARCHITECTURES" in
  arm64) ARCH_LABEL=arm64 ;;
  x86_64) ARCH_LABEL=x86_64 ;;
  'x86_64 arm64'|'arm64 x86_64') ARCH_LABEL=universal ;;
  *) printf 'Unsupported executable architectures: %s\n' "$ARCHITECTURES" >&2; exit 1 ;;
esac

PACKAGE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/jot-dmg.XXXXXX")"
trap 'rm -rf "$PACKAGE_DIRECTORY"' EXIT
SOURCE_DIRECTORY="$PACKAGE_DIRECTORY/volume"
DMG_NAME="Jot-$VERSION-$ARCH_LABEL.dmg"
mkdir -p "$SOURCE_DIRECTORY" "$PROJECT_ROOT/dist"
ditto "$APP_PATH" "$SOURCE_DIRECTORY/Jot.app"
# Synced source folders may add Finder metadata after a build. Clean only the
# two attributes forbidden by codesign on this temporary copy, not the source.
# Preserve quarantine and the app's existing signature.
xattr -dr com.apple.FinderInfo "$SOURCE_DIRECTORY/Jot.app" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$SOURCE_DIRECTORY/Jot.app" 2>/dev/null || true
ln -s /Applications "$SOURCE_DIRECTORY/Applications"
cp "$PROJECT_ROOT/THIRD_PARTY_NOTICES.txt" "$SOURCE_DIRECTORY/Third Party Notices.txt"
cat > "$SOURCE_DIRECTORY/Install Jot.txt" <<'EOF'
Install Jot

1. Drag Jot.app into the Applications folder beside it.
2. Eject this disk image.
3. Open Jot from Applications.

Use the menu-bar icon or Control–Option–J to show your notes.
Change the shortcut in Settings (Command–comma).
Keep Jot running for the global shortcut to work.

Requires macOS 14 or later and a compatible Mac processor.
Your notes stay in your own Mac's Application Support/Jot folder.

This packaging script preserves the app's existing signature.
A local development build is not an Apple-notarized public release.
EOF
codesign --verify --deep --strict "$SOURCE_DIRECTORY/Jot.app"
hdiutil create -srcfolder "$SOURCE_DIRECTORY" -volname Jot -fs HFS+ -format UDZO -o "$PACKAGE_DIRECTORY/$DMG_NAME"
hdiutil verify "$PACKAGE_DIRECTORY/$DMG_NAME"
mv -f "$PACKAGE_DIRECTORY/$DMG_NAME" "$PROJECT_ROOT/dist/$DMG_NAME"
(
  cd "$PROJECT_ROOT/dist"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)
printf '\nDMG: %s\nChecksum: %s\n' "$PROJECT_ROOT/dist/$DMG_NAME" "$PROJECT_ROOT/dist/$DMG_NAME.sha256"
printf 'Packaging complete. Developer ID signing and notarization are separate release steps.\n'
