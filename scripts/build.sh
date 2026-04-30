#!/usr/bin/env bash
# scripts/build.sh — Standardized build/test/lint runner for Eye & Posture Reminder
#
# Usage:
#   ./scripts/build.sh build           # Compile the project
#   ./scripts/build.sh test            # Run unit tests
#   ./scripts/build.sh lint            # Run SwiftLint (if available)
#   ./scripts/build.sh clean           # Clean build artifacts
#   ./scripts/build.sh all             # build + lint + test
#   ./scripts/build.sh check           # Quick syntax check (compile only, no tests)
#   ./scripts/build.sh version         # Show current marketing version
#   ./scripts/build.sh version 0.2.0   # Set marketing version in Info.plist

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
TEST_SCHEME="EyePostureReminderTests"
UI_TEST_SCHEME="EyePostureReminderUITests"
PACKAGE_PATH="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${PACKAGE_PATH}/DerivedData"

XCODE_FLAGS=(
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  ENABLE_BITCODE=NO
  ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO
  ENABLE_APPINTENTS_METADATA_EXTRACTION=NO
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
)

# ── Guards ───────────────────────────────────────────────────────────────────
require_xcodebuild() {
  if ! command -v xcodebuild &>/dev/null; then
    fail "xcodebuild not found. Install Xcode from the Mac App Store or via:"
    fail "  xcode-select --install"
    exit 1
  fi
}

# ── Destination detection ─────────────────────────────────────────────────────
# Returns an xcodebuild -destination string. Respects $SIMULATOR env var when
# set (used by CI), otherwise probes for an available iPhone simulator and
# falls back to Mac Catalyst if no iOS runtimes are found.
detect_destination() {
  # CI (and local overrides) can set $SIMULATOR explicitly — honour it.
  if [[ -n "${SIMULATOR:-}" ]]; then
    echo "$SIMULATOR"
    return
  fi

  local catalyst_dest="platform=macOS,variant=Mac Catalyst"

  # Check whether any iOS Simulator runtime is installed
  if xcrun simctl list runtimes 2>/dev/null | grep -q "iOS"; then
    # Find the first available iPhone simulator dynamically
    local sim_name
    sim_name=$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone [^(]+' | head -1 | sed 's/ *$//')
    if [ -n "$sim_name" ]; then
      echo "platform=iOS Simulator,name=${sim_name}"
    else
      echo "platform=iOS Simulator,OS=latest"
    fi
  else
    warn "No iOS Simulator runtimes found — falling back to Mac Catalyst" >&2
    echo "$catalyst_dest"
  fi
}

# ── Timing helper ─────────────────────────────────────────────────────────────
elapsed() {
  local start=$1
  local end
  end=$(date +%s)
  echo $(( end - start ))s
}

# ── xcodebuild runner (xcpretty fallback) ─────────────────────────────────────
run_xcodebuild() {
  local start
  start=$(date +%s)

  if command -v xcpretty &>/dev/null; then
    xcodebuild "$@" "${XCODE_FLAGS[@]}" | xcpretty
  else
    xcodebuild "$@" "${XCODE_FLAGS[@]}"
  fi

  echo "  (took $(elapsed "$start"))"
}

summarize_xcresult_failures() {
  local bundle_path="$1"

  if [[ ! -d "$bundle_path" ]]; then
    warn "Result bundle not found at: $bundle_path"
    return
  fi

  python3 - "$bundle_path" <<'PY'
import json
import subprocess
import sys

bundle_path = sys.argv[1]

def get_root(path: str):
    commands = [
        ["xcrun", "xcresulttool", "get", "object", "--legacy", "--path", path, "--format", "json"],
        ["xcrun", "xcresulttool", "get", "object", "--path", path, "--format", "json"],
    ]
    for command in commands:
        try:
            return json.loads(subprocess.check_output(command, stderr=subprocess.DEVNULL))
        except Exception:
            continue
    return None

root = get_root(bundle_path)
if not root:
    print("⚠ Unable to parse xcresult bundle for failure details")
    sys.exit(0)

failures = (
    root.get("actions", {})
    .get("_values", [{}])[0]
    .get("actionResult", {})
    .get("issues", {})
    .get("testFailureSummaries", {})
    .get("_values", [])
)

if not failures:
    print("⚠ xcodebuild failed, but xcresult has no testFailureSummaries")
    sys.exit(0)

print(f"✗ xcresult reports {len(failures)} failing tests:")
max_items = 20
for item in failures[:max_items]:
    test_name = item.get("testCaseName", {}).get("_value", "<unknown test>")
    message = item.get("message", {}).get("_value", "").splitlines()[0]
    print(f"  - {test_name}: {message}")

if len(failures) > max_items:
    print(f"  ... and {len(failures) - max_items} more")
PY
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_build() {
  header "BUILD"
  require_xcodebuild
  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "Scheme:      $SCHEME"

  run_xcodebuild build \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH"

  pass "Build succeeded"
}

cmd_check() {
  warn "check is an alias for build (xcodebuild has no syntax-only mode)"
  cmd_build
}

cmd_test() {
  header "TEST"
  require_xcodebuild
  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "Test scheme: $SCHEME (includes $TEST_SCHEME)"

  rm -rf "${PACKAGE_PATH}/TestResults.xcresult"

  if ! run_xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "${PACKAGE_PATH}/TestResults.xcresult" \
    -enableCodeCoverage YES; then
    fail "xcodebuild test failed"
    summarize_xcresult_failures "${PACKAGE_PATH}/TestResults.xcresult"
    exit 1
  fi

  pass "Tests passed"
}

cmd_lint() {
  header "LINT"
  local start
  start=$(date +%s)

  if command -v swiftlint &>/dev/null; then
    info "Running SwiftLint…"
    swiftlint lint --strict --quiet "$PACKAGE_PATH"
    pass "Lint passed (took $(elapsed "$start"))"
  else
    fail "swiftlint not found. Install with: brew install swiftlint"
    exit 1
  fi
}

cmd_clean() {
  header "CLEAN"
  require_xcodebuild
  local dest
  dest=$(detect_destination)

  info "Cleaning DerivedData and build products…"
  xcodebuild clean \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "${XCODE_FLAGS[@]}" \
    | grep -E "^(Build|Clean|error:|warning:)" || true

  rm -rf "${PACKAGE_PATH}/TestResults.xcresult"
  pass "Clean complete"
}

cmd_uitest() {
  header "UI TEST"
  require_xcodebuild

  local result_bundle_path="${PACKAGE_PATH}/UITestResults.xcresult"
  local only_testing_filters=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only-testing)
        if [[ $# -lt 2 ]]; then
          fail "--only-testing requires a value (e.g. EyePostureReminderUITests/HomeScreenTests)"
          exit 1
        fi
        only_testing_filters+=("$2")
        shift 2
        ;;
      --only-testing=*)
        only_testing_filters+=("${1#*=}")
        shift
        ;;
      --result-bundle-path)
        if [[ $# -lt 2 ]]; then
          fail "--result-bundle-path requires a path value"
          exit 1
        fi
        result_bundle_path="$2"
        shift 2
        ;;
      --result-bundle-path=*)
        result_bundle_path="${1#*=}"
        shift
        ;;
      *)
        fail "Unknown uitest option: '$1'"
        echo ""
        usage
        exit 1
        ;;
    esac
  done

  if [[ "$result_bundle_path" != /* ]]; then
    result_bundle_path="${PACKAGE_PATH}/${result_bundle_path}"
  fi

  local only_testing_args=()
  for only_testing_filter in "${only_testing_filters[@]}"; do
    only_testing_args+=(-only-testing "$only_testing_filter")
  done

  local project="${PACKAGE_PATH}/UITests/EyePostureReminderUITests.xcodeproj"
  local project_spec="${PACKAGE_PATH}/UITests/project.yml"
  local project_file="${project}/project.pbxproj"

  # Generate xcodeproj if not present or if the XcodeGen spec changed.
  if [[ ! -d "$project" || ! -f "$project_file" || "$project_spec" -nt "$project_file" ]]; then
    info "UITest xcodeproj missing or stale — running setup…"
    "${PACKAGE_PATH}/scripts/setup-uitests.sh"
  fi

  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "UI Test scheme: $UI_TEST_SCHEME"
  info "Result bundle: $result_bundle_path"
  if [[ ${#only_testing_filters[@]} -gt 0 ]]; then
    info "Running filtered UI tests:"
    for only_testing_filter in "${only_testing_filters[@]}"; do
      info "  - $only_testing_filter"
    done
  fi

  rm -rf "$result_bundle_path"

  # Step 1: build-for-testing generates a .xctestrun that correctly resolves
  # UITargetAppPath to EyePostureReminder.app (not the flat SPM binary).
  # Step 2: test-without-building uses the xctestrun directly, bypassing the
  # TEST_TARGET_NAME ambiguity that occurs when 'xcodebuild test' runs both
  # build and test in a single invocation.
  info "Step 1/2 — building for testing…"
  run_xcodebuild build-for-testing \
    -project "$project" \
    -scheme "$UI_TEST_SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH"

  # Locate the generated xctestrun file
  local xctestrun
  xctestrun=$(find "${DERIVED_DATA_PATH}/Build/Products" \
    -name "${UI_TEST_SCHEME}_*.xctestrun" \
    -maxdepth 1 \
    -print \
    | sort | tail -1)

  if [[ -z "$xctestrun" ]]; then
    fail "No .xctestrun found after build-for-testing"
    exit 1
  fi
  info "xctestrun: $xctestrun"

  # Patch UITargetAppPath so xctestrun always resolves to the .app bundle
  # (build-for-testing may generate a path pointing at the flat SPM binary).
  info "Patching UITargetAppPath in xctestrun…"
  /usr/libexec/PlistBuddy \
    -c "Set :${UI_TEST_SCHEME}:UITargetAppPath __TESTROOT__/Debug-iphonesimulator/EyePostureReminder.app" \
    "$xctestrun" || warn "PlistBuddy patch failed — xctestrun may already have the correct path"

  # Ensure the .app bundle contains the executable and resource bundle.
  # The xcodeproj app-wrapper target builds them to BUILT_PRODUCTS_DIR but
  # doesn't always copy them into the .app; copy them if missing.
  local products_dir="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator"
  local app_dir="${products_dir}/EyePostureReminder.app"
  local spm_bin="${products_dir}/EyePostureReminder"
  local app_bin="${app_dir}/EyePostureReminder"
  local bundle_src="${products_dir}/EyePostureReminder_EyePostureReminder.bundle"
  local bundle_dst="${app_dir}/EyePostureReminder_EyePostureReminder.bundle"

  if [[ -f "$spm_bin" && ! -f "$app_bin" ]]; then
    info "Copying SPM binary into app bundle…"
    cp "$spm_bin" "$app_bin"
    chmod +x "$app_bin"
  fi
  if [[ -d "$bundle_src" ]]; then
    info "Copying resource bundle into app bundle…"
    rm -rf "$bundle_dst"
    cp -r "$bundle_src" "$bundle_dst"
  fi

  info "Step 2/2 — running UI tests…"

  # Retry logic: simulator app launch can fail transiently in CI when
  # SpringBoard hasn't fully settled. Retry up to 3 times with increasing
  # delays to handle FBSOpenApplicationServiceErrorDomain / RequestDenied.
  local max_attempts=3
  local attempt=1
  while true; do
    info "Attempt $attempt/$max_attempts..."
    rm -rf "$result_bundle_path"

    if run_xcodebuild test-without-building \
      -xctestrun "$xctestrun" \
      -destination "$dest" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -resultBundlePath "$result_bundle_path" \
      -disable-concurrent-destination-testing \
      -parallel-testing-enabled NO \
      "${only_testing_args[@]}"; then
      break
    fi

    if (( attempt >= max_attempts )); then
      fail "UI tests failed after $max_attempts attempts"
      summarize_xcresult_failures "$result_bundle_path"
      exit 1
    fi

    warn "Attempt $attempt failed -- retrying in $((attempt * 15))s..."
    sleep $((attempt * 15))
    attempt=$((attempt + 1))
  done

  pass "UI tests passed"
}

cmd_all() {
  header "ALL (build → lint → test)"
  local overall_start
  overall_start=$(date +%s)

  cmd_build
  cmd_lint
  cmd_test

  pass "All steps passed in $(elapsed "$overall_start")"
}

# ── Version management ────────────────────────────────────────────────────────
# Marketing version lives in EyePostureReminder/Info.plist (CFBundleShortVersionString).
# Build number (CFBundleVersion) is auto-incremented by CI via github.run_number.
# To bump manually: ./scripts/build.sh version <new-version>
PLIST="${PACKAGE_PATH}/EyePostureReminder/Info.plist"

cmd_version() {
  local new_version="${1:-}"

  if [[ -z "$new_version" ]]; then
    # Show current version
    if [[ ! -f "$PLIST" ]]; then
      fail "Info.plist not found at: $PLIST"
      exit 1
    fi
    local current
    current=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null)
    local build
    build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null)
    echo -e "${BOLD}Marketing version:${RESET} ${current}"
    echo -e "${BOLD}Build number:${RESET}     ${build} (overwritten by CI with github.run_number)"
  else
    # Validate semver format (digits only — Apple requires numeric segments)
    if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      fail "Version must be numeric semver, e.g. 0.2.0 (no pre-release labels)"
      exit 1
    fi
    if [[ ! -f "$PLIST" ]]; then
      fail "Info.plist not found at: $PLIST"
      exit 1
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $new_version" "$PLIST"
    pass "Marketing version set to ${new_version}"
    info "Remember to commit Info.plist and tag: git tag -a v${new_version} -m 'Release ${new_version}'"
  fi
}

usage() {
  echo -e "${BOLD}Usage:${RESET} $(basename "$0") <command>"
  echo ""
  echo "Commands:"
  echo "  build              Compile the project"
  echo "  test               Run unit tests"
  echo "  uitest             Run UI tests (generates xcodeproj if needed)"
  echo "                     Options:"
  echo "                       --only-testing <target/class[/test]>"
  echo "                       --result-bundle-path <path>"
  echo "  lint               Run SwiftLint (skipped gracefully if not installed)"
  echo "  clean              Remove build artifacts"
  echo "  all                build + lint + test"
  echo "  check              Alias for build (xcodebuild has no syntax-only mode)"
  echo "  version            Show current marketing version"
  echo "  version <x.y.z>   Set marketing version in Info.plist"
}

# ── Entry point ───────────────────────────────────────────────────────────────
COMMAND="${1:-}"

case "$COMMAND" in
  build)   cmd_build ;;
  test)    cmd_test  ;;
  uitest)  shift || true; cmd_uitest "$@" ;;
  lint)    cmd_lint  ;;
  clean)   cmd_clean ;;
  all)     cmd_all   ;;
  check)   cmd_check ;;
  version) cmd_version "${2:-}" ;;
  *)
    fail "Unknown command: '${COMMAND}'"
    echo ""
    usage
    exit 1
    ;;
esac
