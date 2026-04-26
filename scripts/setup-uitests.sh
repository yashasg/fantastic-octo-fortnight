#!/usr/bin/env bash
# scripts/setup-uitests.sh — Generate UITest xcodeproj from UITests/project.yml
#
# Usage:
#   ./scripts/setup-uitests.sh
#
# Installs xcodegen (via Homebrew, if not already present) and generates:
#   UITests/EyePostureReminderUITests.xcodeproj
#   UITests/EyePostureReminderUITests.xcworkspace
#
# The .xcworkspace includes both the UITest target and the local Package.swift,
# so xcodebuild can build the EyePostureReminder app when running UI tests.
#
# Run once before:
#   ./scripts/build.sh uitest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_YML="$REPO_ROOT/UITests/project.yml"
OUTPUT_DIR="$REPO_ROOT/UITests"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { echo -e "${GREEN}✓ $*${RESET}"; }
fail()  { echo -e "${RED}✗ $*${RESET}" >&2; }
info()  { echo -e "${CYAN}▶ $*${RESET}"; }
header(){ echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }

header "SETUP UI TESTS"

# ── Validate project.yml exists ───────────────────────────────────────────────
if [[ ! -f "$PROJECT_YML" ]]; then
  fail "project.yml not found at: $PROJECT_YML"
  exit 1
fi

# ── Ensure xcodegen is available ──────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
  info "xcodegen not found — installing via Homebrew…"
  brew install xcodegen
  pass "xcodegen installed: $(xcodegen version 2>/dev/null || echo 'unknown')"
else
  info "xcodegen: $(xcodegen version 2>/dev/null || echo 'version unknown')"
fi

# ── Generate xcodeproj + xcworkspace ──────────────────────────────────────────
info "Generating from UITests/project.yml → UITests/EyePostureReminderUITests.xcodeproj…"

xcodegen generate \
  --spec "$PROJECT_YML" \
  --project "$OUTPUT_DIR"

pass "Generated UITests/EyePostureReminderUITests.xcodeproj"
pass "Generated UITests/EyePostureReminderUITests.xcworkspace"
info "Run UI tests with:  ./scripts/build.sh uitest"
