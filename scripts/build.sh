#!/usr/bin/env bash
# scripts/build.sh — Standardized build/test/lint runner for Eye & Posture Reminder
#
# Usage:
#   ./scripts/build.sh build    # Compile the project
#   ./scripts/build.sh test     # Run unit tests
#   ./scripts/build.sh lint     # Run SwiftLint (if available)
#   ./scripts/build.sh clean    # Clean build artifacts
#   ./scripts/build.sh all      # build + lint + test
#   ./scripts/build.sh check    # Quick syntax check (compile only, no tests)

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
PACKAGE_PATH="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${PACKAGE_PATH}/DerivedData"

XCODE_FLAGS=(
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  ENABLE_BITCODE=NO
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
# Returns an xcodebuild -destination string, preferring iOS Simulator when
# a runtime is present, falling back to Mac Catalyst.
detect_destination() {
  local sim_dest="platform=iOS Simulator,name=iPhone 16,OS=latest"
  local catalyst_dest="platform=macOS,variant=Mac Catalyst"

  # Check whether any iOS Simulator runtime is installed
  if xcrun simctl list runtimes 2>/dev/null | grep -q "iOS"; then
    echo "$sim_dest"
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
  header "CHECK (syntax)"
  require_xcodebuild
  local dest
  dest=$(detect_destination)
  info "Destination: $dest"

  run_xcodebuild build \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH"

  pass "Syntax check passed"
}

cmd_test() {
  header "TEST"
  require_xcodebuild
  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "Test scheme: $SCHEME (includes $TEST_SCHEME)"

  run_xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "${PACKAGE_PATH}/TestResults.xcresult"

  pass "Tests passed"
}

cmd_lint() {
  header "LINT"
  local start
  start=$(date +%s)

  if command -v swiftlint &>/dev/null; then
    info "Running SwiftLint…"
    swiftlint lint --path "$PACKAGE_PATH"
    pass "Lint passed (took $(elapsed "$start"))"
  else
    warn "swiftlint not found — skipping lint"
    warn "Install with:  brew install swiftlint"
    return 0
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

cmd_all() {
  header "ALL (build → lint → test)"
  local overall_start
  overall_start=$(date +%s)

  cmd_build
  cmd_lint
  cmd_test

  pass "All steps passed in $(elapsed "$overall_start")"
}

usage() {
  echo -e "${BOLD}Usage:${RESET} $(basename "$0") <command>"
  echo ""
  echo "Commands:"
  echo "  build   Compile the project"
  echo "  test    Run unit tests"
  echo "  lint    Run SwiftLint (skipped gracefully if not installed)"
  echo "  clean   Remove build artifacts"
  echo "  all     build + lint + test"
  echo "  check   Quick syntax check (compile only)"
}

# ── Entry point ───────────────────────────────────────────────────────────────
COMMAND="${1:-}"

case "$COMMAND" in
  build) cmd_build ;;
  test)  cmd_test  ;;
  lint)  cmd_lint  ;;
  clean) cmd_clean ;;
  all)   cmd_all   ;;
  check) cmd_check ;;
  *)
    fail "Unknown command: '${COMMAND}'"
    echo ""
    usage
    exit 1
    ;;
esac
