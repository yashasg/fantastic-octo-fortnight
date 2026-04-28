#!/usr/bin/env bash
# scripts/build_signed.sh - Signed archive/export/upload runner for TestFlight.
#
# This script intentionally keeps private signing values out of source control.
# Supply account/team/profile/API-key values through environment variables only.
# It does not run unit tests or UI tests; use scripts/build.sh for validation.
#
# Usage:
#   APPLE_TEAM_ID=XXXXXXXXXX ./scripts/build_signed.sh archive
#   APPLE_TEAM_ID=XXXXXXXXXX ./scripts/build_signed.sh export
#   APPLE_TEAM_ID=XXXXXXXXXX ./scripts/build_signed.sh upload
#
# Optional environment:
#   APP_BUNDLE_ID                         default: com.yashasg.eyeposturereminder
#   SIGNING_STYLE                         automatic (default) or manual
#   SIGNING_CERTIFICATE                   default: Apple Distribution
#   PROVISIONING_PROFILE_SPECIFIER        manual signing only
#   ALLOW_PROVISIONING_UPDATES            YES (default) or NO
#   ASC_AUTH_KEY_PATH                     optional App Store Connect API key path
#   ASC_AUTH_KEY_ID                       optional App Store Connect API key ID
#   ASC_AUTH_ISSUER_ID                    optional App Store Connect issuer ID
#   TESTFLIGHT_INTERNAL_ONLY              YES or NO (default)

set -euo pipefail

# -- Colours -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { echo -e "${GREEN}✓ $*${RESET}"; }
fail()  { echo -e "${RED}✗ $*${RESET}" >&2; }
info()  { echo -e "${CYAN}▶ $*${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $*${RESET}"; }
header(){ echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }

# -- Constants ----------------------------------------------------------------
APP_TARGET="EyePostureReminder"
SCHEME="EyePostureReminder"
PACKAGE_PATH="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${PACKAGE_PATH}/DerivedData"
SIGNED_BUILD_PATH="${DERIVED_DATA_PATH}/SignedBuild"
PROJECT_DIR="${SIGNED_BUILD_PATH}/Project"
PROJECT_SPEC="${PROJECT_DIR}/project.yml"
PROJECT_PATH="${PROJECT_DIR}/${APP_TARGET}Signed.xcodeproj"
ARCHIVE_DIR="${SIGNED_BUILD_PATH}/Archives"
ARCHIVE_PATH="${ARCHIVE_DIR}/${APP_TARGET}.xcarchive"
EXPORT_PATH="${SIGNED_BUILD_PATH}/Export"
EXPORT_OPTIONS_PLIST="${SIGNED_BUILD_PATH}/ExportOptions.plist"

APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.yashasg.eyeposturereminder}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${DEVELOPMENT_TEAM:-}}"
CONFIGURATION="${CONFIGURATION:-Release}"
SIGNING_STYLE="${SIGNING_STYLE:-automatic}"
SIGNING_CERTIFICATE="${SIGNING_CERTIFICATE:-Apple Distribution}"
PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER:-}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-YES}"
EXPORT_METHOD="${EXPORT_METHOD:-app-store-connect}"
TESTFLIGHT_INTERNAL_ONLY="${TESTFLIGHT_INTERNAL_ONLY:-NO}"
UPLOAD_SYMBOLS="${UPLOAD_SYMBOLS:-YES}"

ASC_AUTH_KEY_PATH="${ASC_AUTH_KEY_PATH:-${APP_STORE_CONNECT_API_KEY_PATH:-}}"
ASC_AUTH_KEY_ID="${ASC_AUTH_KEY_ID:-${APP_STORE_CONNECT_API_KEY_ID:-}}"
ASC_AUTH_ISSUER_ID="${ASC_AUTH_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-}}"

# Tracks how APPLE_TEAM_ID was resolved ("" = explicit/env, "keychain" = auto-detected)
TEAM_ID_SOURCE=""
TEAM_ID_AMBIGUOUS=false

# -- Helpers ------------------------------------------------------------------
# Try to infer APPLE_TEAM_ID from a Keychain Apple Distribution identity.
# Sets APPLE_TEAM_ID and TEAM_ID_SOURCE="keychain" when exactly one unique
# Team ID is found. Sets TEAM_ID_AMBIGUOUS=true when multiple are found.
# Never prints the actual Team ID value.
infer_team_id_from_keychain() {
  local raw_ids
  raw_ids=$(security find-identity -p codesigning -v 2>/dev/null \
    | grep "Apple Distribution" \
    | grep -oE '\([A-Z0-9]{10}\)' \
    | tr -d '()' \
    | sort -u) || true

  local count=0
  [[ -n "$raw_ids" ]] && count=$(echo "$raw_ids" | wc -l | tr -d ' ')

  if [[ "$count" -eq 1 ]]; then
    APPLE_TEAM_ID="$raw_ids"
    TEAM_ID_SOURCE="keychain"
  elif [[ "$count" -gt 1 ]]; then
    TEAM_ID_AMBIGUOUS=true
  fi
}

# Auto-detect Team ID from Keychain if not explicitly provided.
# Provisioning profiles are handled by Xcode automatic signing or
# explicit env vars (PROVISIONING_PROFILE_SPECIFIER), not Keychain.
if [[ -z "$APPLE_TEAM_ID" ]]; then
  infer_team_id_from_keychain
fi

usage() {
  echo -e "${BOLD}Usage:${RESET} $(basename "$0") <command>"
  echo ""
  echo "Commands:"
  echo "  doctor             Check local signing prerequisites"
  echo "  archive            Create a signed .xcarchive"
  echo "  export             Create a signed .xcarchive and local .ipa"
  echo "  upload             Create a signed .xcarchive and upload for TestFlight"
  echo "  clean              Remove signed build artifacts"
  echo ""
  echo "Required for archive/export/upload:"
  echo "  APPLE_TEAM_ID=<team-id> ./scripts/build_signed.sh archive"
  echo ""
  echo "APPLE_TEAM_ID can be omitted if exactly one Apple Distribution identity"
  echo "is present in the local macOS Keychain — it will be auto-detected."
  echo ""
  echo "Private values must be passed through environment variables only."
  echo "Do not edit Team IDs, profile UUIDs, API key IDs, or .p8 paths into this file."
}

elapsed() {
  local start=$1
  local end
  end=$(date +%s)
  echo $(( end - start ))s
}

require_tool() {
  local tool="$1"
  local install_hint="$2"

  if ! command -v "$tool" &>/dev/null; then
    fail "$tool not found."
    fail "$install_hint"
    exit 1
  fi
}

require_xcodebuild() {
  require_tool "xcodebuild" "Install Xcode from the Mac App Store."
}

require_xcodegen() {
  require_tool "xcodegen" "Install with: brew install xcodegen"
}

require_team_id() {
  if [[ -z "$APPLE_TEAM_ID" ]]; then
    if [[ "$TEAM_ID_AMBIGUOUS" == "true" ]]; then
      fail "Multiple Apple Distribution Team IDs found in Keychain — cannot auto-detect."
      fail "Set APPLE_TEAM_ID explicitly:"
    else
      fail "APPLE_TEAM_ID is required for signed builds."
      fail "Install an Apple Distribution certificate in your Keychain for auto-detection, or set it explicitly:"
    fi
    fail "  APPLE_TEAM_ID=<your-team-id> ./scripts/build_signed.sh archive"
    fail "Do not commit the Team ID into this script."
    exit 1
  fi
}

AUTH_FLAGS=()
PROVISIONING_FLAGS=()
SIGNING_BUILD_SETTINGS=()

build_auth_flags() {
  AUTH_FLAGS=()

  local have_any=false
  [[ -n "$ASC_AUTH_KEY_PATH" ]] && have_any=true
  [[ -n "$ASC_AUTH_KEY_ID" ]] && have_any=true
  [[ -n "$ASC_AUTH_ISSUER_ID" ]] && have_any=true

  if [[ "$have_any" == "false" ]]; then
    return 0
  fi

  if [[ -z "$ASC_AUTH_KEY_PATH" || -z "$ASC_AUTH_KEY_ID" || -z "$ASC_AUTH_ISSUER_ID" ]]; then
    fail "App Store Connect API auth requires all three values:"
    fail "  ASC_AUTH_KEY_PATH, ASC_AUTH_KEY_ID, ASC_AUTH_ISSUER_ID"
    exit 1
  fi

  if [[ ! -f "$ASC_AUTH_KEY_PATH" ]]; then
    fail "ASC_AUTH_KEY_PATH does not exist: $ASC_AUTH_KEY_PATH"
    exit 1
  fi

  if [[ "$ASC_AUTH_KEY_PATH" == "$PACKAGE_PATH"* ]]; then
    warn "ASC_AUTH_KEY_PATH points inside this repo. Move .p8 keys outside the repo before committing."
  fi

  AUTH_FLAGS=(
    "-authenticationKeyPath" "$ASC_AUTH_KEY_PATH"
    "-authenticationKeyID" "$ASC_AUTH_KEY_ID"
    "-authenticationKeyIssuerID" "$ASC_AUTH_ISSUER_ID"
  )
}

build_provisioning_flags() {
  PROVISIONING_FLAGS=()

  if [[ "$ALLOW_PROVISIONING_UPDATES" == "YES" ]]; then
    PROVISIONING_FLAGS=("-allowProvisioningUpdates")
  fi
}

build_signing_build_settings() {
  SIGNING_BUILD_SETTINGS=(
    "PRODUCT_BUNDLE_IDENTIFIER=${APP_BUNDLE_ID}" \
    "DEVELOPMENT_TEAM=${APPLE_TEAM_ID}" \
    "CODE_SIGN_STYLE=${SIGNING_STYLE}" \
    "CODE_SIGN_IDENTITY=${SIGNING_CERTIFICATE}" \
    "CODE_SIGNING_ALLOWED=YES" \
    "CODE_SIGNING_REQUIRED=YES" \
    "ENABLE_BITCODE=NO"
  )

  if [[ "$SIGNING_STYLE" == "manual" && -n "$PROVISIONING_PROFILE_SPECIFIER" ]]; then
    SIGNING_BUILD_SETTINGS+=("PROVISIONING_PROFILE_SPECIFIER=${PROVISIONING_PROFILE_SPECIFIER}")
  fi
}

run_xcodebuild() {
  local start
  start=$(date +%s)

  if command -v xcpretty &>/dev/null; then
    xcodebuild "$@" | xcpretty
  else
    xcodebuild "$@"
  fi

  echo "  (took $(elapsed "$start"))"
}

generate_project() {
  header "GENERATE SIGNED PROJECT"
  require_xcodegen

  mkdir -p "$PROJECT_DIR"

  # Build a temporary app-only Xcode project. Do not reuse the UI-test project:
  # signed archives only need the app target, not test bundles.
  cat > "$PROJECT_SPEC" <<EOF
name: ${APP_TARGET}Signed

options:
  deploymentTarget:
    iOS: "16.0"
  xcodeVersion: "16.2"
  minimumXcodeGenVersion: "2.40.0"
  generateEmptyDirectories: false

packages:
  EyePostureReminder:
    path: "${PACKAGE_PATH}"

targets:
  ${APP_TARGET}:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    dependencies:
      - package: EyePostureReminder
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${APP_BUNDLE_ID}
        TARGETED_DEVICE_FAMILY: "1,2"
        INFOPLIST_FILE: "${PACKAGE_PATH}/EyePostureReminder/Info.plist"
        CODE_SIGN_ENTITLEMENTS: "${PACKAGE_PATH}/EyePostureReminder/EyePostureReminder.entitlements"
        ENABLE_BITCODE: "NO"
    postBuildScripts:
      - name: "Assemble App Bundle"
        script: |
          set -e
          BIN_SRC="\${BUILT_PRODUCTS_DIR}/\${EXECUTABLE_NAME}"
          BIN_DST="\${BUILT_PRODUCTS_DIR}/\${EXECUTABLE_FOLDER_PATH}/\${EXECUTABLE_NAME}"
          if [ -f "\$BIN_SRC" ] && [ "\$BIN_SRC" != "\$BIN_DST" ]; then
            cp "\$BIN_SRC" "\$BIN_DST"
            chmod +x "\$BIN_DST"
          fi

          BUNDLE_NAME="\${PRODUCT_MODULE_NAME}_\${PRODUCT_MODULE_NAME}.bundle"
          BUNDLE_SRC="\${BUILT_PRODUCTS_DIR}/\${BUNDLE_NAME}"
          BUNDLE_DST="\${BUILT_PRODUCTS_DIR}/\${EXECUTABLE_FOLDER_PATH}/\${BUNDLE_NAME}"
          if [ -d "\$BUNDLE_SRC" ]; then
            rm -rf "\$BUNDLE_DST"
            cp -r "\$BUNDLE_SRC" "\$BUNDLE_DST"
          fi

          PRIVACY_SRC="${PACKAGE_PATH}/EyePostureReminder/PrivacyInfo.xcprivacy"
          PRIVACY_DST="\${BUILT_PRODUCTS_DIR}/\${EXECUTABLE_FOLDER_PATH}/PrivacyInfo.xcprivacy"
          if [ -f "\$PRIVACY_SRC" ]; then
            cp "\$PRIVACY_SRC" "\$PRIVACY_DST"
          fi

schemes:
  ${SCHEME}:
    build:
      targets:
        ${APP_TARGET}: [run, archive]
    archive:
      config: ${CONFIGURATION}
EOF

  xcodegen generate \
    --spec "$PROJECT_SPEC" \
    --project "$PROJECT_DIR"

  pass "Generated temporary project at: $PROJECT_PATH"
}

create_export_options() {
  local destination="$1"

  mkdir -p "$SIGNED_BUILD_PATH"
  rm -f "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Clear dict" "$EXPORT_OPTIONS_PLIST" >/dev/null

  /usr/libexec/PlistBuddy -c "Add :method string ${EXPORT_METHOD}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :destination string ${destination}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :teamID string ${APPLE_TEAM_ID}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :signingStyle string ${SIGNING_STYLE}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :signingCertificate string ${SIGNING_CERTIFICATE}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :stripSwiftSymbols bool YES" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :uploadSymbols bool ${UPLOAD_SYMBOLS}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :testFlightInternalTestingOnly bool ${TESTFLIGHT_INTERNAL_ONLY}" "$EXPORT_OPTIONS_PLIST"

  if [[ "$SIGNING_STYLE" == "manual" && -n "$PROVISIONING_PROFILE_SPECIFIER" ]]; then
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_OPTIONS_PLIST"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:${APP_BUNDLE_ID} string ${PROVISIONING_PROFILE_SPECIFIER}" "$EXPORT_OPTIONS_PLIST"
  fi
}

cmd_doctor() {
  header "SIGNED BUILD DOCTOR"
  require_xcodebuild

  if command -v xcodegen &>/dev/null; then
    info "xcodegen: $(xcodegen version 2>/dev/null || echo 'version unknown')"
  else
    warn "xcodegen missing. Install with: brew install xcodegen"
  fi

  info "Bundle ID: ${APP_BUNDLE_ID}"

  if [[ -n "$APPLE_TEAM_ID" ]]; then
    if [[ "$TEAM_ID_SOURCE" == "keychain" ]]; then
      pass "APPLE_TEAM_ID: detected from Keychain"
    else
      pass "APPLE_TEAM_ID: set"
    fi
  elif [[ "$TEAM_ID_AMBIGUOUS" == "true" ]]; then
    warn "APPLE_TEAM_ID: multiple Team IDs found in Keychain — set APPLE_TEAM_ID explicitly"
  else
    warn "APPLE_TEAM_ID: not set (required for archive/export/upload; install an Apple Distribution cert for auto-detection)"
  fi

  if security find-identity -p codesigning -v 2>/dev/null | grep -q "Apple Distribution"; then
    pass "Apple Distribution signing identity found in Keychain"
  else
    warn "No Apple Distribution signing identity found in Keychain"
  fi

  if [[ -n "$ASC_AUTH_KEY_PATH" ]]; then
    if [[ "$ASC_AUTH_KEY_PATH" == "$PACKAGE_PATH"* ]]; then
      warn "ASC_AUTH_KEY_PATH is inside the repo. Move it outside before committing."
    elif [[ -f "$ASC_AUTH_KEY_PATH" ]]; then
      pass "ASC_AUTH_KEY_PATH exists outside the repo"
    else
      warn "ASC_AUTH_KEY_PATH does not exist"
    fi
  fi

  pass "Doctor complete"
}

cmd_archive() {
  header "SIGNED ARCHIVE"
  require_xcodebuild
  require_team_id
  generate_project

  rm -rf "$ARCHIVE_PATH"
  mkdir -p "$ARCHIVE_DIR"

  build_auth_flags
  build_provisioning_flags
  build_signing_build_settings

  info "Scheme:      $SCHEME"
  info "Bundle ID:   $APP_BUNDLE_ID"
  info "Archive:     $ARCHIVE_PATH"

  run_xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    "${PROVISIONING_FLAGS[@]}" \
    "${AUTH_FLAGS[@]}" \
    archive \
    "${SIGNING_BUILD_SETTINGS[@]}"

  pass "Archive created: $ARCHIVE_PATH"
}

cmd_export() {
  cmd_archive

  header "EXPORT IPA"
  require_team_id
  create_export_options "export"

  rm -rf "$EXPORT_PATH"
  mkdir -p "$EXPORT_PATH"

  build_auth_flags
  build_provisioning_flags

  run_xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    "${PROVISIONING_FLAGS[@]}" \
    "${AUTH_FLAGS[@]}"

  pass "Export complete: $EXPORT_PATH"
}

cmd_upload() {
  cmd_archive

  header "UPLOAD TO APP STORE CONNECT"
  require_team_id
  create_export_options "upload"

  rm -rf "$EXPORT_PATH"
  mkdir -p "$EXPORT_PATH"

  build_auth_flags
  build_provisioning_flags

  run_xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    "${PROVISIONING_FLAGS[@]}" \
    "${AUTH_FLAGS[@]}"

  pass "Upload submitted to App Store Connect"
}

cmd_clean() {
  header "CLEAN SIGNED BUILD"
  rm -rf "$SIGNED_BUILD_PATH"
  pass "Removed: $SIGNED_BUILD_PATH"
}

# -- Entry point ---------------------------------------------------------------
COMMAND="${1:-}"

case "$COMMAND" in
  doctor)  cmd_doctor ;;
  archive) cmd_archive ;;
  export)  cmd_export ;;
  upload)  cmd_upload ;;
  clean)   cmd_clean ;;
  -h|--help|help) usage ;;
  "")
    usage
    exit 1
    ;;
  *)
    fail "Unknown command: '${COMMAND}'"
    echo ""
    usage
    exit 1
    ;;
esac
