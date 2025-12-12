#!/usr/bin/env bash
# Fix dependency versions that are too new for nightly-2024-05-01

set -euo pipefail

echo "=== Fixing Dependencies for nightly-2024-05-01 ==="
echo ""

# Backup Cargo.lock
if [ -f "Cargo.lock" ]; then
    cp Cargo.lock Cargo.lock.backup
    echo "✓ Backed up Cargo.lock to Cargo.lock.backup"
fi

# Fix inflector case in server/Cargo.toml
echo ""
echo "1. Fixing Inflector case..."
if [ -f "server/Cargo.toml" ] && grep -q 'inflector[[:space:]]*=' server/Cargo.toml; then
    sed -i 's/inflector[[:space:]]*=/Inflector =/' server/Cargo.toml
    echo "✓ Fixed: inflector -> Inflector in server/Cargo.toml"
else
    echo "✓ Inflector already correct or not found"
fi

# Add version constraints to root Cargo.toml [dependencies] section
echo ""
echo "2. Pinning problematic dependencies..."

# Check if we need to add dependency overrides
if ! grep -q '\[patch.crates-io\]' Cargo.toml; then
    echo "" >> Cargo.toml
    echo "# Patches for nightly-2024-05-01 compatibility" >> Cargo.toml
    echo "[patch.crates-io]" >> Cargo.toml
    echo "✓ Added [patch.crates-io] section"
fi

# Pin globset to version that doesn't need edition2024
if ! grep -q 'globset.*=' Cargo.toml; then
    # Find the [patch.crates-io] section and add after it
    sed -i '/\[patch.crates-io\]/a globset = { version = "=0.4.14" }' Cargo.toml
    echo "✓ Pinned globset = 0.4.14"
fi

echo ""
echo "3. Updated Cargo.toml:"
echo "---"
tail -10 Cargo.toml
echo "---"

# Remove Cargo.lock to force fresh resolution
echo ""
echo "4. Removing Cargo.lock to force fresh dependency resolution..."
rm -f Cargo.lock
echo "✓ Removed Cargo.lock"

echo ""
echo "5. Updating dependencies with pinned versions..."
cargo update

echo ""
echo "================================================================"
echo "✅ Dependency fixes applied"
echo "================================================================"
echo ""
echo "If you still see errors, you may need to pin additional crates."
echo "Backup saved as: Cargo.lock.backup"