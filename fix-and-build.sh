#!/usr/bin/env bash
# Comprehensive fix and build script for depict inside container

set -euo pipefail

echo "=== Depict Fix and Build Script ==="
date

# Fix Git ownership
echo "Configuring Git..."
git config --global --add safe.directory /workspace 2>/dev/null || true

# CRITICAL: Install and set nightly toolchain
echo ""
echo "=== CRITICAL: Setting up nightly-2024-05-01 toolchain ==="
if ! rustup toolchain list | grep -q "nightly-2024-05-01"; then
    echo "Installing nightly-2024-05-01..."
    rustup toolchain install nightly-2024-05-01
else
    echo "✓ nightly-2024-05-01 already installed"
fi

# Add wasm32 target to nightly
echo "Adding wasm32-unknown-unknown target to nightly-2024-05-01..."
rustup target add wasm32-unknown-unknown --toolchain nightly-2024-05-01

# Set nightly as override for this directory
echo "Setting nightly-2024-05-01 as override for /workspace..."
rustup override set nightly-2024-05-01

# Verify we're now using nightly
echo ""
echo "Verifying Rust toolchain..."
rustc --version
cargo --version
rustup show

if ! rustc --version | grep -q "nightly"; then
    echo "❌ ERROR: Still not using nightly!"
    echo "Current toolchain:"
    rustup show
    exit 1
fi

echo "✅ Successfully switched to nightly-2024-05-01"

# Uncomment server and tikz in workspace (if commented)
echo ""
echo "Fixing Cargo.toml workspace members..."
if grep -q '#"server"' Cargo.toml; then
    sed -i 's/#"server"/"server"/' Cargo.toml
    echo "  ✓ Uncommented server in workspace"
fi
if grep -q '#"tikz"' Cargo.toml; then
    sed -i 's/#"tikz"/"tikz"/' Cargo.toml
    echo "  ✓ Uncommented tikz in workspace"
fi

# Apply factorial fix if needed
if grep -q 'factorial = "\^0.3"' Cargo.toml 2>/dev/null; then
    sed -i 's/factorial = "\^0.3"/factorial = "0.4"/' Cargo.toml
    echo "  ✓ Fixed factorial version"
fi

# Update dependencies
echo ""
echo "Updating dependencies..."
cargo update

# Verify workspace members
echo ""
echo "Current workspace members:"
cargo metadata --no-deps --format-version 1 2>/dev/null | \
    grep -o '"name":"depict-[^"]*"' | \
    cut -d'"' -f4 | \
    sort -u

# Build desktop
echo ""
echo "=== Building Desktop Application ==="
cargo build --release -p depict-desktop
echo "✅ Desktop built successfully"

# Build server
echo ""
echo "=== Building Server ==="
cargo build --release -p depict-server
echo "✅ Server built successfully"

# Build web WASM
echo ""
echo "=== Building Web WASM ==="
cargo build --release -p depict-web --target wasm32-unknown-unknown
echo "✅ Web WASM built successfully"

# Build web assets with trunk
echo ""
echo "=== Building Web Assets with Trunk ==="
cd web
trunk build --release
cd ..
echo "✅ Web assets built successfully"

# Organize artifacts
echo ""
echo "=== Organizing Build Artifacts ==="
BUILD_DIR="build_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUILD_DIR/dist"

# Copy binaries
cp target/release/depict-desktop "$BUILD_DIR/dist/"
echo "✓ Copied depict-desktop"

cp target/release/depict-server "$BUILD_DIR/dist/"
echo "✓ Copied depict-server"

# Copy web assets
cp -r web/dist/* "$BUILD_DIR/dist/"
echo "✓ Copied web assets"

# Make binaries executable
chmod +x "$BUILD_DIR/dist/depict-desktop"
chmod +x "$BUILD_DIR/dist/depict-server"

echo ""
echo "================================================================"
echo "✅ BUILD COMPLETE"
echo "================================================================"
echo "Build directory: $BUILD_DIR"
echo ""
echo "Contents:"
ls -lh "$BUILD_DIR/dist/" | grep -E '^-' | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "To run the server:"
echo "  cd /workspace"
echo "  WEBROOT=$BUILD_DIR/dist $BUILD_DIR/dist/depict-server"
echo ""
echo "Then access at: http://localhost:8000"
echo ""
echo "================================================================"
date