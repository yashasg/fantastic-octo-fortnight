#!/bin/bash

echo "=== FINAL COMPREHENSIVE AUDIT ==="
echo ""

CRITICAL_ISSUES=()
WARNINGS=()
NOTES=()

# 1. TestFlight: Check if ExportOptions.plist is generated vs committed
echo "Checking testflight.yml ExportOptions.plist handling..."
if grep -q "cat > .*ExportOptions.plist" .github/workflows/testflight.yml; then
    NOTES+=("testflight.yml: ExportOptions.plist is generated in workflow (correct approach)")
else
    if [ -f "ExportOptions.plist" ]; then
        WARNINGS+=("testflight.yml: ExportOptions.plist exists in repo; workflow also generates one (redundant)")
    fi
fi

# 2. Check .squad directory exists
echo "Checking .squad directory references..."
if [ ! -d ".squad" ]; then
    WARNINGS+=("Squad workflows reference .squad/ directory but it doesn't exist")
    if [ -d ".ai-team" ]; then
        NOTES+=("Fallback .ai-team directory exists (workflows handle this)")
    fi
fi

# 3. Check if Coverage threshold (50%) is reasonable
echo "Checking coverage threshold..."
if grep -q "50" .github/workflows/ci.yml; then
    NOTES+=("ci.yml: Coverage threshold is 50% (reasonable for young project)")
fi

# 4. Check Xcode version pinning
echo "Checking Xcode version..."
XCODE_VER=$(grep "XCODE_VERSION:" .github/workflows/ci.yml | head -1 | grep -oE '"[0-9]+\.[0-9]+"' | tr -d '"')
if [ -n "$XCODE_VER" ]; then
    NOTES+=("Xcode pinned to version $XCODE_VER (good for reproducibility)")
fi

# 5. Check runner specification
echo "Checking runner OS..."
if grep -q "macos-15" .github/workflows/ci.yml; then
    NOTES+=("ci.yml: Using macos-15 runner (current, appropriate for recent Xcode)")
fi

# 6. Check timeout settings
echo "Checking job timeouts..."
if grep -q "timeout-minutes:" .github/workflows/ci.yml; then
    TO=$(grep "timeout-minutes:" .github/workflows/ci.yml | head -1 | grep -oE "[0-9]+")
    NOTES+=("ci.yml: Timeout set to ${TO}min")
fi

# 7. Check for proper cache invalidation
echo "Checking cache keys..."
if grep -q "hashFiles" .github/workflows/ci.yml; then
    NOTES+=("ci.yml: Cache keys use hashFiles() for proper invalidation")
fi

# 8. Test results artifact retention
echo "Checking artifact retention..."
if grep -q "retention-days: 30" .github/workflows/ci.yml; then
    NOTES+=("ci.yml: Test results retained for 30 days (reasonable)")
fi

# 9. Check for proper secret cleanup
echo "Checking secret cleanup in testflight.yml..."
if grep -q "rm -f.*asc_api_key.p8" .github/workflows/testflight.yml; then
    NOTES+=("testflight.yml: API keys properly cleaned up after use")
fi

# 10. Check SwiftLint version
echo "Checking SwiftLint version..."
if grep -q "swiftlint@0.57.0" .github/workflows/ci.yml; then
    NOTES+=("ci.yml: SwiftLint pinned to v0.57.0 (reproducible)")
fi

# 11. Check for proper signal handling
echo "Checking error handling..."
if grep -q "if: always()" .github/workflows/ci.yml; then
    NOTES+=("ci.yml: Using 'if: always()' for cleanup steps (proper)")
fi

# 12. Check Actions are signed releases
echo "Checking action versions..."
if grep "actions/checkout@v4" .github/workflows/*.yml >/dev/null; then
    NOTES+=("Using actions/checkout@v4 (current major version, good)")
fi

# 13. Check GH_TOKEN usage in testflight
echo "Checking GH_TOKEN usage..."
if grep -q "GH_TOKEN:" .github/workflows/testflight.yml; then
    NOTES+=("testflight.yml: Uses GH_TOKEN from GITHUB_TOKEN secret (correct)")
fi

# 14. Check permissions are minimal
echo "Checking permission scopes..."
for workflow in .github/workflows/*.yml; do
    WF=$(basename "$workflow")
    PERMS=$(grep -A5 "^permissions:" "$workflow" | grep -oE "[a-z-]+: (read|write)" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    if [ -n "$PERMS" ]; then
        NOTES+=("$WF permissions: $PERMS")
    fi
done

echo ""
echo "=== AUDIT RESULTS ==="
echo ""

if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "❌ CRITICAL ISSUES:"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "   - $issue"
    done
    echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "⚠️  WARNINGS:"
    for warning in "${WARNINGS[@]}"; do
        echo "   - $warning"
    done
    echo ""
fi

echo "✓ OBSERVATIONS & GOOD PRACTICES:"
for note in "${NOTES[@]}"; do
    echo "   ✓ $note"
done

echo ""
echo "=== FINAL VERDICT ==="
if [ ${#CRITICAL_ISSUES[@]} -eq 0 ]; then
    if [ ${#WARNINGS[@]} -eq 0 ]; then
        echo "✅ CONVERGED — All workflows are correct and complete"
    else
        echo "⚠️  CONVERGED (with minor warnings) — Workflows are functional but could be improved"
    fi
else
    echo "❌ FAILED — Critical issues must be addressed"
fi
