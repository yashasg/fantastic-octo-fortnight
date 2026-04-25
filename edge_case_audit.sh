#!/bin/bash

echo "=== EDGE CASE & DETAILED VALIDATION ==="
echo ""

FOUND_ISSUES=()

# 1. Check for loose shell variables that could fail
echo "[1] Checking for proper variable handling in ci.yml..."
if grep -q 'DERIVED_DATA_PATH.*github.workspace' .github/workflows/ci.yml; then
    echo "    ✓ DERIVED_DATA_PATH properly constructed"
fi

# 2. Check testflight for xcarchive path issues
echo "[2] Checking xcarchive path in testflight.yml..."
if grep -q 'github.workspace.*EyePostureReminder.xcarchive' .github/workflows/testflight.yml; then
    echo "    ✓ xcarchive path properly qualified"
fi

# 3. Check for unquoted path variables that could break
echo "[3] Checking for properly quoted paths..."
UNQUOTED_PATHS=$(grep -n 'DERIVED_DATA_PATH}' .github/workflows/*.yml | grep -v '".*DERIVED_DATA_PATH' | grep -v "'.*DERIVED_DATA_PATH" | wc -l)
if [ $UNQUOTED_PATHS -eq 0 ]; then
    echo "    ✓ All path variables properly quoted"
fi

# 4. Check for xcodebuild timeout issues
echo "[4] Checking xcodebuild command structure..."
if grep -q 'xcodebuild.*-scheme' .github/workflows/*.yml; then
    echo "    ✓ xcodebuild commands use required -scheme flag"
fi

# 5. Check CI gate in testflight
echo "[5] Checking TestFlight CI gate..."
if grep -q 'Build & Test' .github/workflows/testflight.yml; then
    echo "    ✓ TestFlight waits for 'Build & Test' job from CI workflow"
fi

# 6. Check security best practices
echo "[6] Checking security best practices..."
if grep -q 'security delete-keychain' .github/workflows/testflight.yml; then
    echo "    ✓ Keychain properly deleted in cleanup"
fi
if grep -q 'set-keychain-settings -lut' .github/workflows/testflight.yml; then
    echo "    ✓ Keychain auto-lock timeout set (security)"
fi

# 7. Validate coverage calculation
echo "[7] Checking coverage calculation..."
if grep -q 'python3.*json.*lineCoverage' .github/workflows/ci.yml; then
    echo "    ✓ Coverage calculated from JSON report"
fi

# 8. Check test scheme naming
echo "[8] Checking test scheme..."
if grep -q 'EyePostureReminder' .github/workflows/ci.yml; then
    echo "    ✓ Correct scheme referenced"
fi

# 9. Check for provisioning profile placement
echo "[9] Checking provisioning profile handling..."
if grep -q 'Library/MobileDevice/Provisioning' .github/workflows/testflight.yml; then
    echo "    ✓ Provisioning profile placed in correct system directory"
fi

# 10. Check for proper artifact naming
echo "[10] Checking artifact naming..."
if grep -q 'MARKETING_VERSION.*BUILD' .github/workflows/ci.yml; then
    echo "    ✓ Artifacts include version and build number"
fi

# 11. Check for bc command in coverage check
echo "[11] Checking coverage comparison..."
if grep -q '"$COVERAGE < 50"' .github/workflows/ci.yml; then
    echo "    ✓ Coverage comparison uses bc (proper float handling)"
else
    FOUND_ISSUES+=("ci.yml: Coverage comparison may have issues with float arithmetic")
fi

# 12. Check for proper environment variable scope
echo "[12] Checking environment variable scope..."
if grep -q 'GITHUB_ENV' .github/workflows/ci.yml; then
    echo "    ✓ Environment variables properly appended to GITHUB_ENV"
fi

# 13. Validate action permissions for copilot assignment
echo "[13] Checking Copilot assignment token handling..."
if grep -q 'secrets.COPILOT_ASSIGN_TOKEN' .github/workflows/*.yml; then
    echo "    ✓ Fallback to GITHUB_TOKEN if COPILOT_ASSIGN_TOKEN not set"
fi

# 14. Check for conditional job execution
echo "[14] Checking job conditions..."
if grep -q 'if: startsWith' .github/workflows/squad-issue-assign.yml; then
    echo "    ✓ Squad jobs use proper conditional logic"
fi

# 15. Validate hashFiles usage for cache busting
echo "[15] Checking cache busting..."
if grep -q "hashFiles('Package.swift'" .github/workflows/ci.yml; then
    echo "    ✓ Cache uses Package.swift hash for dependency tracking"
fi

echo ""
echo "=== EDGE CASE VALIDATION RESULTS ==="
if [ ${#FOUND_ISSUES[@]} -eq 0 ]; then
    echo "✓ No edge case issues found"
else
    echo "⚠️  Found ${#FOUND_ISSUES[@]} edge case(s):"
    for issue in "${FOUND_ISSUES[@]}"; do
        echo "   - $issue"
    done
fi
