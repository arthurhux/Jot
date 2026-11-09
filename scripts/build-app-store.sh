#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ARGUMENTS=()

usage() {
  cat <<'EOF'
Usage: scripts/build-app-store.sh [--skip-editor]

Builds a sandboxed Mac App Store variant of Jot at dist/AppStore/Jot.app.

Without signing variables it signs ad hoc with the App Store entitlements, so
you can run the sandboxed app locally (for example with --smoke-test) before
submitting. For a submission build, set:

  JOT_SIGN_IDENTITY         "Apple Distribution: Your Name (TEAMID)"
  JOT_TEAM_ID               Your 10-character Apple Developer Team ID
  JOT_PROVISIONING_PROFILE  Path to the Mac App Store .provisionprofile
  JOT_INSTALLER_IDENTITY    "3rd Party Mac Developer Installer: Your Name (TEAMID)"

With all four set, the script also writes dist/AppStore/Jot.pkg for upload with
Transporter. Optional: JOT_BUNDLE_ID overrides the bundle identifier, which is
useful for a local sandbox test that must not share the production container.
Nothing is uploaded by this script.
EOF
}

for argument in "$@"; do
  case "$argument" in
    --skip-editor) BUILD_ARGUMENTS+=(--skip-editor) ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$argument" >&2; usage >&2; exit 2 ;;
  esac
done

SIGN_IDENTITY="${JOT_SIGN_IDENTITY:--}"
TEAM_ID="${JOT_TEAM_ID:-}"
PROFILE="${JOT_PROVISIONING_PROFILE:-}"
INSTALLER_IDENTITY="${JOT_INSTALLER_IDENTITY:-}"

if [[ "$SIGN_IDENTITY" != "-" && ( -z "$TEAM_ID" || -z "$PROFILE" ) ]]; then
  printf 'A distribution signature also needs JOT_TEAM_ID and JOT_PROVISIONING_PROFILE.\n' >&2
  exit 2
fi
if [[ -n "$PROFILE" && ! -f "$PROFILE" ]]; then
  printf 'Provisioning profile not found: %s\n' "$PROFILE" >&2
  exit 1
fi

cd "$PROJECT_ROOT"
OUTPUT_DIRECTORY="$PROJECT_ROOT/dist/AppStore"
APP_PATH="$OUTPUT_DIRECTORY/Jot.app"
STAGING_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/jot-app-store.XXXXXX")"
STAGING_PATH="$STAGING_DIRECTORY/Jot.app"
ENTITLEMENTS="$STAGING_DIRECTORY/Jot.entitlements"
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT

# Build straight into staging so the developer dist/Jot.app is never replaced.
JOT_APP_PATH="$STAGING_PATH" "$PROJECT_ROOT/scripts/build-app.sh" ${BUILD_ARGUMENTS[@]+"${BUILD_ARGUMENTS[@]}"}
# The editor and icons are already copied to Contents/Resources. Drop SwiftPM's
# duplicate resource bundle so the submitted app contains one copy of each file.
rm -rf "$STAGING_PATH/Contents/Resources/Jot_Jot.bundle"
cp AppStore/PrivacyInfo.xcprivacy "$STAGING_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
cp AppStore/Jot.entitlements "$ENTITLEMENTS"

PLIST="$STAGING_PATH/Contents/Info.plist"
if [[ -n "${JOT_BUNDLE_ID:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $JOT_BUNDLE_ID" "$PLIST"
fi
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"

if [[ -n "$TEAM_ID" ]]; then
  /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENTITLEMENTS"
fi
if [[ -n "$PROFILE" ]]; then
  cp "$PROFILE" "$STAGING_PATH/Contents/embedded.provisionprofile"
fi

plutil -lint "$PLIST" "$ENTITLEMENTS" "$STAGING_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
xattr -cr "$STAGING_PATH"
codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" --options runtime "$STAGING_PATH"
codesign --verify --strict --verbose=2 "$STAGING_PATH"

printf '\nSigned entitlements:\n'
codesign -d --entitlements - --xml "$STAGING_PATH" 2>/dev/null | plutil -p - || true

# Package from the unsynced staging copy. A synced Documents folder can attach
# Finder metadata to new bundles, which codesign rejects.
PACKAGE_STAGING=""
if [[ -n "$INSTALLER_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
  PACKAGE_STAGING="$STAGING_DIRECTORY/Jot.pkg"
  productbuild --component "$STAGING_PATH" /Applications --sign "$INSTALLER_IDENTITY" "$PACKAGE_STAGING"
  pkgutil --check-signature "$PACKAGE_STAGING"
fi

mkdir -p "$OUTPUT_DIRECTORY"
rm -rf "$APP_PATH"
ditto --noextattr --noqtn "$STAGING_PATH" "$APP_PATH"
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.ResourceFork "$APP_PATH" 2>/dev/null || true
if ! codesign --verify --strict "$APP_PATH" 2>/dev/null; then
  printf 'Note: the synced copy picked up Finder metadata; the staged app verified above.\n' >&2
fi

if [[ -n "$PACKAGE_STAGING" ]]; then
  PACKAGE_PATH="$OUTPUT_DIRECTORY/Jot.pkg"
  rm -f "$PACKAGE_PATH"
  cp "$PACKAGE_STAGING" "$PACKAGE_PATH"
  printf '\nApp Store package: %s\nUpload it with Transporter after reviewing it.\n' "$PACKAGE_PATH"
else
  printf '\nSandboxed app (ad hoc, local testing only): %s\n' "$APP_PATH"
fi
rm -rf "$STAGING_DIRECTORY"
trap - EXIT
