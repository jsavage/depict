#!/usr/bin/env bash
# Diagnostic script to understand depict workspace structure

set -euo pipefail

echo "=== Depict Workspace Diagnostics ==="
echo ""

# 1. Rust toolchain
echo "1. Rust Toolchain Information"
echo "=============================="
rustc --version
cargo --version
rustup show
echo ""

# 2. Directory structure
echo "2. Project Directory Structure"
echo "=============================="
echo "Current directory: $(pwd)"
echo ""
echo "Top-level contents:"
ls -la
echo ""

# 3. Cargo workspace
echo "3. Cargo Workspace Configuration"
echo "================================="
if [ -f "Cargo.toml" ]; then
    echo "Root Cargo.toml exists"
    echo ""
    echo "Workspace section:"
    grep -A 20 '\[workspace\]' Cargo.toml || echo "(no workspace section found)"
    echo ""
fi

# 4. Find all Cargo.toml files
echo "4. All Cargo.toml Files in Project"
echo "===================================="
find . -name "Cargo.toml" -type f 2>/dev/null | while read -r toml; do
    echo ""
    echo "File: $toml"
    if grep -q '^\[package\]' "$toml"; then
        package_name=$(grep -A 5 '^\[package\]' "$toml" | grep '^name' | head -1 | cut -d'=' -f2 | tr -d ' "')
        echo "  Package name: $package_name"
    fi
done
echo ""

# 5. List packages using cargo metadata
echo "5. Packages According to Cargo"
echo "==============================="
echo "Running: cargo metadata --no-deps --format-version 1"
echo ""
if command -v jq &> /dev/null; then
    cargo metadata --no-deps --format-version 1 2>/dev/null | \
        jq -r '.packages[] | "  \(.name) (\(.version))"' || \
        echo "(error getting metadata)"
else
    # Without jq, use grep
    cargo metadata --no-deps --format-version 1 2>/dev/null | \
        grep -o '"name":"[^"]*"' | \
        cut -d'"' -f4 | \
        sort -u | \
        sed 's/^/  /' || \
        echo "(error getting metadata)"
fi
echo ""

# 6. Check for common issues
echo "6. Checking for Common Issues"
echo "=============================="

# Check if using nightly
if rustc --version | grep -q nightly; then
    echo "✓ Using nightly Rust"
else
    echo "⚠ Not using nightly Rust (required for OSQP)"
fi

# Check for factorial dependency issue
if [ -f "Cargo.toml" ]; then
    if grep -q 'factorial = "\^0.3"' Cargo.toml; then
        echo "⚠ Found factorial ^0.3 (needs to be 0.4)"
    else
        echo "✓ No factorial ^0.3 issue found"
    fi
fi

# Check for web directory
if [ -d "web" ]; then
    echo "✓ web/ directory exists"
    if [ -f "web/index.html" ]; then
        echo "✓ web/index.html exists"
    else
        echo "⚠ web/index.html not found"
    fi
else
    echo "⚠ web/ directory not found"
fi

# Check for target directory
if [ -d "target" ]; then
    echo "✓ target/ directory exists"
    if [ -d "target/release" ]; then
        echo "  Contents of target/release:"
        ls -lh target/release/ 2>/dev/null | grep -v '^d' | grep -v '\.d$' | grep -v '\.rlib$' | head -20
    fi
else
    echo "⚠ target/ directory not found (no builds yet)"
fi

echo ""
echo "7. Dependency Issues Check"
echo "=========================="
echo "Checking for OSQP and other problematic dependencies..."
echo ""

find . -name "Cargo.toml" -type f | while read -r toml; do
    if grep -q "osqp" "$toml"; then
        echo "Found OSQP reference in: $toml"
        grep "osqp" "$toml"
    fi
done

echo ""
echo "=== End of Diagnostics ==="
echo ""
echo "Next steps:"
echo "1. Review the package names listed in section 5"
echo "2. Use those exact names with 'cargo build -p <package-name>'"
echo "3. If OSQP issues persist, ensure 'rustup override set nightly-2024-05-01' is run"