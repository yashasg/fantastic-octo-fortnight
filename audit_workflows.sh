#!/bin/bash

WORKFLOWS_DIR=".github/workflows"
ISSUES=()

echo "=== CI/CD WORKFLOW AUDIT ==="
echo ""

# Check each workflow
for workflow in $(ls $WORKFLOWS_DIR/*.{yml,yaml} 2>/dev/null | sort); do
    wf_name=$(basename "$workflow")
    echo "📋 Auditing: $wf_name"
    
    # 1. Check for required top-level fields
    if ! grep -q "^name:" "$workflow"; then
        ISSUES+=("$wf_name: Missing 'name' field")
    fi
    if ! grep -q "^on:" "$workflow"; then
        ISSUES+=("$wf_name: Missing 'on' (trigger) field")
    fi
    if ! grep -q "^jobs:" "$workflow"; then
        ISSUES+=("$wf_name: Missing 'jobs' field")
    fi
    
    # 2. Check for hardcoded secrets/credentials
    if grep -iE "password|secret|token|api.key|bearer" "$workflow" | grep -v "secrets\." | grep -v "GITHUB_TOKEN" | grep -qv "env:"; then
        ISSUES+=("$wf_name: Potential hardcoded credentials detected")
    fi
    
    # 3. Check for outdated action versions (v3 or older, should be v4+)
    if grep -E "uses:.*@v[0-3]" "$workflow" | grep -v "actions/checkout@v4" | grep -v "actions/cache@v4" | grep -v "actions/upload-artifact@v4"; then
        ISSUES+=("$wf_name: Potentially outdated action versions detected")
        echo "  Found: $(grep -E 'uses:.*@v[0-3]' "$workflow" || true)"
    fi
    
    # 4. Check for TODOs, FIXMEs, or placeholders
    if grep -iE "TODO|FIXME|XXX|PLACEHOLDER|stub|fix.this|replace.me" "$workflow"; then
        ISSUES+=("$wf_name: TODO/FIXME/placeholder comment found")
    fi
    
    # 5. Check for non-existent script references
    grep -oE "\./(scripts/[a-zA-Z0-9._-]+)" "$workflow" | while read script; do
        if [ ! -f "$script" ]; then
            ISSUES+=("$wf_name: Referenced script not found: $script")
        fi
    done
    
    echo "  ✓ Basic validation passed"
    echo ""
done

echo "=== SUMMARY ==="
if [ ${#ISSUES[@]} -eq 0 ]; then
    echo "✓ No issues found — all workflows CONVERGED"
else
    echo "❌ Found ${#ISSUES[@]} issue(s):"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
fi
