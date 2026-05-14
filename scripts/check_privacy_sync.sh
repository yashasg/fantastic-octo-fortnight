#!/usr/bin/env bash
# scripts/check_privacy_sync.sh
#
# Lightweight release check that verifies the hosted privacy page
# (docs/privacy.html) stays materially synchronized with the canonical
# privacy policy (docs/legal/PRIVACY.md).
#
# It does NOT diff prose. It only verifies that the canonical sections
# reviewers and App Review look for are present in BOTH files. If you
# rename or remove a canonical section, update REQUIRED_SECTIONS below
# so the check stays meaningful.
#
# Exit codes:
#   0 — all required sections present in both files
#   1 — one or more required sections missing
#   2 — bad invocation (missing files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CANONICAL="$REPO_ROOT/docs/legal/PRIVACY.md"
HOSTED="$REPO_ROOT/docs/privacy.html"

# Required canonical sections (case-insensitive substring match).
# Each entry is "<canonical-needle>|<hosted-needle>" so the two files
# can phrase the heading slightly differently as long as the same
# concept is disclosed in both.
REQUIRED_SECTIONS=(
  "What We Collect or Access|What we collect or access"
  "What We Do NOT Collect or Do|What we do NOT collect or do"
  "Local Storage|Local storage"
  "App Store Privacy Manifest|App Store Privacy Manifest"
  "Apple Diagnostics and Analytics|Apple diagnostics and analytics"
  "Local Logging|Local logging"
  "No Third-Party Data Sharing|No third-party data sharing"
  "Apple App Store|Apple App Store"
  "Children's Privacy|Children's privacy"
  "Data Security|Data security"
  "Your Rights|Your rights"
  "Changes to This Privacy Policy|Changes to this privacy policy"
  "Contact|Contact"
)

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
info()   { printf '\033[0;36m▶ %s\033[0m\n' "$*"; }

if [[ ! -f "$CANONICAL" ]]; then
  red "✗ Canonical privacy policy not found: $CANONICAL"
  exit 2
fi

if [[ ! -f "$HOSTED" ]]; then
  red "✗ Hosted privacy page not found: $HOSTED"
  exit 2
fi

info "Verifying $HOSTED is in sync with $CANONICAL"

failures=0

for entry in "${REQUIRED_SECTIONS[@]}"; do
  canonical_needle="${entry%%|*}"
  hosted_needle="${entry##*|}"

  if ! grep -qiF "$canonical_needle" "$CANONICAL"; then
    red "✗ Canonical PRIVACY.md is missing section: \"$canonical_needle\""
    failures=$((failures + 1))
    continue
  fi

  if ! grep -qiF "$hosted_needle" "$HOSTED"; then
    red "✗ Hosted privacy.html is missing section: \"$hosted_needle\""
    red "  (canonical has \"$canonical_needle\" — hosted page must mirror it)"
    failures=$((failures + 1))
  fi
done

if (( failures > 0 )); then
  red "✗ Privacy sync check failed: $failures missing section(s)."
  yellow "  Update docs/privacy.html to mirror docs/legal/PRIVACY.md, or update"
  yellow "  REQUIRED_SECTIONS in scripts/check_privacy_sync.sh if a canonical"
  yellow "  section was intentionally renamed or removed."
  exit 1
fi

green "✓ Privacy sync check passed (${#REQUIRED_SECTIONS[@]} required sections present in both files)"
