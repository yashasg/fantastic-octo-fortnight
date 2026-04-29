#!/usr/bin/env bash
# scripts/run.sh — Build, install, and launch on iOS Simulator
#
# Usage:
#   ./scripts/run.sh              # Build & run on first available iPhone simulator
#   ./scripts/run.sh --device "iPhone 16 Pro"   # Target a specific simulator
#   ./scripts/run.sh --no-build   # Skip build (use last successful build)

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
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

# ── Constants ────────────────────────────────────────────────────────────────
SCHEME="EyePostureReminder"
PACKAGE_PATH="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${PACKAGE_PATH}/DerivedData"
# Bundle ID is extracted from the built .app at runtime (see install_and_launch)

XCODE_FLAGS=(
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  ENABLE_BITCODE=NO
  ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO
  ENABLE_APPINTENTS_METADATA_EXTRACTION=NO
)

# ── Defaults ─────────────────────────────────────────────────────────────────
DEVICE_NAME=""
SKIP_BUILD=false

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      DEVICE_NAME="$2"
      shift 2
      ;;
    --no-build)
      SKIP_BUILD=true
      shift
      ;;
    -h|--help)
      echo -e "${BOLD}Usage:${RESET} $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  --device <name>   Target a specific simulator (e.g. \"iPhone 16 Pro\")"
      echo "  --no-build        Skip build, use last successful build artifacts"
      echo "  -h, --help        Show this help"
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Guards ───────────────────────────────────────────────────────────────────
require_xcodebuild() {
  if ! command -v xcodebuild &>/dev/null; then
    fail "xcodebuild not found. Install Xcode from the Mac App Store or via:"
    fail "  xcode-select --install"
    exit 1
  fi
}

require_simctl() {
  if ! xcrun simctl help &>/dev/null 2>&1; then
    fail "simctl not available. Ensure Xcode is properly installed."
    exit 1
  fi
}

# ── Timing helper ─────────────────────────────────────────────────────────────
elapsed() {
  local start=$1
  local end
  end=$(date +%s)
  echo $(( end - start ))s
}

# ── Simulator helpers ─────────────────────────────────────────────────────────

# Find an available iPhone simulator UDID.
# If DEVICE_NAME is set, match that exact name; otherwise pick the first iPhone.
find_simulator() {
  local udid=""
  local name=""

  if [[ -n "$DEVICE_NAME" ]]; then
    # Match specific device name
    local line
    line=$(xcrun simctl list devices available 2>/dev/null \
      | grep "$DEVICE_NAME" \
      | head -1)
    if [[ -z "$line" ]]; then
      fail "Simulator '$DEVICE_NAME' not found. Available devices:"
      xcrun simctl list devices available 2>/dev/null | grep -E "iPhone|iPad" | sed 's/^/  /'
      exit 1
    fi
    udid=$(echo "$line" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
    name=$(echo "$line" | grep -oE '(iPhone|iPad) [^(]+' | sed 's/ *$//')
  else
    # Pick first available iPhone
    local line
    line=$(xcrun simctl list devices available 2>/dev/null \
      | grep -E "iPhone" \
      | head -1)
    if [[ -z "$line" ]]; then
      fail "No iPhone simulators available. Install a simulator runtime via:"
      fail "  Xcode → Settings → Platforms → iOS"
      exit 1
    fi
    udid=$(echo "$line" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
    name=$(echo "$line" | grep -oE 'iPhone [^(]+' | sed 's/ *$//')
  fi

  if [[ -z "$udid" ]]; then
    fail "Could not determine simulator UDID."
    exit 1
  fi

  echo "$udid|$name"
}

# Boot the simulator if it isn't already booted.
ensure_booted() {
  local udid="$1"
  local name="$2"

  local state
  state=$(xcrun simctl list devices 2>/dev/null \
    | grep "$udid" \
    | grep -oE '\(Booted\)' || true)

  if [[ -n "$state" ]]; then
    info "Simulator '$name' is already booted"
  else
    info "Booting simulator '$name'…"
    xcrun simctl boot "$udid" 2>/dev/null || true
    # Open Simulator.app so the user can see the device
    open -a Simulator
    # Give it a moment to finish booting
    sleep 2
    pass "Simulator booted"
  fi
}

# ── Build ─────────────────────────────────────────────────────────────────────
build_for_simulator() {
  local sim_name="$1"

  header "BUILD (Simulator)"
  info "Scheme:      $SCHEME"
  info "Destination: $sim_name"

  local start
  start=$(date +%s)

  local dest="platform=iOS Simulator,name=${sim_name},OS=latest"

  if command -v xcpretty &>/dev/null; then
    xcodebuild build \
      -scheme "$SCHEME" \
      -destination "$dest" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      "${XCODE_FLAGS[@]}" | xcpretty
  else
    xcodebuild build \
      -scheme "$SCHEME" \
      -destination "$dest" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      "${XCODE_FLAGS[@]}"
  fi

  pass "Build succeeded ($(elapsed "$start"))"
}

# ── App Bundle Assembly ───────────────────────────────────────────────────────
# Swift Package executableTargets produce a flat Mach-O binary, not a .app
# bundle. simctl install requires a .app bundle with an Info.plist. This
# function wraps the built executable into a minimal .app structure.
assemble_app_bundle() {
  local app_path="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
  local exe_path="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}"
  local src_plist="${PACKAGE_PATH}/${SCHEME}/Info.plist"

  if [[ ! -f "$exe_path" ]]; then
    fail "Build output not found at: $exe_path"
    fail "The build may have failed silently — re-run without --no-build."
    exit 1
  fi

  # If the .app bundle already exists, refresh the binary and Info.plist
  if [[ -d "$app_path" ]]; then
    header "REFRESHING APP BUNDLE"
    info "Updating binary and Info.plist in existing bundle…"
    cp "$exe_path" "$app_path/${SCHEME}"
    chmod +x "$app_path/${SCHEME}"

    # Always re-process Info.plist so new keys (privacy descriptions etc.) are picked up
    local workspace_name
    workspace_name=$(basename "$PACKAGE_PATH")
    local bundle_id="${workspace_name}.${SCHEME}"
    sed \
      -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/${bundle_id}/g" \
      -e "s/\$(EXECUTABLE_NAME)/${SCHEME}/g" \
      -e "s/\$(PRODUCT_NAME)/${SCHEME}/g" \
      "$src_plist" > "$app_path/Info.plist"

    # Re-embed the SPM resource bundle so Bundle.module resolves at runtime
    embed_resource_bundle "$app_path"
    pass "Bundle refreshed: ${SCHEME}.app"
    return
  fi

  if [[ ! -f "$src_plist" ]]; then
    fail "Info.plist not found at: $src_plist"
    exit 1
  fi

  header "ASSEMBLING APP BUNDLE"
  info "Swift Package executable → .app bundle wrapper…"

  mkdir -p "$app_path"

  cp "$exe_path" "$app_path/${SCHEME}"
  chmod +x "$app_path/${SCHEME}"

  # SPM auto-assigns bundle IDs as: {workspace-name}.{target-name}
  # Derive workspace name from the package root directory.
  local workspace_name
  workspace_name=$(basename "$PACKAGE_PATH")
  local bundle_id="${workspace_name}.${SCHEME}"

  # Process Info.plist — substitute Xcode build variable placeholders
  sed \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/${bundle_id}/g" \
    -e "s/\$(EXECUTABLE_NAME)/${SCHEME}/g" \
    -e "s/\$(PRODUCT_NAME)/${SCHEME}/g" \
    "$src_plist" > "$app_path/Info.plist"

  # Embed the SPM resource bundle so Bundle.module resolves at runtime
  embed_resource_bundle "$app_path"

  pass "App bundle assembled: ${SCHEME}.app (bundle ID: ${bundle_id})"
}

# ── Resource Bundle Embedding ─────────────────────────────────────────────────
# SPM resource bundles land alongside the .app in DerivedData but are NOT
# automatically embedded by xcodebuild for executable targets. Copy the bundle
# inside the .app so Bundle.module can find it via Bundle.main.resourceURL.
embed_resource_bundle() {
  local app_path="$1"
  local resource_bundle="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}_${SCHEME}.bundle"

  if [[ -d "$resource_bundle" ]]; then
    local dest="${app_path}/$(basename "$resource_bundle")"
    rm -rf "$dest"
    cp -r "$resource_bundle" "$dest"
    info "Embedded resource bundle: $(basename "$resource_bundle")"
  else
    warn "Resource bundle not found at: $resource_bundle — localization may not work"
  fi
}

# ── Install & Launch ──────────────────────────────────────────────────────────
install_and_launch() {
  local udid="$1"
  local name="$2"

  header "INSTALL & LAUNCH"

  # Locate the .app bundle in DerivedData
  local app_path="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"

  if [[ ! -d "$app_path" ]]; then
    fail "App bundle not found at: $app_path"
    fail "Run without --no-build to build first."
    exit 1
  fi

  # Extract the real bundle identifier from the built app
  local bundle_id
  bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
  if [[ -z "$bundle_id" ]]; then
    fail "Could not read CFBundleIdentifier from built app."
    exit 1
  fi
  info "Bundle ID:   $bundle_id"

  info "Installing ${SCHEME}.app on '$name'…"
  xcrun simctl install "$udid" "$app_path"
  pass "App installed"

  info "Launching ${SCHEME}…"
  xcrun simctl launch "$udid" "$bundle_id"
  pass "App launched on '$name'"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  local overall_start
  overall_start=$(date +%s)

  require_xcodebuild
  require_simctl

  header "SIMULATOR RUN"

  # Find target simulator
  local sim_info
  sim_info=$(find_simulator)
  local sim_udid="${sim_info%%|*}"
  local sim_name="${sim_info##*|}"

  info "Target: $sim_name ($sim_udid)"

  # Boot simulator
  ensure_booted "$sim_udid" "$sim_name"

  # Build (unless skipped)
  if [[ "$SKIP_BUILD" == "false" ]]; then
    build_for_simulator "$sim_name"
    # Swift Package executable targets produce a flat binary — wrap it in a
    # .app bundle so simctl can install it.
    assemble_app_bundle
  else
    warn "Skipping build (--no-build)"
  fi

  # Install and launch
  install_and_launch "$sim_udid" "$sim_name"

  echo ""
  pass "Done in $(elapsed "$overall_start")"
}

main
