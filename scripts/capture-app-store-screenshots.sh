#!/usr/bin/env bash
# Capture App Store screenshot PNGs from deterministic XCUITest states.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/docs/app-store-screenshots}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"
DEFAULT_DEVICES=("iPhone 17 Pro" "iPhone 17 Pro Max")
DEVICES=()

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--output-dir DIR] [--device "iPhone 17 Pro"]...

Captures the five App Store screenshot states documented in docs/APP_STORE_LISTING.md.
If no --device is provided, captures on: ${DEFAULT_DEVICES[*]}.
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

find "$OUTPUT_DIR" -type f -name '*.png' -maxdepth 2 | sort
