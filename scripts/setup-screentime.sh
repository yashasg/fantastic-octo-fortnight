#!/usr/bin/env bash
# scripts/setup-screentime.sh — Generate Screen Time extension xcodeproj from project.yml
#
# Usage:
#   ./scripts/setup-screentime.sh           # generate only
#   ./scripts/setup-screentime.sh --build   # generate + xcodebuild (no signing)
#
# Generates:
#   EyePostureReminderExtensions.xcodeproj  (gitignored — source of truth is project.yml)
#
# Requirements:
#   • xcodegen (brew install xcodegen)
#   • Xcode (for --build validation)
#
# Runtime Screen Time shielding requires FamilyControls entitlement (#201).
# Simulator builds compile and run without it; shield callbacks are no-ops.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_YML="$REPO_ROOT/project.yml"
OUTPUT_DIR="$REPO_ROOT/ScreenTimeExtensions"
XCODEPROJ="${OUTPUT_DIR}/EyePostureReminderExtensions.xcodeproj"
SCHEME="EyePostureReminderExtensions"
DERIVED_DATA="$REPO_ROOT/DerivedData"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass()   { echo -e "${GREEN}✓ $*${RESET}"; }
fail()   { echo -e "${RED}✗ $*${RESET}" >&2; }
info()   { echo -e "${CYAN}▶ $*${RESET}"; }
warn()   { echo -e "${YELLOW}⚠ $*${RESET}"; }
header() { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }

header "SETUP SCREEN TIME EXTENSIONS"

# ── Validate project.yml exists ───────────────────────────────────────────────
if [[ ! -f "$PROJECT_YML" ]]; then
  fail "project.yml not found at: $PROJECT_YML"
  exit 1
fi

# ── Ensure xcodegen is available ──────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
  info "xcodegen not found — installing via Homebrew…"
  if ! command -v brew &>/dev/null; then
    fail "Homebrew not found. Install xcodegen manually: https://github.com/yonaskolb/XcodeGen"
    exit 1
  fi
  brew install xcodegen
  pass "xcodegen installed: $(xcodegen version 2>/dev/null || echo 'unknown')"
else
  info "xcodegen: $(xcodegen version 2>/dev/null || echo 'version unknown')"
fi

# ── Generate xcodeproj ────────────────────────────────────────────────────────
info "Generating from project.yml → ScreenTimeExtensions/EyePostureReminderExtensions.xcodeproj…"

mkdir -p "$OUTPUT_DIR"

xcodegen generate \
  --spec "$PROJECT_YML" \
  --project "$OUTPUT_DIR"

pass "Generated: ScreenTimeExtensions/EyePostureReminderExtensions.xcodeproj"

# ── Optional: build for simulator (no code signing) ───────────────────────────
if [[ "${1:-}" == "--build" ]]; then
  header "VALIDATE BUILD (simulator, no signing)"

  if ! command -v xcodebuild &>/dev/null; then
    fail "xcodebuild not found. Install Xcode from the Mac App Store."
    exit 1
  fi

  mkdir -p "${REPO_ROOT}/.build/tmp"
  BUILD_LOG="$(mktemp "${REPO_ROOT}/.build/tmp/screentime-build.XXXXXX.log")"
  trap 'rm -f "$BUILD_LOG"' EXIT

  # Detect first available iPhone simulator
  DEST="platform=iOS Simulator,OS=latest"
  if xcrun simctl list runtimes 2>/dev/null | grep -q "iOS"; then
    SIM=$(xcrun simctl list devices available 2>/dev/null \
      | grep -oE 'iPhone [^(]+' | head -1 | sed 's/ *$//')
    [[ -n "$SIM" ]] && DEST="platform=iOS Simulator,name=${SIM}"
  fi
  info "Destination: $DEST"

  set +e
  xcodebuild build \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    ENABLE_BITCODE=NO \
    ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO \
    ENABLE_APPINTENTS_METADATA_EXTRACTION=NO \
    2>&1 | tee "$BUILD_LOG"
  build_status="${PIPESTATUS[0]}"
  set -e

  if grep -En '(^|[^[:alpha:]])warning:' "$BUILD_LOG"; then
    fail "Build validation emitted warnings"
    exit 1
  fi

  if [[ "$build_status" -ne 0 ]]; then
    fail "Build validation failed"
    exit "$build_status"
  fi

  pass "Build validation succeeded"
fi

echo ""
info "Next steps:"
info "  • Run unit tests:    ./scripts/build.sh test"
info "  • Build+validate:    ./scripts/setup-screentime.sh --build"
info "  • Signed archive:    APPLE_TEAM_ID=XXXXXXXXXX ./scripts/build_signed.sh archive"
info ""
info "Screen Time shielding is blocked on issue #201 (FamilyControls entitlement)."
info "See docs/SPIKE_SCREEN_TIME_APIS.md for full context."
