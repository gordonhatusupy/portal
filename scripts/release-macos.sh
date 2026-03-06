#!/usr/bin/env bash

set -euo pipefail

APP_NAME="${APP_NAME:-Portal}"
PROJECT_PATH="${PROJECT_PATH:-Portal.xcodeproj}"
SCHEME="${SCHEME:-Portal}"
CONFIGURATION="${CONFIGURATION:-Release}"
DIST_DIR="${DIST_DIR:-dist}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.derivedData-release}"
APP_PATH="$DIST_DIR/$APP_NAME.app"
NOTARIZATION_ZIP_PATH="$DIST_DIR/$APP_NAME-notarization.zip"
RELEASE_ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-macOS.dmg"

SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"

NOTARYTOOL_KEY_PATH="${NOTARYTOOL_KEY_PATH:-}"
NOTARYTOOL_KEY_ID="${NOTARYTOOL_KEY_ID:-}"
NOTARYTOOL_ISSUER="${NOTARYTOOL_ISSUER:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"

print_usage() {
  cat <<'EOF'
Usage: scripts/release-macos.sh [--skip-notarization]

Builds a signed macOS release app, optionally notarizes it, then packages the
final distributable zip in dist/.

Required environment variables:
  DEVELOPMENT_TEAM           Apple Developer Team ID
  DEVELOPER_ID_APPLICATION   Full Developer ID Application identity name

Notarization credentials (choose one mode unless --skip-notarization is used):
  Mode 1: App Store Connect API key
    NOTARYTOOL_KEY_PATH
    NOTARYTOOL_KEY_ID
    NOTARYTOOL_ISSUER

  Mode 2: Stored keychain profile
    NOTARYTOOL_PROFILE

Optional:
  KEYCHAIN_PATH              Temporary keychain path for CI signing
  APP_NAME                   Default: Portal
  PROJECT_PATH               Default: Portal.xcodeproj
  SCHEME                     Default: Portal
EOF
}

log() {
  printf '[release] %s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required environment variable: %s\n' "$name" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      print_usage
      exit 1
      ;;
  esac
done

require_command xcodebuild
require_command codesign
require_command ditto
require_command xcrun
require_command spctl

require_env DEVELOPMENT_TEAM
require_env DEVELOPER_ID_APPLICATION

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
  if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
    :
  else
    require_env NOTARYTOOL_KEY_PATH
    require_env NOTARYTOOL_KEY_ID
    require_env NOTARYTOOL_ISSUER
  fi
fi

log "Preparing release output directories"
rm -rf "$DIST_DIR" "$DERIVED_DATA_PATH"
mkdir -p "$DIST_DIR"

log "Building $APP_NAME in $CONFIGURATION"
BUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
  ENABLE_HARDENED_RUNTIME=YES
  build
)

if [[ -n "$KEYCHAIN_PATH" ]]; then
  BUILD_ARGS+=("OTHER_CODE_SIGN_FLAGS=--keychain $KEYCHAIN_PATH")
fi

xcodebuild "${BUILD_ARGS[@]}"

BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$BUILT_APP_PATH" ]]; then
  printf 'Expected built app not found at %s\n' "$BUILT_APP_PATH" >&2
  exit 1
fi

log "Copying signed app into $APP_PATH"
ditto "$BUILT_APP_PATH" "$APP_PATH"

log "Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

log "Creating notarization zip"
rm -f "$NOTARIZATION_ZIP_PATH" "$RELEASE_ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZATION_ZIP_PATH"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  log "Skipping notarization; using pre-notarization zip as final artifact"
  cp "$NOTARIZATION_ZIP_PATH" "$RELEASE_ZIP_PATH"
else
  log "Submitting app for notarization"
  if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
    xcrun notarytool submit "$NOTARIZATION_ZIP_PATH" \
      --keychain-profile "$NOTARYTOOL_PROFILE" \
      --wait
  else
    xcrun notarytool submit "$NOTARIZATION_ZIP_PATH" \
      --key "$NOTARYTOOL_KEY_PATH" \
      --key-id "$NOTARYTOOL_KEY_ID" \
      --issuer "$NOTARYTOOL_ISSUER" \
      --wait
  fi

  log "Stapling notarization ticket"
  xcrun stapler staple "$APP_PATH"

  log "Checking Gatekeeper assessment"
  spctl -a -t exec -vv "$APP_PATH"

  log "Creating final distributable zip"
  ditto -c -k --keepParent "$APP_PATH" "$RELEASE_ZIP_PATH"
fi

log "Creating DMG installer"
DMG_STAGING="$DIST_DIR/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

log "Release artifacts ready:"
printf '  %s\n' "$RELEASE_ZIP_PATH"
printf '  %s\n' "$DMG_PATH"
