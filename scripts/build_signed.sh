#!/usr/bin/env bash
# scripts/build_signed.sh - Signed archive/export/upload runner for TestFlight.
#
# This script intentionally keeps private signing values out of source control.
# Supply account/team/profile/API-key values through environment variables only.
# It does not run unit tests or UI tests; use scripts/build.sh for validation.
#
# The signed XcodeGen spec is derived from the committed `project.yml` (single
# source of truth) by `scripts/lib/signed_project_spec.py`. The Python helper
# applies the signing/path/versioning overlays needed for distribution while
# preserving everything else from `project.yml`, so adding a target to
# `project.yml` automatically flows into the signed build (and the helper
# fails loudly if the target hasn't been wired through this script's
# entitlement / provisioning-profile env vars). See issue #929.
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
#   SHIELD_CONFIG_ENTITLEMENTS_PATH       default: ShieldConfiguration distribution entitlements
#   DEVICE_ACTIVITY_ENTITLEMENTS_PATH     default: DeviceActivity distribution entitlements

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
PROJECT_SOURCE_SPEC="${PACKAGE_PATH}/project.yml"
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
RESOLVED_BUILD_NUMBER=""

# Extension target support (future-safe; set YES only when extension provisioning
# profiles are available — requires FamilyControls entitlement approval, issue #201).
# When NO (default), the signed archive builds the main app only (current TestFlight path).
EXTENSION_PROFILES_AVAILABLE="${EXTENSION_PROFILES_AVAILABLE:-NO}"
SHIELD_CONFIG_BUNDLE_ID="${SHIELD_CONFIG_BUNDLE_ID:-${APP_BUNDLE_ID}.shieldconfiguration}"
DEVICE_ACTIVITY_BUNDLE_ID="${DEVICE_ACTIVITY_BUNDLE_ID:-${APP_BUNDLE_ID}.deviceactivitymonitor}"
# Individual extension provisioning profile specifiers (manual signing only).
# Required when EXTENSION_PROFILES_AVAILABLE=YES and SIGNING_STYLE=manual.
# Leave empty only when SIGNING_STYLE=automatic.
SHIELD_CONFIG_PROFILE="${SHIELD_CONFIG_PROFILE:-}"
DEVICE_ACTIVITY_PROFILE="${DEVICE_ACTIVITY_PROFILE:-}"
SHIELD_CONFIG_ENTITLEMENTS_PATH="${SHIELD_CONFIG_ENTITLEMENTS_PATH:-${PACKAGE_PATH}/Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.Distribution.entitlements}"
DEVICE_ACTIVITY_ENTITLEMENTS_PATH="${DEVICE_ACTIVITY_ENTITLEMENTS_PATH:-${PACKAGE_PATH}/Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.Distribution.entitlements}"

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
  echo ""
  echo "Extension support (blocked on issue #201 — FamilyControls entitlement approval):"
  echo "  EXTENSION_PROFILES_AVAILABLE=YES   Include extension targets in signed archive"
  echo "  SHIELD_CONFIG_BUNDLE_ID=<id>       Default: APP_BUNDLE_ID.shieldconfiguration"
  echo "  DEVICE_ACTIVITY_BUNDLE_ID=<id>     Default: APP_BUNDLE_ID.deviceactivitymonitor"
  echo "  SHIELD_CONFIG_PROFILE=<name>       Profile specifier for ShieldConfigurationExtension"
  echo "  DEVICE_ACTIVITY_PROFILE=<name>     Profile specifier for DeviceActivityMonitorExtension"
  echo "  SHIELD_CONFIG_ENTITLEMENTS_PATH=<path>"
  echo "  DEVICE_ACTIVITY_ENTITLEMENTS_PATH=<path>"
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

require_python3_yaml() {
  require_tool "python3" "Install with: brew install python@3"
  if ! python3 -c "import yaml" >/dev/null 2>&1; then
    info "PyYAML not found — installing into the active python3 (--user)…"
    if ! python3 -m pip install --user --quiet pyyaml >&2; then
      fail "Failed to install PyYAML. Install it manually:"
      fail "  python3 -m pip install --user pyyaml"
      exit 1
    fi
  fi
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

entitlements_requests_app_groups() {
  local entitlements_path="$1"
  /usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups" "$entitlements_path" >/dev/null 2>&1
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

project_setting_value() {
  local key="$1"
  local value
  value="$(awk -v key="$key" '$1 == key ":" { gsub(/"/, "", $2); print $2; exit }' "$PROJECT_SOURCE_SPEC")"
  if [[ -z "$value" ]]; then
    fail "Missing ${key} in project.yml"
    exit 1
  fi
  echo "$value"
}

archive_marketing_version() {
  if [[ -n "${MARKETING_VERSION:-}" ]]; then
    echo "$MARKETING_VERSION"
  else
    project_setting_value MARKETING_VERSION
  fi
}

archive_build_number() {
  if [[ -z "$RESOLVED_BUILD_NUMBER" ]]; then
    if [[ -n "${BUILD_NUMBER:-}" ]]; then
      RESOLVED_BUILD_NUMBER="$BUILD_NUMBER"
    else
      RESOLVED_BUILD_NUMBER="$(date +%Y%m%d%H%M)"
      info "BUILD_NUMBER not set — using timestamp fallback: $RESOLVED_BUILD_NUMBER" >&2
    fi
  fi

  echo "$RESOLVED_BUILD_NUMBER"
}

validate_app_store_upload_version() {
  [[ "$EXPORT_METHOD" == "app-store-connect" ]] || return 0

  local marketing_version
  marketing_version="$(archive_marketing_version)"

  if [[ -z "$marketing_version" ]]; then
    fail "App Store uploads require MARKETING_VERSION; resolved value is empty."
    fail "Set MARKETING_VERSION explicitly or run './scripts/build.sh version <semver>' to commit a version."
    exit 1
  fi

  if [[ ! "$marketing_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    fail "App Store uploads require a semver MARKETING_VERSION (MAJOR.MINOR or MAJOR.MINOR.PATCH); got '${marketing_version}'."
    fail "Run './scripts/build.sh version <semver>' to set a valid value, then re-dispatch."
    exit 1
  fi

  case "$marketing_version" in
    0|0.0|0.0.0)
      fail "App Store uploads cannot use placeholder MARKETING_VERSION '${marketing_version}'."
      fail "Bump to a real release version (e.g. '0.2.0') before uploading."
      exit 1
      ;;
  esac

  local project_marketing_version
  project_marketing_version="$(project_setting_value MARKETING_VERSION)"
  if [[ -n "$project_marketing_version" && "$marketing_version" != "$project_marketing_version" ]]; then
    fail "MARKETING_VERSION override '${marketing_version}' does not match project.yml ('${project_marketing_version}')."
    fail "Either run './scripts/build.sh version ${marketing_version}' and commit, or align the override to '${project_marketing_version}'."
    exit 1
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

ensure_manual_extension_profiles() {
  [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]] || return 0
  [[ "$SIGNING_STYLE" == "manual" ]] || return 0

  if [[ -z "$SHIELD_CONFIG_PROFILE" || -z "$DEVICE_ACTIVITY_PROFILE" ]]; then
    fail "Extension profiles requested with manual signing, but extension profile names are missing."
    fail "Create App Store Connect profiles for the extension bundle IDs, then set:"
    fail "  SHIELD_CONFIG_PROFILE=<ShieldConfiguration profile name>"
    fail "  DEVICE_ACTIVITY_PROFILE=<DeviceActivityMonitor profile name>"
    fail "Or use SIGNING_STYLE=automatic with Xcode-managed signing."
    exit 1
  fi
}

ensure_extension_entitlements() {
  [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]] || return 0

  if [[ ! -f "$SHIELD_CONFIG_ENTITLEMENTS_PATH" ]]; then
    fail "ShieldConfiguration entitlements file not found: $SHIELD_CONFIG_ENTITLEMENTS_PATH"
    exit 1
  fi

  if [[ ! -f "$DEVICE_ACTIVITY_ENTITLEMENTS_PATH" ]]; then
    fail "DeviceActivityMonitor entitlements file not found: $DEVICE_ACTIVITY_ENTITLEMENTS_PATH"
    exit 1
  fi
}

# Inject CFBundleVersion into the already-built archive's Info.plist(s).
# Does NOT touch source Info.plist — safe to call on any commit without
# leaving a dirty working tree.  Uses BUILD_NUMBER env var when set (CI),
# falls back to a YYYYMMDDHHmm timestamp for local signed builds.
#
# When EXTENSION_PROFILES_AVAILABLE=YES, extension .appex Info.plists are
# updated to the same build number.  Apple rejects TestFlight uploads where
# CFBundleVersion of a nested extension differs from the container app.
inject_build_number() {
  local archive_plist="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/Info.plist"

  if [[ ! -f "$archive_plist" ]]; then
    warn "Archive Info.plist not found at: $archive_plist — CFBundleVersion not injected"
    return
  fi

  local build_num
  build_num="$(archive_build_number)"

  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_num" "$archive_plist"
  pass "CFBundleVersion set to $build_num in main app archive (source Info.plist unchanged)"

  # Sync extension CFBundleVersions when extensions are included in the archive.
  # Mismatched versions cause App Store Connect to reject the upload with:
  #   "The bundle version ... in the extension ... must be the same as in the containing app."
  if [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]]; then
    local plugins_dir="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/PlugIns"
    for appex_plist in "${plugins_dir}"/*.appex/Info.plist; do
      if [[ -f "$appex_plist" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_num" "$appex_plist" 2>/dev/null \
          || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_num" "$appex_plist"
        pass "CFBundleVersion set to $build_num in $(basename "$(dirname "$appex_plist")")"
      fi
    done
  fi
}

verify_archived_version() {
  local archive_plist="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/Info.plist"

  if [[ ! -f "$archive_plist" ]]; then
    fail "Archive Info.plist not found at: $archive_plist"
    return 1
  fi

  local expected_marketing
  local expected_build
  local actual_marketing
  local actual_build
  expected_marketing="$(archive_marketing_version)"
  expected_build="$(archive_build_number)"
  actual_marketing=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$archive_plist" 2>/dev/null || true)
  actual_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$archive_plist" 2>/dev/null || true)

  if [[ "$actual_marketing" != "$expected_marketing" ]]; then
    fail "Archive marketing version mismatch: expected ${expected_marketing}, got ${actual_marketing:-<missing>}"
    return 1
  fi

  if [[ "$actual_build" != "$expected_build" ]]; then
    fail "Archive build number mismatch: expected ${expected_build}, got ${actual_build:-<missing>}"
    return 1
  fi

  pass "Archive version verified: ${actual_marketing} (${actual_build})"

  if [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]]; then
    local plugins_dir="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/PlugIns"
    local extension_plists=(
      "${plugins_dir}/ShieldConfigurationExtension.appex/Info.plist"
      "${plugins_dir}/DeviceActivityMonitorExtension.appex/Info.plist"
    )
    local extension_plist
    for extension_plist in "${extension_plists[@]}"; do
      if [[ ! -f "$extension_plist" ]]; then
        fail "Extension Info.plist not found at: $extension_plist"
        return 1
      fi

      actual_marketing=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$extension_plist" 2>/dev/null || true)
      actual_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$extension_plist" 2>/dev/null || true)

      if [[ "$actual_marketing" != "$expected_marketing" ]]; then
        fail "$(basename "$(dirname "$extension_plist")") marketing version mismatch: expected ${expected_marketing}, got ${actual_marketing:-<missing>}"
        return 1
      fi

      if [[ "$actual_build" != "$expected_build" ]]; then
        fail "$(basename "$(dirname "$extension_plist")") build number mismatch: expected ${expected_build}, got ${actual_build:-<missing>}"
        return 1
      fi
    done

    pass "Extension archive versions match containing app"
  fi
}

verify_archived_main_app_privacy_manifest() {
  local privacy_manifest="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/PrivacyInfo.xcprivacy"

  if [[ ! -f "$privacy_manifest" ]]; then
    fail "Main app archive is missing PrivacyInfo.xcprivacy at: ${privacy_manifest}"
    fail "App Store privacy manifest acceptance requires the archived .app to bundle PrivacyInfo.xcprivacy."
    fail "Confirm EyePostureReminder/PrivacyInfo.xcprivacy is copied into the bundle by the archive build."
    return 1
  fi

  pass "Main app archive includes PrivacyInfo.xcprivacy"
}

verify_archived_extensions() {
  [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]] || return 0

  local plugins_dir="${ARCHIVE_PATH}/Products/Applications/${APP_TARGET}.app/PlugIns"
  local missing=0
  local shield_appex="${plugins_dir}/ShieldConfigurationExtension.appex"
  local monitor_appex="${plugins_dir}/DeviceActivityMonitorExtension.appex"

  if [[ ! -d "$plugins_dir" ]]; then
    fail "Archive is missing PlugIns directory: $plugins_dir"
    return 1
  fi

  if [[ ! -d "$shield_appex" ]]; then
    fail "Archive is missing ShieldConfiguration extension binary."
    missing=1
  fi

  if [[ ! -d "$monitor_appex" ]]; then
    fail "Archive is missing DeviceActivityMonitor extension binary."
    missing=1
  fi

  if [[ "$missing" -ne 0 ]]; then
    fail "Extension archive validation failed. Check extension target embedding/signing settings."
    return 1
  fi

  if [[ ! -f "${shield_appex}/PrivacyInfo.xcprivacy" ]]; then
    fail "ShieldConfiguration extension is missing PrivacyInfo.xcprivacy."
    missing=1
  fi

  if [[ ! -f "${monitor_appex}/PrivacyInfo.xcprivacy" ]]; then
    fail "DeviceActivityMonitor extension is missing PrivacyInfo.xcprivacy."
    missing=1
  fi

  if [[ "$missing" -ne 0 ]]; then
    fail "Extension archive privacy manifest validation failed."
    return 1
  fi

  pass "Archive includes ShieldConfiguration + DeviceActivityMonitor extensions"
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
  REDACT_SHIELD_CONFIG_PROFILE="${SHIELD_CONFIG_PROFILE:-}" \
  REDACT_DEVICE_ACTIVITY_PROFILE="${DEVICE_ACTIVITY_PROFILE:-}" \
  REDACT_AUTH_KEY_PATH="${ASC_AUTH_KEY_PATH:-}" \
  REDACT_AUTH_KEY_ID="${ASC_AUTH_KEY_ID:-}" \
  REDACT_AUTH_ISSUER_ID="${ASC_AUTH_ISSUER_ID:-}" \
  perl -pe '
    BEGIN {
      @pairs = (
        [$ENV{REDACT_TEAM_ID} // "", "<TEAM_ID_REDACTED>"],
        [$ENV{REDACT_PROFILE_SPECIFIER} // "", "<PROFILE_REDACTED>"],
        [$ENV{REDACT_SHIELD_CONFIG_PROFILE} // "", "<SHIELD_CONFIG_PROFILE_REDACTED>"],
        [$ENV{REDACT_DEVICE_ACTIVITY_PROFILE} // "", "<DEVICE_ACTIVITY_PROFILE_REDACTED>"],
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
  require_python3_yaml
  require_signed_entitlements

  mkdir -p "$PROJECT_DIR"

  local style_value
  local marketing_version
  local build_number
  local extension_profiles_flag
  style_value="$(code_sign_style_value)"
  marketing_version="$(archive_marketing_version)"
  build_number="$(archive_build_number)"

  if [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]]; then
    extension_profiles_flag="yes"
    warn "EXTENSION_PROFILES_AVAILABLE=YES — including extension targets in signed archive."
    warn "This requires FamilyControls entitlement approval (#201) and extension profiles."
  else
    extension_profiles_flag="no"
    info "EXTENSION_PROFILES_AVAILABLE=NO — building main app only (current TestFlight path)."
    info "Set EXTENSION_PROFILES_AVAILABLE=YES with extension profiles to include extensions."
  fi

  # The signed-build spec is a transformation of the committed project.yml
  # (single source of truth — see scripts/lib/signed_project_spec.py). The
  # transformation applies:
  #
  #   1. Distribution signing settings per target (replaces the simulator
  #      NO/empty signing values from project.yml with Apple Distribution
  #      and optional manual provisioning profile pins).
  #   2. .Distribution.entitlements variants for each target.
  #   3. Marketing version / build number overrides from this script.
  #   4. Absolute paths (the signed .xcodeproj is generated outside
  #      ScreenTimeExtensions/, so the project.yml relative paths need to
  #      be re-anchored).
  #   5. A PrivacyInfo.xcprivacy copy step (App Store privacy nutrition
  #      label requirement; the simulator build doesn't need it).
  #   6. A single archive-focused scheme.
  #   7. Optional pruning of extension targets when their provisioning
  #      profiles are not available (gated on #201).
  #
  # The helper fails loudly if project.yml adds a target the signing
  # path hasn't been wired for — see _TARGET_SIGNING_PROFILE in the
  # helper. Closes the project.yml ↔ build_signed.sh drift (#929).
  python3 "${PACKAGE_PATH}/scripts/lib/signed_project_spec.py" \
    --source "$PROJECT_SOURCE_SPEC" \
    --output "$PROJECT_SPEC" \
    --app-name "$APP_TARGET" \
    --package-path "$PACKAGE_PATH" \
    --marketing-version "$marketing_version" \
    --build-number "$build_number" \
    --team-id "$APPLE_TEAM_ID" \
    --signing-style "$style_value" \
    --code-sign-identity "$SIGNING_CERTIFICATE" \
    --signed-entitlements "$SIGNED_ENTITLEMENTS_PATH" \
    --shield-config-entitlements "$SHIELD_CONFIG_ENTITLEMENTS_PATH" \
    --device-activity-entitlements "$DEVICE_ACTIVITY_ENTITLEMENTS_PATH" \
    --provisioning-profile "$PROVISIONING_PROFILE_SPECIFIER" \
    --shield-config-profile "$SHIELD_CONFIG_PROFILE" \
    --device-activity-profile "$DEVICE_ACTIVITY_PROFILE" \
    --extension-profiles-available "$extension_profiles_flag" \
    --configuration "$CONFIGURATION"

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
    if [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]]; then
      /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:${SHIELD_CONFIG_BUNDLE_ID} string ${SHIELD_CONFIG_PROFILE}" "$EXPORT_OPTIONS_PLIST"
      /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:${DEVICE_ACTIVITY_BUNDLE_ID} string ${DEVICE_ACTIVITY_PROFILE}" "$EXPORT_OPTIONS_PLIST"
    fi
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
    elif entitlements_requests_app_groups "$SIGNED_ENTITLEMENTS_PATH"; then
      warn "Signed entitlements request App Groups. The App ID/profile must include group.com.yashasg.kshana."
    else
      pass "Signed entitlements: App Store profile-safe"
    fi
  else
    warn "Signed entitlements file missing: $SIGNED_ENTITLEMENTS_PATH"
  fi

  if [[ "$EXTENSION_PROFILES_AVAILABLE" == "YES" ]]; then
    warn "EXTENSION_PROFILES_AVAILABLE=YES — extension targets will be included (requires #201 FamilyControls approval)"
    if [[ "$SIGNING_STYLE" == "manual" ]]; then
      if [[ -n "$SHIELD_CONFIG_PROFILE" && -n "$DEVICE_ACTIVITY_PROFILE" ]]; then
        pass "Extension profile specifiers: set"
      else
        warn "Extension profile specifiers missing — set SHIELD_CONFIG_PROFILE and DEVICE_ACTIVITY_PROFILE before archiving"
      fi
    fi
  else
    info "EXTENSION_PROFILES_AVAILABLE=NO — extension targets excluded from archive (blocked on #201)"
    echo "" >&2
    echo "  Post-#201 unblock checklist (complete in order):" >&2
    echo "    1. Confirm FamilyControls entitlement approved at developer.apple.com → App IDs" >&2
    echo "    2. Add com.apple.developer.family-controls to:" >&2
    echo "         EyePostureReminder/EyePostureReminder.entitlements" >&2
    echo "         EyePostureReminder/EyePostureReminder.Distribution.entitlements" >&2
    echo "         Extensions/ShieldConfigurationExtension/*.entitlements (both variants)" >&2
    echo "         Extensions/DeviceActivityMonitorExtension/*.entitlements (both variants)" >&2
    echo "    3. Regenerate App Store Connect provisioning profiles for all three bundle IDs" >&2
    echo "    4. Download profiles; verify via this doctor command with EXTENSION_PROFILES_AVAILABLE=YES" >&2
    echo "    5. Add repo secrets: SHIELD_CONFIG_PROVISION_PROFILE_BASE64," >&2
    echo "         DEVICE_ACTIVITY_PROVISION_PROFILE_BASE64, SHIELD_CONFIG_PROFILE_SPECIFIER," >&2
    echo "         DEVICE_ACTIVITY_PROFILE_SPECIFIER" >&2
    echo "    6. Run TestFlight workflow with EXTENSION_PROFILES_AVAILABLE=YES to include extensions" >&2
    echo "  See: https://github.com/yashasg/fantastic-octo-fortnight/issues/201" >&2
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
  ensure_manual_extension_profiles
  ensure_extension_entitlements

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
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    archive; then
    print_archive_failure_hint
    exit 1
  fi

  inject_build_number
  verify_archived_version
  verify_archived_main_app_privacy_manifest
  verify_archived_extensions
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

  IPA_PATH="${EXPORT_PATH}/EyePostureReminder.ipa"
  if [[ ! -f "$IPA_PATH" ]]; then
    fail "Export succeeded but IPA not found at expected path: $IPA_PATH"
    exit 1
  fi

  pass "Export complete: $EXPORT_PATH"
}

cmd_upload() {
  validate_app_store_upload_version
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

  IPA_PATH="${EXPORT_PATH}/EyePostureReminder.ipa"
  if [[ ! -f "$IPA_PATH" ]]; then
    fail "Upload-mode export completed but IPA not found at expected path: $IPA_PATH — aborting before artifact upload."
    exit 1
  fi

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
