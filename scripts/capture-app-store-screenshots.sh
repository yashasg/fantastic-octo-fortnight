#!/usr/bin/env bash
# Capture App Store screenshot PNGs from deterministic XCUITest states.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/docs/app-store-screenshots}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"
DEFAULT_DEVICES=("iPhone 17 Pro" "iPhone 17 Pro Max")
DEVICES=()

# Filenames captured by Tests/EyePostureReminderUITests/AppStoreScreenshotTests.
EXPECTED_SCREENSHOTS=(
  "01-settings.png"
  "02-eye-break-overlay.png"
  "03-posture-check-overlay.png"
  "04-onboarding-welcome.png"
  "05-snooze-options.png"
)

# Pixel dimensions documented in docs/APP_STORE_LISTING.md §7 ("WIDTHxHEIGHT").
expected_dimensions_for_device() {
  case "$1" in
    "iPhone 17 Pro") echo "1206x2622" ;;
    "iPhone 17 Pro Max") echo "1320x2868" ;;
    *) echo "" ;;
  esac
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--output-dir DIR] [--device "iPhone 17 Pro"]...

Captures the five App Store screenshot states documented in docs/APP_STORE_LISTING.md.
If no --device is provided, captures on: ${DEFAULT_DEVICES[*]}.

After capture, validates that each device output directory contains all
expected screenshot PNGs. For default devices, also validates pixel
dimensions match the App Store-required sizes for each device family.
Custom --device entries are validated for filename presence only, since
non-default devices may use different dimensions.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --device)
      DEVICES+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ${#DEVICES[@]} -eq 0 ]]; then
  DEVICES=("${DEFAULT_DEVICES[@]}")
fi

cd "$ROOT_DIR"
./scripts/setup-uitests.sh
mkdir -p "$OUTPUT_DIR"

for device in "${DEVICES[@]}"; do
  device_dir="$OUTPUT_DIR/${device// /-}"
  mkdir -p "$device_dir"
  echo "Capturing App Store screenshots on $device -> $device_dir"

  SIMULATOR="platform=iOS Simulator,name=$device" \
    DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
    APP_STORE_SCREENSHOT_DIR="$device_dir" \
    ./scripts/build.sh uitest \
      --only-testing EyePostureReminderUITests/AppStoreScreenshotTests/test_captureAppStoreScreenshotSet
done

# ── Post-capture validation ──────────────────────────────────────────────────
# Confirms each device directory contains the required PNGs (and matches the
# documented App Store dimensions for default devices). Failure here indicates
# the test missed a state, the capture step crashed silently, or a simulator
# was misconfigured — all of which would otherwise produce a silently
# incomplete screenshot package handed to the release operator.

png_dimensions() {
  # Returns "WIDTHxHEIGHT" for a PNG using built-in `sips`.
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null \
    | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}'
}

validate_device_dir() {
  local device="$1"
  local device_dir="$2"
  local expected_dims="$3"
  local errors=0

  for name in "${EXPECTED_SCREENSHOTS[@]}"; do
    local path="$device_dir/$name"
    if [[ ! -f "$path" ]]; then
      echo "✗ $device: missing $name (expected at $path)" >&2
      errors=$((errors + 1))
      continue
    fi

    if [[ -n "$expected_dims" ]]; then
      local actual
      actual="$(png_dimensions "$path")"
      if [[ "$actual" != "$expected_dims" ]]; then
        echo "✗ $device: $name has dimensions $actual, expected $expected_dims" >&2
        errors=$((errors + 1))
      fi
    fi
  done

  if [[ $errors -gt 0 ]]; then
    return 1
  fi

  if [[ -n "$expected_dims" ]]; then
    echo "✓ $device: ${#EXPECTED_SCREENSHOTS[@]} PNGs present at $expected_dims"
  else
    echo "✓ $device: ${#EXPECTED_SCREENSHOTS[@]} PNGs present (dimension check skipped — non-default device)"
  fi
}

validation_failed=0
for device in "${DEVICES[@]}"; do
  device_dir="$OUTPUT_DIR/${device// /-}"
  expected_dims="$(expected_dimensions_for_device "$device")"
  if ! validate_device_dir "$device" "$device_dir" "$expected_dims"; then
    validation_failed=1
  fi
done

find "$OUTPUT_DIR" -type f -name '*.png' -maxdepth 2 | sort

if [[ $validation_failed -ne 0 ]]; then
  echo "App Store screenshot validation failed. See errors above." >&2
  exit 1
fi
