#!/bin/bash

echo "=== DETAILED MANUAL AUDIT ==="
echo ""

# Check ci.yml for references to non-existent Info.plist
echo "1. Checking ci.yml for Info.plist path..."
if grep -q "EyePostureReminder/Info.plist" .github/workflows/ci.yml; then
    if [ -f "EyePostureReminder/Info.plist" ]; then
        echo "   ✓ Info.plist exists at correct path"
    else
        echo "   ✗ WARNING: Info.plist reference but file location may be wrong"
    fi
fi

echo ""
echo "2. Checking TestFlight workflow for missing secrets..."
REQUIRED_SECRETS=(
    "BUILD_CERTIFICATE_BASE64"
    "P12_PASSWORD"
    "BUILD_PROVISION_PROFILE_BASE64"
    "KEYCHAIN_PASSWORD"
    "ASC_API_KEY_BASE64"
    "ASC_KEY_ID"
    "ASC_ISSUER_ID"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
    if grep -q "secrets\.$secret" .github/workflows/testflight.yml; then
        echo "   ✓ $secret referenced properly"
    else
        echo "   ✗ MISSING secret reference: $secret"
    fi
done

echo ""
echo "3. Checking Squad workflows for script references..."
for script in ralph-triage.js; do
    if grep -q "$script" .github/workflows/squad-heartbeat.yml; then
        echo "   ⚠ Script reference: $script (runtime check only, file path)"
    fi
done

echo ""
echo "4. Checking action versions..."
grep -r "uses:" .github/workflows/ | grep -oE "actions/[^@]+@v[0-9]+" | sort -u

echo ""
echo "5. Checking for unhandled errors in scripts..."
if grep -q "set -e" scripts/build.sh; then
    echo "   ✓ build.sh has proper error handling (set -e)"
fi

echo ""
echo "6. Checking for deprecated xcodebuild options..."
if grep -q "ENABLE_BITCODE=NO" .github/workflows/testflight.yml; then
    echo "   ✓ ENABLE_BITCODE correctly set to NO (bitcode deprecated)"
fi

echo ""
echo "7. Checking for proper permissions..."
grep "^permissions:" .github/workflows/*.yml | head -6

echo ""
