#!/usr/bin/env bash
#
# set-build-info.sh — Xcode Run Script Build Phase
#
# Sets CFBundleVersion and injects the current commit hash as EPRCommitHash
# into the app's Info.plist at build time.
#
# Usage (Xcode Run Script Build Phase):
#   "${SRCROOT}/../scripts/set-build-info.sh"
#
# Environment variables (set by Xcode automatically):
#   INFOPLIST_FILE         — relative path to Info.plist (from SRCROOT)
#   SRCROOT                — project source root
#   BUILT_PRODUCTS_DIR     — where the built .app lives
#   PRODUCT_NAME           — target name
#
# Override build number by setting BUILD_NUMBER in the environment
# (e.g. from GitHub Actions: BUILD_NUMBER=${{ github.run_number }})
#
# If BUILD_NUMBER is not set, falls back to a timestamp: YYYYMMDDHHmm

set -euo pipefail

# ── Resolve Info.plist path ───────────────────────────────────────────────────
# During Xcode builds, INFOPLIST_FILE is relative to SRCROOT.
# During CI (called standalone), we look for it adjacent to this script.
if [[ -n "${INFOPLIST_FILE:-}" && -n "${SRCROOT:-}" ]]; then
  PLIST_PATH="${SRCROOT}/${INFOPLIST_FILE}"
elif [[ -n "${BUILT_PRODUCTS_DIR:-}" && -n "${PRODUCT_NAME:-}" ]]; then
  PLIST_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Info.plist"
else
  # Fallback: resolve relative to script location
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PLIST_PATH="${SCRIPT_DIR}/../EyePostureReminder/Info.plist"
fi

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "error: set-build-info.sh — Info.plist not found at: $PLIST_PATH"
  exit 1
fi

# ── Build number ─────────────────────────────────────────────────────────────
# Use BUILD_NUMBER from env (set by CI), otherwise fall back to timestamp.
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  BUNDLE_VERSION="$BUILD_NUMBER"
else
  BUNDLE_VERSION="$(date +%Y%m%d%H%M)"
  echo "note: BUILD_NUMBER not set — using timestamp: $BUNDLE_VERSION"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$PLIST_PATH"
echo "Set CFBundleVersion = $BUNDLE_VERSION"

# ── Commit hash ───────────────────────────────────────────────────────────────
# Inject the current short commit SHA as EPRCommitHash.
# This key is separate from the Apple-required version fields.
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
  COMMIT_HASH="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
else
  COMMIT_HASH="${GIT_COMMIT_HASH:-unknown}"
fi

# Add the key if it doesn't exist, otherwise update it.
/usr/libexec/PlistBuddy -c "Add :EPRCommitHash string $COMMIT_HASH" "$PLIST_PATH" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :EPRCommitHash $COMMIT_HASH" "$PLIST_PATH"
echo "Set EPRCommitHash = $COMMIT_HASH"

echo "Build info applied to: $PLIST_PATH"
