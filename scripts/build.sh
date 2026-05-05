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
#   ./scripts/build.sh version 0.2.0   # Set marketing version in project.yml

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
PROJECT_SPEC_PATH="${PACKAGE_PATH}/project.yml"

project_setting_value() {
  local key="$1"
  local value
  value="$(awk -v key="$key" '$1 == key ":" { gsub(/"/, "", $2); print $2; exit }' "$PROJECT_SPEC_PATH")"
  if [[ -z "$value" ]]; then
    fail "Missing ${key} in project.yml"
    exit 1
  fi
  echo "$value"
}

DEFAULT_MARKETING_VERSION="$(project_setting_value MARKETING_VERSION)"
DEFAULT_CURRENT_PROJECT_VERSION="$(project_setting_value CURRENT_PROJECT_VERSION)"

XCODE_FLAGS=(
  MARKETING_VERSION="${MARKETING_VERSION:-$DEFAULT_MARKETING_VERSION}"
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-$DEFAULT_CURRENT_PROJECT_VERSION}"
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
  local start rc
  start=$(date +%s)
  rc=0

  if command -v xcpretty &>/dev/null; then
    # Disable pipefail temporarily: without it the pipeline exits with xcpretty's
    # status (typically 0), so set -e will not abort early, and PIPESTATUS[0]
    # still holds xcodebuild's real exit code.  Using `|| true` instead would
    # reset PIPESTATUS to (0) before we can read it — that was the false-green bug.
    set +o pipefail
    xcodebuild "$@" "${XCODE_FLAGS[@]}" | xcpretty
    rc=${PIPESTATUS[0]}
    set -o pipefail
  else
    xcodebuild "$@" "${XCODE_FLAGS[@]}" || rc=$?
  fi

  echo "  (took $(elapsed "$start"))"
  # Propagate xcodebuild's exit code; the echo above must not mask it.
  return "$rc"
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

extract_failed_test_identifiers() {
  local bundle_path="$1"
  local default_target="$2"

  if [[ ! -d "$bundle_path" ]]; then
    return
  fi

  python3 - "$bundle_path" "$default_target" <<'PY'
import json
import re
import subprocess
import sys

bundle_path = sys.argv[1]
default_target = sys.argv[2]

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

def to_only_testing_filter(test_case_name: str):
    # Expected xcresult style: -[Target.Class test_method]
    match = re.match(r"^-\[([^.]+)\.([^\s]+)\s([^\]]+)\]$", test_case_name)
    if match:
        target, class_name, method_name = match.groups()
        return f"{target}/{class_name}/{method_name}"

    # Alternate xcresult style: ClassName.testMethod
    dot_style = re.match(r"^([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)$", test_case_name)
    if dot_style and default_target:
        class_name, method_name = dot_style.groups()
        return f"{default_target}/{class_name}/{method_name}"

    # Fallback for already-normalized identifiers.
    if test_case_name.count("/") >= 2:
        return test_case_name
    return None

root = get_root(bundle_path)
if not root:
    sys.exit(0)

failures = (
    root.get("actions", {})
    .get("_values", [{}])[0]
    .get("actionResult", {})
    .get("issues", {})
    .get("testFailureSummaries", {})
    .get("_values", [])
)

seen = set()
for item in failures:
    test_case_name = item.get("testCaseName", {}).get("_value", "")
    identifier = to_only_testing_filter(test_case_name)
    if not identifier or identifier in seen:
        continue
    seen.add(identifier)
    print(identifier)
PY
}

xcresult_attempt_passed() {
  local bundle_path="$1"
  local allow_historical_failures="${2:-false}"

  if [[ ! -d "$bundle_path" ]]; then
    warn "Result bundle not found at: $bundle_path"
    return 1
  fi

  python3 - "$bundle_path" "$allow_historical_failures" <<'PY'
import json
import subprocess
import sys

bundle_path = sys.argv[1]
allow_historical_failures = sys.argv[2] == "true"

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
    print("⚠ Unable to parse xcresult bundle for pass/fail validation")
    sys.exit(1)

action_result = (
    root.get("actions", {})
    .get("_values", [{}])[0]
    .get("actionResult", {})
)
status = action_result.get("status", {}).get("_value", "")
failures = (
    action_result.get("issues", {})
    .get("testFailureSummaries", {})
    .get("_values", [])
)

if failures and not allow_historical_failures:
    print(f"⚠ xcresult contains {len(failures)} testFailureSummaries despite successful command exit")
    sys.exit(1)

if not status:
    print("⚠ xcresult action status is missing — result bundle may be incomplete or corrupt")
    sys.exit(1)

if status not in {"succeeded", "success"}:
    print(f"⚠ xcresult action status is '{status}' (expected succeeded)")
    sys.exit(1)

if failures:
    print(
        f"⚠ xcresult contains {len(failures)} historical testFailureSummaries "
        "from retried UI tests; final action status succeeded"
    )

sys.exit(0)
PY
}

report_xcresult_retry_failures() {
  local bundle_path="$1"
  local report_path="$2"

  if [[ ! -d "$bundle_path" ]]; then
    warn "Result bundle not found at: $bundle_path"
    return
  fi

  python3 - "$bundle_path" "$report_path" <<'PY'
import json
import os
import subprocess
import sys

bundle_path = sys.argv[1]
report_path = sys.argv[2]

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

def annotation_escape(value: str) -> str:
    return (
        value.replace("%", "%25")
        .replace("\r", "%0D")
        .replace("\n", "%0A")
        .replace(":", "%3A")
        .replace(",", "%2C")
    )

root = get_root(bundle_path)
if not root:
    print("⚠ Unable to parse xcresult bundle for retry-failure reporting")
    sys.exit(0)

action_result = (
    root.get("actions", {})
    .get("_values", [{}])[0]
    .get("actionResult", {})
)
failures = (
    action_result.get("issues", {})
    .get("testFailureSummaries", {})
    .get("_values", [])
)

lines = ["# UI retry failure report", ""]
if not failures:
    lines.append("No first-attempt UI test failures were recorded before retry success.")
    print("✓ No retried UI test failures recorded")
else:
    lines.append(
        f"{len(failures)} first-attempt UI test failure(s) were recorded before the final retry pass."
    )
    lines.append("")
    print(
        f"⚠ UI retry report: {len(failures)} first-attempt failure(s) "
        "were hidden by retry success"
    )
    for item in failures:
        test_name = item.get("testCaseName", {}).get("_value", "<unknown test>")
        message = item.get("message", {}).get("_value", "").splitlines()[0]
        document = item.get("documentLocationInCreatingWorkspace", {}).get("url", {}).get("_value", "")
        lines.append(f"- `{test_name}`: {message or '<no message>'}")
        annotation = f"{test_name}: {message or 'first-attempt failure before retry success'}"
        if os.environ.get("GITHUB_ACTIONS") == "true":
            print(
                "::warning title=Retried UI test failure::"
                + annotation_escape(annotation)
            )
        elif document:
            print(f"  - {test_name}: {message} ({document})")
        else:
            print(f"  - {test_name}: {message}")

os.makedirs(os.path.dirname(report_path) or ".", exist_ok=True)
with open(report_path, "w", encoding="utf-8") as report:
    report.write("\n".join(lines) + "\n")

summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write("\n".join(lines) + "\n\n")
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

  # Secondary guard (#455): even when xcodebuild exits 0 the result bundle can
  # be missing or corrupt (e.g. IDETesting mkstemp failure).  Treat either case
  # as a test failure so CI never reports success with a broken xcresult.
  local result_bundle="${PACKAGE_PATH}/TestResults.xcresult"
  if [[ ! -d "$result_bundle" ]]; then
    fail "TestResults.xcresult not found — result bundle was not written (see #455)"
    exit 1
  fi
  if ! xcrun xcresulttool get object --path "$result_bundle" --format json \
       &>/dev/null 2>&1 && \
     ! xcrun xcresulttool get object --legacy --path "$result_bundle" \
       --format json &>/dev/null 2>&1; then
    fail "TestResults.xcresult cannot be parsed — result bundle may be corrupt (see #455)"
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
  local -a only_testing_filters=()
  local -a only_testing_args=()
  local only_testing_count=0
  local xctestrun_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only-testing)
        if [[ $# -lt 2 ]]; then
          fail "--only-testing requires a value (e.g. EyePostureReminderUITests/HomeScreenTests)"
          exit 1
        fi
        only_testing_filters+=("$2")
        only_testing_args+=(-only-testing "$2")
        only_testing_count=$((only_testing_count + 1))
        shift 2
        ;;
      --only-testing=*)
        only_testing_filters+=("${1#*=}")
        only_testing_args+=(-only-testing "${1#*=}")
        only_testing_count=$((only_testing_count + 1))
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
      --xctestrun-path)
        if [[ $# -lt 2 ]]; then
          fail "--xctestrun-path requires a file path"
          exit 1
        fi
        xctestrun_path="$2"
        shift 2
        ;;
      --xctestrun-path=*)
        xctestrun_path="${1#*=}"
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
  if [[ -n "$xctestrun_path" && "$xctestrun_path" != /* ]]; then
    xctestrun_path="${PACKAGE_PATH}/${xctestrun_path}"
  fi

  local project="${PACKAGE_PATH}/UITests/EyePostureReminderUITests.xcodeproj"
  local project_spec="${PACKAGE_PATH}/UITests/project.yml"
  local project_file="${project}/project.pbxproj"

  # Generate xcodeproj only when we need to run build-for-testing locally.
  if [[ -z "$xctestrun_path" ]]; then
    if [[ ! -d "$project" || ! -f "$project_file" || "$project_spec" -nt "$project_file" ]]; then
      info "UITest xcodeproj missing or stale — running setup…"
      "${PACKAGE_PATH}/scripts/setup-uitests.sh"
    fi
  fi

  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "UI Test scheme: $UI_TEST_SCHEME"
  info "Result bundle: $result_bundle_path"
  if (( only_testing_count > 0 )); then
    info "Running filtered UI tests:"
    for only_testing_filter in "${only_testing_filters[@]}"; do
      info "  - $only_testing_filter"
    done
  fi

  rm -rf "$result_bundle_path"

  local xctestrun
  if [[ -n "$xctestrun_path" ]]; then
    xctestrun="$xctestrun_path"
    info "Using prebuilt xctestrun: $xctestrun"
  else
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
    xctestrun=$(find "${DERIVED_DATA_PATH}/Build/Products" \
      -name "${UI_TEST_SCHEME}_*.xctestrun" \
      -maxdepth 1 \
      -print \
      | sort | tail -1)
  fi

  if [[ -z "$xctestrun" || ! -f "$xctestrun" ]]; then
    fail "No valid .xctestrun found at: ${xctestrun:-<empty>}"
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
  local products_root
  products_root="$(cd "$(dirname "$xctestrun")" && pwd)"
  local products_dir="${products_root}/Debug-iphonesimulator"
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

  # Keep optional retries inside a single xcodebuild invocation so the simulator
  # session remains warm. The default is one deterministic pass; set
  # UITEST_XCODEBUILD_TEST_ITERATIONS > 1 to opt into XCTest-level retry.
  local test_iterations="${UITEST_XCODEBUILD_TEST_ITERATIONS:-1}"
  local max_test_execution_time="${UITEST_XCODEBUILD_MAX_TEST_SECONDS:-180}"
  if ! [[ "$test_iterations" =~ ^[1-9][0-9]*$ ]]; then
    fail "UITEST_XCODEBUILD_TEST_ITERATIONS must be a positive integer (got: $test_iterations)"
    exit 1
  fi
  if ! [[ "$max_test_execution_time" =~ ^[1-9][0-9]*$ ]]; then
    fail "UITEST_XCODEBUILD_MAX_TEST_SECONDS must be a positive integer (got: $max_test_execution_time)"
    exit 1
  fi
  rm -rf "$result_bundle_path"
  local retry_report_path="${result_bundle_path%.xcresult}-retry-failures.md"
  rm -f "$retry_report_path"
  local -a xcodebuild_test_args=(
    test-without-building \
    -xctestrun "$xctestrun" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$result_bundle_path" \
    -disable-concurrent-destination-testing \
    -parallel-testing-enabled NO \
    -maximum-test-execution-time-allowance "$max_test_execution_time"
  )
  if (( test_iterations > 1 )); then
    xcodebuild_test_args+=(
      -test-iterations "$test_iterations"
      -retry-tests-on-failure
      -test-repetition-relaunch-enabled YES
    )
  fi
  xcodebuild_test_args+=("${only_testing_args[@]}")

  if ! run_xcodebuild "${xcodebuild_test_args[@]}"; then
    fail "UI tests failed"
    summarize_xcresult_failures "$result_bundle_path"
    exit 1
  fi

  local allow_historical_failures="false"
  if (( test_iterations > 1 )); then
    allow_historical_failures="true"
  fi

  if ! xcresult_attempt_passed "$result_bundle_path" "$allow_historical_failures"; then
    fail "UI tests failed"
    summarize_xcresult_failures "$result_bundle_path"
    exit 1
  fi

  if (( test_iterations > 1 )); then
    report_xcresult_retry_failures "$result_bundle_path" "$retry_report_path"
  fi

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
# Marketing version lives in project.yml (MARKETING_VERSION).
# Build number (CFBundleVersion) defaults to project.yml and is overridden by CI via CURRENT_PROJECT_VERSION.
# To bump manually: ./scripts/build.sh version <new-version>
PLIST="${PACKAGE_PATH}/EyePostureReminder/Info.plist"

cmd_version() {
  local new_version="${1:-}"

  if [[ -z "$new_version" ]]; then
    if [[ ! -f "$PROJECT_SPEC_PATH" ]]; then
      fail "project.yml not found at: $PROJECT_SPEC_PATH"
      exit 1
    fi
    local current
    current="$(project_setting_value MARKETING_VERSION)"
    local build
    build="$(project_setting_value CURRENT_PROJECT_VERSION)"
    echo -e "${BOLD}Marketing version:${RESET} ${current}"
    echo -e "${BOLD}Build number:${RESET}     ${build} (overridden by CI with github.run_number)"
  else
    # Validate semver format (digits only — Apple requires numeric segments)
    if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      fail "Version must be numeric semver, e.g. 0.2.0 (no pre-release labels)"
      exit 1
    fi
    if [[ ! -f "$PROJECT_SPEC_PATH" ]]; then
      fail "project.yml not found at: $PROJECT_SPEC_PATH"
      exit 1
    fi
    local update_count
    update_count="$(python3 - "$PROJECT_SPEC_PATH" "$new_version" <<'PY'
import re
import sys

path, version = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    contents = handle.read()

updated, count = re.subn(
    r'(^\s*MARKETING_VERSION:\s*)"[0-9]+\.[0-9]+\.[0-9]+"',
    rf'\1"{version}"',
    contents,
    flags=re.MULTILINE,
)

if count == 0:
    print("0")
    sys.exit(1)

with open(path, "w", encoding="utf-8") as handle:
    handle.write(updated)

print(count)
PY
)"
    pass "Marketing version set to ${new_version} in project.yml (${update_count} target settings)"
    info "Remember to commit project.yml and tag: git tag -a v${new_version} -m 'Release ${new_version}'"
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
  echo "                       --xctestrun-path <path>"
  echo "  lint               Run SwiftLint (skipped gracefully if not installed)"
  echo "  clean              Remove build artifacts"
  echo "  all                build + lint + test"
  echo "  check              Alias for build (xcodebuild has no syntax-only mode)"
  echo "  version            Show current marketing version"
  echo "  version <x.y.z>   Set marketing version in project.yml"
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
