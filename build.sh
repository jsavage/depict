#!/usr/bin/env bash
# Complete build script for depict project
# Can be run locally or in CI

set -euo pipefail

echo "=== Depict Build Script ==="
echo "Started at: $(date)"
echo ""

# Configuration
BUILD_DIR="build_$(date +%Y%m%d_%H%M%S)"
RELEASE_FLAG="--release"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            RELEASE_FLAG=""
            shift
            ;;
        --output-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--debug] [--output-dir DIR]"
            exit 1
            ;;
    esac
done

# Step 1: Verify toolchain
echo "1. Verifying Rust toolchain..."
echo "================================================"
rustc --version
cargo --version
trunk --version 2>/dev/null || echo "trunk: not found"
wasm-bindgen --version 2>/dev/null || echo "wasm-bindgen: not found"
echo "Build host: $(uname -a)"
echo "Date: $(date)"
echo "================================================"
echo ""

# Step 2: Fix known code issues
echo "2. Applying code fixes..."

# Fix server code - missing 'classes' field in pattern
if [ -f "server/src/main.rs" ]; then
    sed -i '70s/|depict::graph_drawing::frontend::dom::Label{text, hpos, width, vpos}|/|depict::graph_drawing::frontend::dom::Label{text, hpos, width, vpos, ..}|/' server/src/main.rs
    echo "✓ Fixed server/src/main.rs line 70"
fi

# Fix inflector case (common issue)
if [ -f "server/Cargo.toml" ]; then
    sed -i 's/inflector[[:space:]]*=/Inflector =/' server/Cargo.toml
    echo "✓ Fixed Inflector case in server/Cargo.toml"
fi

# Ensure workspace members are uncommented
sed -i 's/#"server"/"server"/' Cargo.toml
sed -i 's/#"tikz"/"tikz"/' Cargo.toml
echo "✓ Verified workspace members"
echo ""

# Step 3: Build desktop application
echo "3. Building desktop application..."
cargo build $RELEASE_FLAG -p depict-desktop
echo "✓ Desktop built"
echo ""

# Step 4: Build server
echo "4. Building server..."
cargo build $RELEASE_FLAG -p depict-server
echo "✓ Server built"
echo ""

# Step 5: Build web WASM
echo "5. Building web WASM..."
cargo build $RELEASE_FLAG -p depict-web --target wasm32-unknown-unknown
echo "✓ Web WASM built"
echo ""

# Step 6: Build web assets with trunk
echo "6. Building web assets..."
cd web
if [ "$RELEASE_FLAG" = "--release" ]; then
    trunk build --release
else
    trunk build
fi
cd ..
echo "✓ Web assets built"
echo ""

# Step 7: Organize build artifacts
echo "7. Organizing build artifacts..."
mkdir -p "$BUILD_DIR/dist"

# Determine the target directory based on release flag
if [ "$RELEASE_FLAG" = "--release" ]; then
    TARGET_DIR="target/release"
else
    TARGET_DIR="target/debug"
fi

# Copy binaries
cp "$TARGET_DIR/depict-desktop" "$BUILD_DIR/dist/"
cp "$TARGET_DIR/depict-server" "$BUILD_DIR/dist/"
echo "✓ Copied binaries"

# Copy web assets
cp -r web/dist/* "$BUILD_DIR/dist/"
echo "✓ Copied web assets"

# Make binaries executable
chmod +x "$BUILD_DIR/dist/depict-desktop"
chmod +x "$BUILD_DIR/dist/depict-server"
echo "✓ Set executable permissions"
echo ""

# Step 8: Create run script
cat > "$BUILD_DIR/run-server.sh" << 'EOF'
#!/usr/bin/env bash
# Script to run the depict server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WEBROOT="$SCRIPT_DIR/dist"
PORT=${PORT:-8000}

echo "Starting depict server..."
echo "Web root: $WEBROOT"
echo "Port: $PORT"
echo "Access at: http://localhost:$PORT"
echo ""

exec "$SCRIPT_DIR/dist/depict-server"
EOF

chmod +x "$BUILD_DIR/run-server.sh"
echo "✓ Created run script"
echo ""

# Step 9: Summary
echo "================================================================"
echo "✅ BUILD COMPLETE"
echo "================================================================"
echo "Build directory: $BUILD_DIR"
echo ""
echo "Contents:"
ls -lh "$BUILD_DIR/dist/" | grep -E '^-' | awk '{printf "  %-30s %10s\n", $9, $5}'
echo ""
echo "To run the server:"
echo "  cd $BUILD_DIR"
echo "  ./run-server.sh"
echo ""
echo "Or manually:"
echo "  WEBROOT=$BUILD_DIR/dist $BUILD_DIR/dist/depict-server"
echo ""
echo "Then open: http://localhost:8000"
echo "================================================================"
echo "Completed at: $(date)"