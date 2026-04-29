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
#   SIGNING_STYLE                         manual (default) or automatic
#   SIGNING_CERTIFICATE                   default: Apple Distribution
#   PROVISIONING_PROFILE_SPECIFIER        manual signing only
#   ALLOW_PROVISIONING_UPDATES            YES (default) or NO
#   ASC_AUTH_KEY_PATH                     optional App Store Connect API key path
#   ASC_AUTH_KEY_ID                       optional App Store Connect API key ID
#   ASC_AUTH_ISSUER_ID                    optional App Store Connect issuer ID
#   TESTFLIGHT_INTERNAL_ONLY              YES or NO (default)
#   BUILD_NUMBER                          default: YYYYMMDDHHmm timestamp; set for unique TestFlight builds
#   SIGNED_ENTITLEMENTS_PATH              default: App Store-safe distribution entitlements

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
SIGNED_ENTITLEMENTS_PATH="${SIGNED_ENTITLEMENTS_PATH:-${PACKAGE_PATH}/EyePostureReminder/EyePostureReminder.Distribution.entitlements}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${DEVELOPMENT_TEAM:-}}"
CONFIGURATION="${CONFIGURATION:-Release}"
SIGNING_STYLE="${SIGNING_STYLE:-manual}"
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

code_sign_style_value() {
  if [[ "$SIGNING_STYLE" == "manual" ]]; then
    echo "Manual"
  else
    echo "Automatic"
  fi
}

yaml_quote() {
  local value="$1"
  local escaped
  escaped=$(printf '%s' "$value" | sed "s/'/''/g")
  printf "'%s'" "$escaped"
}

require_signed_entitlements() {
  if [[ ! -f "$SIGNED_ENTITLEMENTS_PATH" ]]; then
    fail "Signed entitlements file not found: $SIGNED_ENTITLEMENTS_PATH"
    fail "Set SIGNED_ENTITLEMENTS_PATH to an existing entitlements file, or restore the default distribution entitlements file."
    exit 1
  fi
}

entitlements_requests_focus_status() {
  local entitlements_path="$1"
  /usr/libexec/PlistBuddy -c "Print :com.apple.developer.focus-status" "$entitlements_path" >/dev/null 2>&1
}

profile_dir_path() {
  echo "${HOME}/Library/MobileDevice/Provisioning Profiles"
}

decode_profile_to_plist() {
  local profile="$1"
  local plist="$2"

  security cms -D -i "$profile" > "$plist" 2>/dev/null
}

profile_bundle_matches() {
  local plist="$1"
  local app_identifier
  app_identifier=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$plist" 2>/dev/null || true)

  if [[ -n "$APPLE_TEAM_ID" ]]; then
    [[ "$app_identifier" == "${APPLE_TEAM_ID}.${APP_BUNDLE_ID}" ]]
  else
    [[ "$app_identifier" == *".${APP_BUNDLE_ID}" ]]
  fi
}

profile_is_app_store_connect() {
  local plist="$1"
  local get_task_allow
  local provisions_all_devices

  profile_bundle_matches "$plist" || return 1

  get_task_allow=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:get-task-allow" "$plist" 2>/dev/null || true)
  [[ "$get_task_allow" == "false" ]] || return 1

  # Development and ad hoc profiles are device-bound. TestFlight/App Store
  # profiles do not contain a ProvisionedDevices array.
  if /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$plist" >/dev/null 2>&1; then
    return 1
  fi

  provisions_all_devices=$(/usr/libexec/PlistBuddy -c "Print :ProvisionsAllDevices" "$plist" 2>/dev/null || true)
  [[ "$provisions_all_devices" != "true" ]]
}

matching_profile_names() {
  local profile_dir
  local profile
  local plist
  local name

  profile_dir="$(profile_dir_path)"
  [[ -d "$profile_dir" ]] || return 0

  for profile in "$profile_dir"/*.mobileprovision; do
    [[ -e "$profile" ]] || continue

    plist="$(mktemp)"
    if decode_profile_to_plist "$profile" "$plist" && profile_bundle_matches "$plist"; then
      name=$(/usr/libexec/PlistBuddy -c "Print :Name" "$plist" 2>/dev/null || true)
      [[ -n "$name" ]] && printf '%s\n' "$name"
    fi
    rm -f "$plist"
  done | sort -u
}

matching_app_store_profile_names() {
  local profile_dir
  local profile
  local plist
  local name

  profile_dir="$(profile_dir_path)"
  [[ -d "$profile_dir" ]] || return 0

  for profile in "$profile_dir"/*.mobileprovision; do
    [[ -e "$profile" ]] || continue

    plist="$(mktemp)"
    if decode_profile_to_plist "$profile" "$plist" && profile_is_app_store_connect "$plist"; then
      name=$(/usr/libexec/PlistBuddy -c "Print :Name" "$plist" 2>/dev/null || true)
      [[ -n "$name" ]] && printf '%s\n' "$name"
    fi
    rm -f "$plist"
  done | sort -u
}

count_lines() {
  local value="$1"

  if [[ -z "$value" ]]; then
    echo 0
  else
    printf '%s\n' "$value" | wc -l | tr -d ' '
  fi
}

ensure_manual_distribution_profile() {
  [[ "$SIGNING_STYLE" == "manual" ]] || return 0

  if [[ -n "$PROVISIONING_PROFILE_SPECIFIER" ]]; then
    return 0
  fi

  local profiles
  local profile_count
  profiles="$(matching_app_store_profile_names || true)"
  profile_count="$(count_lines "$profiles")"

  if [[ "$profile_count" -eq 1 ]]; then
    PROVISIONING_PROFILE_SPECIFIER="$profiles"
    pass "App Store Connect provisioning profile: auto-detected"
    return 0
  fi

  if [[ "$profile_count" -gt 1 ]]; then
    fail "Multiple App Store Connect provisioning profiles found for ${APP_BUNDLE_ID}."
    fail "Set PROVISIONING_PROFILE_SPECIFIER to the intended profile name, then retry."
    fail "Do not commit the profile name into this script."
    exit 1
  fi

  fail "No App Store Connect provisioning profile found for ${APP_BUNDLE_ID}."
  fail "TestFlight does not require registered devices; this needs a Distribution → App Store Connect profile."
  fail "Create/download one at developer.apple.com → Certificates, Identifiers & Profiles → Profiles."
  fail "Then double-click the .mobileprovision file or set PROVISIONING_PROFILE_SPECIFIER manually."
  exit 1
}

# Inject CFBundleVersion into the already-built archive's Info.plist.
# Does NOT touch source Info.plist — safe to call on any commit without
# leaving a dirty working tree.  Uses BUILD_NUMBER env var when set (CI),
# falls back to a YYYYMMDDHHmm timestamp for local signed builds.
inject_build_number() {
  local archive_plist="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/Info.plist"

  if [[ ! -f "$archive_plist" ]]; then
    warn "Archive Info.plist not found at: $archive_plist — CFBundleVersion not injected"
    return
  fi

  local build_num
  if [[ -n "${BUILD_NUMBER:-}" ]]; then
    build_num="$BUILD_NUMBER"
  else
    build_num="$(date +%Y%m%d%H%M)"
    info "BUILD_NUMBER not set — using timestamp fallback: $build_num"
  fi

  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_num" "$archive_plist"
  pass "CFBundleVersion set to $build_num in archive (source Info.plist unchanged)"
}

run_xcodebuild() {
  local start
  local status
  local -a statuses
  start=$(date +%s)

  set +e
  if command -v xcpretty &>/dev/null; then
    xcodebuild "$@" 2>&1 | redact_stream | xcpretty
    statuses=("${PIPESTATUS[@]}")
    status="${statuses[0]}"
  else
    xcodebuild "$@" 2>&1 | redact_stream
    statuses=("${PIPESTATUS[@]}")
    status="${statuses[0]}"
  fi
  set -e

  echo "  (took $(elapsed "$start"))"
  return "$status"
}

redact_stream() {
  REDACT_TEAM_ID="${APPLE_TEAM_ID:-}" \
  REDACT_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER:-}" \
  REDACT_AUTH_KEY_PATH="${ASC_AUTH_KEY_PATH:-}" \
  REDACT_AUTH_KEY_ID="${ASC_AUTH_KEY_ID:-}" \
  REDACT_AUTH_ISSUER_ID="${ASC_AUTH_ISSUER_ID:-}" \
  perl -pe '
    BEGIN {
      @pairs = (
        [$ENV{REDACT_TEAM_ID} // "", "<TEAM_ID_REDACTED>"],
        [$ENV{REDACT_PROFILE_SPECIFIER} // "", "<PROFILE_REDACTED>"],
        [$ENV{REDACT_AUTH_KEY_PATH} // "", "<ASC_KEY_PATH_REDACTED>"],
        [$ENV{REDACT_AUTH_KEY_ID} // "", "<ASC_KEY_ID_REDACTED>"],
        [$ENV{REDACT_AUTH_ISSUER_ID} // "", "<ASC_ISSUER_ID_REDACTED>"],
      );
    }
    for my $pair (@pairs) {
      my ($value, $replacement) = @$pair;
      next unless length $value;
      s/\Q$value\E/$replacement/g;
    }
    s/Apple Distribution: [^"\n]*\(<TEAM_ID_REDACTED>\)/Apple Distribution: <SIGNING_IDENTITY_REDACTED> (<TEAM_ID_REDACTED>)/g;
    s/--sign\s+[A-Fa-f0-9]{40}/--sign <CERTIFICATE_SHA1_REDACTED>/g;
    s/\([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\)/(<PROFILE_UUID_REDACTED>)/g;
  '
}

generate_project() {
  header "GENERATE SIGNED PROJECT"
  require_xcodegen
  require_signed_entitlements

  mkdir -p "$PROJECT_DIR"

  local style_value
  local manual_signing_settings=""
  style_value="$(code_sign_style_value)"

  # Scope manual signing only to the generated app-wrapper target. Passing these
  # as command-line build settings makes Xcode apply them to Swift Package
  # targets too, and SPM targets cannot consume provisioning profiles.
  if [[ "$SIGNING_STYLE" == "manual" ]]; then
    manual_signing_settings="        CODE_SIGN_IDENTITY: $(yaml_quote "$SIGNING_CERTIFICATE")"
    if [[ -n "$PROVISIONING_PROFILE_SPECIFIER" ]]; then
      manual_signing_settings="${manual_signing_settings}
        PROVISIONING_PROFILE_SPECIFIER: $(yaml_quote "$PROVISIONING_PROFILE_SPECIFIER")"
    fi
  fi

  # Archive for iOS distribution requires a proper .xcodeproj with a signed
  # app-wrapper target.  SPM executable targets cannot be archived for device
  # distribution without one.  This generated project mirrors the pattern used
  # in UITests/project.yml (app-wrapper + SPM package dependency) but enables
  # distribution signing instead of test-only, unsigned settings.
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
    path: $(yaml_quote "$PACKAGE_PATH")

targets:
  ${APP_TARGET}:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    dependencies:
      - package: EyePostureReminder
    sources:
      - path: $(yaml_quote "${PACKAGE_PATH}/EyePostureReminder/AppIcon.xcassets")
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(yaml_quote "$APP_BUNDLE_ID")
        TARGETED_DEVICE_FAMILY: "1"
        INFOPLIST_FILE: $(yaml_quote "${PACKAGE_PATH}/EyePostureReminder/Info.plist")
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CODE_SIGN_ENTITLEMENTS: $(yaml_quote "$SIGNED_ENTITLEMENTS_PATH")
        DEVELOPMENT_TEAM: $(yaml_quote "$APPLE_TEAM_ID")
        CODE_SIGN_STYLE: $(yaml_quote "$style_value")
        CODE_SIGNING_ALLOWED: "YES"
        CODE_SIGNING_REQUIRED: "YES"
        ENABLE_BITCODE: "NO"
${manual_signing_settings}
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
    warn "  → Install via: developer.apple.com → Certificates → create 'Apple Distribution'"
  fi

  local matching_profiles
  local app_store_profiles
  local matching_count
  local app_store_count
  matching_profiles="$(matching_profile_names || true)"
  app_store_profiles="$(matching_app_store_profile_names || true)"
  matching_count="$(count_lines "$matching_profiles")"
  app_store_count="$(count_lines "$app_store_profiles")"

  if [[ "$app_store_count" -gt 0 ]]; then
    pass "App Store Connect provisioning profile(s) found locally for ${APP_BUNDLE_ID} (${app_store_count} file(s))"
  else
    warn "No App Store Connect provisioning profile found locally for ${APP_BUNDLE_ID}"
    if [[ "$matching_count" -gt 0 ]]; then
      warn "  Found profile(s) for this bundle ID, but they appear to be device-bound development/ad hoc profiles."
    fi
    warn "  TestFlight does not require registered devices."
    warn "  Create Distribution → App Store Connect profile at developer.apple.com → Profiles, then download it."
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

  if [[ -n "${BUILD_NUMBER:-}" ]]; then
    pass "BUILD_NUMBER: set ($BUILD_NUMBER)"
  else
    info "BUILD_NUMBER: not set — timestamp will be used for CFBundleVersion in archive"
  fi

  if [[ -f "$SIGNED_ENTITLEMENTS_PATH" ]]; then
    if entitlements_requests_focus_status "$SIGNED_ENTITLEMENTS_PATH"; then
      warn "Signed entitlements request Focus Status. The App ID/profile must include that capability."
    else
      pass "Signed entitlements: App Store profile-safe"
    fi
  else
    warn "Signed entitlements file missing: $SIGNED_ENTITLEMENTS_PATH"
  fi

  pass "Doctor complete"
}

# Print actionable guidance when xcodebuild archive fails due to account or
# provisioning issues.  Does not print the Team ID or any secret values.
print_archive_failure_hint() {
  echo "" >&2
  fail "xcodebuild archive failed.  Common causes and remedies:"
  echo "" >&2
  warn "Automatic signing (SIGNING_STYLE=automatic):"
  echo "  'No Accounts' means Xcode cannot resolve or download provisioning profiles." >&2
  echo "  Option A — add your Apple ID in Xcode → Settings → Accounts." >&2
  echo "  Option B — supply App Store Connect API key flags (all three required):" >&2
  echo "               ASC_AUTH_KEY_PATH=<path/to/AuthKey_XXXXX.p8> \\" >&2
  echo "               ASC_AUTH_KEY_ID=<key-id> \\" >&2
  echo "               ASC_AUTH_ISSUER_ID=<issuer-id> \\" >&2
  echo "               ./scripts/build_signed.sh export" >&2
  echo "" >&2
  warn "Manual signing (default — SIGNING_STYLE=manual):"
  echo "  'No profiles for canonical app bundle ID' means no matching" >&2
  echo "  App Store Connect Distribution profile is installed locally." >&2
  echo "  1. Create a Distribution → App Store Connect profile at:" >&2
  echo "       developer.apple.com → Certificates, Identifiers & Profiles → Profiles" >&2
  echo "  2. Download and double-click the .mobileprovision file (installs it), or:" >&2
  echo "       PROVISIONING_PROFILE_SPECIFIER=<exact-profile-name> ./scripts/build_signed.sh export" >&2
  echo "" >&2
  warn "Export and upload require a successful archive:"
  echo "  • 'export' signs and packages the archive into a local .ipa." >&2
  echo "  • 'upload' / Transporter only accept an already-signed .ipa." >&2
  echo "  • Fix the archive step above, then re-run 'export' (or 'upload')." >&2
  echo "" >&2
  info "Run './scripts/build_signed.sh doctor' to check all prerequisites."
}

cmd_archive() {
  header "SIGNED ARCHIVE"
  require_xcodebuild
  require_team_id

  ensure_manual_distribution_profile

  generate_project

  rm -rf "$ARCHIVE_PATH"
  mkdir -p "$ARCHIVE_DIR"

  build_auth_flags
  build_provisioning_flags

  info "Scheme:      $SCHEME"
  info "Bundle ID:   $APP_BUNDLE_ID"
  info "Archive:     $ARCHIVE_PATH"

  if ! run_xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    "${PROVISIONING_FLAGS[@]+"${PROVISIONING_FLAGS[@]}"}" \
    "${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}" \
    archive; then
    print_archive_failure_hint
    exit 1
  fi

  inject_build_number
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
    "${PROVISIONING_FLAGS[@]+"${PROVISIONING_FLAGS[@]}"}" \
    "${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}"

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
    "${PROVISIONING_FLAGS[@]+"${PROVISIONING_FLAGS[@]}"}" \
    "${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}"

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
