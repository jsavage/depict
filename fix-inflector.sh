#!/usr/bin/env bash
# Fix inflector case-sensitivity issue in server/Cargo.toml

set -euo pipefail

echo "=== Fixing Inflector Case Sensitivity ==="

# Fix in server/Cargo.toml
if [ -f "server/Cargo.toml" ]; then
    echo "Checking server/Cargo.toml..."
    
    # Show current inflector references
    echo "Current inflector references:"
    grep -i "inflector" server/Cargo.toml || echo "  (none found)"
    
    # Replace lowercase inflector with Inflector (capital I)
    if grep -q 'inflector[[:space:]]*=' server/Cargo.toml; then
        echo ""
        echo "Fixing: inflector -> Inflector"
        sed -i 's/inflector[[:space:]]*=/Inflector =/' server/Cargo.toml
        echo "✅ Fixed in server/Cargo.toml"
    elif grep -q 'Inflector[[:space:]]*=' server/Cargo.toml; then
        echo "✅ Already using correct case (Inflector)"
    else
        echo "⚠️  No inflector dependency found"
    fi
    
    echo ""
    echo "Updated inflector references:"
    grep -i "inflector" server/Cargo.toml || echo "  (none found)"
else
    echo "❌ server/Cargo.toml not found"
    exit 1
fi

# Check other Cargo.toml files for the same issue
echo ""
echo "Checking other Cargo.toml files..."
for toml in */Cargo.toml; do
    if [ "$toml" != "server/Cargo.toml" ] && grep -q 'inflector[[:space:]]*=' "$toml" 2>/dev/null; then
        echo "Found lowercase inflector in: $toml"
        sed -i 's/inflector[[:space:]]*=/Inflector =/' "$toml"
        echo "  ✅ Fixed"
    fi
done

echo ""
echo "================================================================"
echo "✅ Inflector case fix complete"
echo "================================================================"
echo ""
echo "Now run: cargo update"
echo "Then continue with builds"