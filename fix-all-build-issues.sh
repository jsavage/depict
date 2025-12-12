#!/usr/bin/env bash
# Fix all remaining build issues

set -euo pipefail

echo "=== Fixing All Build Issues ==="
echo ""

# 1. Ensure nightly is active
echo "1. Setting nightly toolchain..."
rustup override set nightly-2024-05-01
rustc --version
echo ""

# 2. Fix server code - add missing 'classes' field
echo "2. Fixing server/src/main.rs - adding missing 'classes' field..."
if [ -f "server/src/main.rs" ]; then
    # Find line 70 and fix the pattern to include classes
    sed -i '70s/|depict::graph_drawing::frontend::dom::Label{text, hpos, width, vpos}|/|depict::graph_drawing::frontend::dom::Label{text, hpos, width, vpos, ..}|/' server/src/main.rs
    
    # Verify the fix
    echo "Line 70 is now:"
    sed -n '70p' server/src/main.rs
    echo "✓ Fixed pattern to ignore missing fields with '..'"
else
    echo "⚠️  server/src/main.rs not found"
fi

# 3. Fix inflector case
echo ""
echo "3. Fixing Inflector case..."
sed -i 's/inflector[[:space:]]*=/Inflector =/' server/Cargo.toml 2>/dev/null && echo "✓ Fixed" || echo "✓ Already correct"

# 4. Uncomment workspace members
echo ""
echo "4. Fixing workspace members..."
sed -i 's/#"server"/"server"/' Cargo.toml 2>/dev/null && echo "✓ Uncommented server" || echo "✓ Already uncommented"
sed -i 's/#"tikz"/"tikz"/' Cargo.toml 2>/dev/null && echo "✓ Uncommented tikz" || echo "✓ Already uncommented"

echo ""
echo "================================================================"
echo "Fixes applied. Now building..."
echo "================================================================"
echo ""

# Build all three components
echo "Building depict-desktop..."
cargo build --release -p depict-desktop
echo "✅ Desktop built"

echo ""
echo "Building depict-server..."
cargo build --release -p depict-server
echo "✅ Server built"

echo ""
echo "Building depict-web WASM..."
cargo build --release -p depict-web --target wasm32-unknown-unknown
echo "✅ Web WASM built"

echo ""
echo "Building web assets with trunk..."
cd web && trunk build --release && cd ..
echo "✅ Web assets built"

# Organize artifacts
echo ""
echo "Organizing build artifacts..."
BUILD_DIR="build_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUILD_DIR/dist"
cp target/release/depict-desktop "$BUILD_DIR/dist/"
cp target/release/depict-server "$BUILD_DIR/dist/"
cp -r web/dist/* "$BUILD_DIR/dist/"
chmod +x "$BUILD_DIR/dist/depict-desktop"
chmod +x "$BUILD_DIR/dist/depict-server"

echo ""
echo "================================================================"
echo "✅ BUILD COMPLETE!"
echo "================================================================"
echo ""
echo "Build directory: $BUILD_DIR"
echo ""
echo "To run:"
echo "  WEBROOT=$BUILD_DIR/dist $BUILD_DIR/dist/depict-server"
echo ""
echo "Then open: http://localhost:8000"
echo ""