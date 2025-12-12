#!/usr/bin/env bash
# Found in workspace folder of container
set -euo pipefail

echo "=== Building Depict ==="
date

BUILD_DIR="build_output/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUILD_DIR/logs" "$BUILD_DIR/dist"

echo "Build directory: $BUILD_DIR"

# Install WASM target
if ! rustup target list --installed | grep -q "wasm32-unknown-unknown"; then
    echo "Installing WASM target..."
    rustup target add wasm32-unknown-unknown
fi

# Build desktop
echo "=== Building Desktop ==="
cargo build --release -p depict-desktop 2>&1 | tee "$BUILD_DIR/logs/desktop.log"
[ -f "target/release/depict-desktop" ] && cp target/release/depict-desktop "$BUILD_DIR/dist/"

# Build server
echo "=== Building Server ==="
cargo build --release -p depict-server 2>&1 | tee "$BUILD_DIR/logs/server.log"
[ -f "target/release/depict-server" ] && cp target/release/depict-server "$BUILD_DIR/dist/"

# Build web
echo "=== Building Web ==="
cargo build --release -p depict-web --target wasm32-unknown-unknown 2>&1 | tee "$BUILD_DIR/logs/web.log"

echo "Build complete! Logs in: $BUILD_DIR/logs/"
ls -lh "$BUILD_DIR/dist/"
