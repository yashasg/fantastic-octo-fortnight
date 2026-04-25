#!/bin/bash

echo "=== SCRIPT VALIDATION ==="
echo ""

# Extract all script references from workflows
echo "[1] Scripts referenced in workflows:"
SCRIPTS=$(grep -r './scripts/' .github/workflows/ | grep -oE '\./scripts/[a-zA-Z0-9._-]+' | sort -u)

for script in $SCRIPTS; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "    ✓ $script (exists, executable)"
        else
            echo "    ⚠️  $script (exists, NOT executable)"
        fi
    else
        echo "    ✗ $script (MISSING)"
    fi
done

echo ""
echo "[2] Available scripts in scripts/ directory:"
ls -la scripts/

echo ""
echo "[3] Checking script content for required functions:"
for workflow in .github/workflows/*.yml; do
    # Extract function calls like ./scripts/build.sh <command>
    COMMANDS=$(grep -oE '\./scripts/build\.sh [a-z]+' "$workflow" | awk '{print $NF}' | sort -u)
    if [ -n "$COMMANDS" ]; then
        WF=$(basename "$workflow")
        echo "    $WF uses build.sh commands: $(echo $COMMANDS | tr '\n' ', ')"
    fi
done

echo ""
echo "=== SCRIPT VALIDATION COMPLETE ==="
