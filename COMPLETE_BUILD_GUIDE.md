# Depict Complete Build Guide - Successful Configuration

**Date:** November 23, 2025  
**Status:** ✅ WORKING BUILD ACHIEVED

## Summary

Successfully built all three components of depict:
- Desktop GUI (native)
- Server (native)
- Web Interface (WASM)

## Critical Success Factors

### 1. Operating System
- **Ubuntu 22.04** (NOT 24.04)
- Ubuntu 24.04 has webkit2gtk-4.1, but depict needs webkit2gtk-4.0
- Solution: Use Docker with Ubuntu 22.04 base image

### 2. Rust Toolchain
- **nightly-2024-05-01** (or any from 2024-05-01 through 2024-11-01)
- Earlier nightlies (2022-2024-04) all fail
- Stable toolchain fails due to osqp requiring nightly features

### 3. Key Dependencies
```bash
# System packages (Ubuntu 22.04)
build-essential
pkg-config
cmake
libssl-dev
curl
git
libwebkit2gtk-4.0-dev  # Critical: 4.0, not 4.1
libgtk-3-dev
libsoup2.4-dev

# Rust targets
wasm32-unknown-unknown

# Rust tools
trunk
wasm-bindgen-cli
```

### 4. Code Modifications Required
- **server/src/main.rs line 70**: Add `..` to Label pattern match for missing `classes` field
- **Cargo.toml**: Change `factorial = "^0.3"` to `factorial = "0.4"`

## Complete Reproduction Steps

### Step 1: Create Docker Environment

```dockerfile
# Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    cmake \
    libssl-dev \
    curl \
    git \
    libwebkit2gtk-4.0-dev \
    libgtk-3-dev \
    libsoup2.4-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain stable
ENV PATH=/root/.cargo/bin:$PATH

# Install specific nightly that works
RUN rustup install nightly-2024-05-01
RUN rustup default nightly-2024-05-01

# Install WASM target
RUN rustup target add wasm32-unknown-unknown

# Install build tools
RUN cargo install trunk wasm-bindgen-cli

WORKDIR /workspace

EXPOSE 8000

CMD ["bash"]
```

### Step 2: Build Docker Image

```bash
docker build -t depict-builder .
```

### Step 3: Run Container with Port Mapping

```bash
# Map port 8000 from container to host
docker run -it --rm -v $(pwd):/workspace -p 8000:8000 depict-builder
```

### Step 4: Inside Container - Apply Code Fixes

```bash
# Fix server/src/main.rs line 70
sed -i 's/Label{text, hpos, width, vpos}/Label{text, hpos, width, vpos, ..}/g' server/src/main.rs

# Fix Cargo.toml factorial dependency
sed -i 's/factorial = "\^0.3"/factorial = "0.4"/' Cargo.toml

# Update dependencies
cargo update
```

### Step 5: Build All Components

```bash
# Use nightly-2024-05-01 (already set as default)
rustup override set nightly-2024-05-01

# Build desktop
cargo build --release -p depict-desktop

# Build server
cargo build --release -p depict-server

# Build web (WASM)
cargo build --release -p depict-web --target wasm32-unknown-unknown

# Build web assets with trunk
cd web
trunk build --release
cd ..
```

### Step 6: Organize Build Artifacts

```bash
BUILD_DIR="build_output/final_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUILD_DIR/dist"

# Copy binaries
cp target/release/depict-desktop "$BUILD_DIR/dist/"
cp target/release/depict-server "$BUILD_DIR/dist/"

# Copy web assets
cp -r web/dist/* "$BUILD_DIR/dist/"

# Verify
ls -lh "$BUILD_DIR/dist/"
```

### Step 7: Run Server

```bash
# Server needs WEBROOT environment variable
WEBROOT="$BUILD_DIR/dist" "$BUILD_DIR/dist/depict-server" &

# Server listens on port 8000 (not 8080!)
# Access at http://localhost:8000
```

## Build Times (Approximate)

- Docker image build: ~25 minutes
- Desktop build: ~8 minutes
- Server build: ~4 minutes  
- Web WASM build: ~3 minutes
- Trunk web assets: ~1 minute
- **Total: ~40 minutes**

## File Sizes

- depict-desktop: 32 MB
- depict-server: 16 MB
- depict-web WASM: 4.7 MB
- Total web assets: ~5 MB

## Architecture Understanding

```
┌─────────────────────────────────────┐
│     depict-core (library)           │
│  - DSL Parser                       │
│  - Layout Engine (uses osqp)        │
│  - SVG Generation                   │
└─────────────────────────────────────┘
           │              │
           ▼              ▼
    ┌──────────┐    ┌──────────────┐
    │ Web UI   │    │ Desktop UI   │
    │ (WASM)   │    │ (Native)     │
    │ +Dioxus  │    │ +Dioxus      │
    └──────────┘    └──────────────┘
           │
           ▼
    ┌──────────────┐
    │ depict-server│
    │ (serves web) │
    │ port 8000    │
    └──────────────┘
```

## Key Issues Encountered & Solutions

### Issue 1: Ubuntu 24.04 webkit incompatibility
**Error:** `could not find system library 'javascriptcoregtk-4.0'`  
**Solution:** Use Ubuntu 22.04 which has webkit2gtk-4.0

### Issue 2: osqp requires nightly Rust
**Error:** `#![feature]` may not be used on stable  
**Solution:** Use nightly-2024-05-01 or later

### Issue 3: Most nightlies don't work
**Error:** Various compilation errors  
**Solution:** Nightlies from 2024-05-01 through 2024-11-01 work. Earlier ones fail.

### Issue 4: Server missing Label::classes field
**Error:** `pattern does not mention field 'classes'`  
**Solution:** Add `..` to pattern: `Label{text, hpos, width, vpos, ..}`

### Issue 5: factorial version mismatch
**Error:** `failed to select a version for factorial = "^0.3"`  
**Solution:** Update to factorial 0.4

### Issue 6: Server needs WEBROOT variable
**Error:** `NotPresent` when starting server  
**Solution:** Set `WEBROOT` to directory containing web assets

### Issue 7: Server uses port 8000, not 8080
**Error:** Cannot connect on 8080  
**Solution:** Server defaults to port 8000

## Testing Results

### Successful Nightly Versions
Tested 29 nightly versions systematically:
- ❌ 2022-07-01 through 2024-04-01: All failed
- ✅ 2024-05-01: SUCCESS
- ✅ 2024-06-01: SUCCESS
- ✅ 2024-07-01: SUCCESS
- ✅ 2024-08-01: SUCCESS
- ✅ 2024-09-01: SUCCESS
- ✅ 2024-10-01: SUCCESS
- ✅ 2024-11-01: SUCCESS

**Recommendation:** Use `nightly-2024-05-01` (earliest working version)

## Why osqp Fork?

The project uses a forked version of osqp:
```toml
osqp-rust = { version = "0.6", git = "https://github.com/mstone/osqp.rs" }
```

**Reason:** The fork adds WASM support (32-bit and 64-bit versions)  
**Commit:** 895b8d5 "osqp-rust-sys: generate both 64-bit and 32-bit versions"  
**Date:** June 27, 2022

The fork modifies:
- `wasm: libc -> ::std::os::raw, intptr_t -> isize`
- Generates both 32-bit and 64-bit bindings for WASM targets

## Accessing from Host Machine

The container runs with port mapping `-p 8000:8000`, so:

**From host machine browser:** `http://localhost:8000`

If you can't connect, check:
1. Container was started with `-p 8000:8000`
2. Server is running inside container
3. No firewall blocking port 8000

To restart with proper port mapping:
```bash
docker run -it --rm -v $(pwd):/workspace -p 8000:8000 depict-builder
```

## Quick Start Script

Save this as `quick_build.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Apply fixes
sed -i 's/Label{text, hpos, width, vpos}/Label{text, hpos, width, vpos, ..}/g' server/src/main.rs
sed -i 's/factorial = "\^0.3"/factorial = "0.4"/' Cargo.toml

# Set toolchain
rustup override set nightly-2024-05-01
rustup target add wasm32-unknown-unknown

# Update deps
cargo update

# Build all
cargo build --release -p depict-desktop
cargo build --release -p depict-server
cargo build --release -p depict-web --target wasm32-unknown-unknown
cd web && trunk build --release && cd ..

# Organize
BUILD_DIR="build_output/final_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUILD_DIR/dist"
cp target/release/depict-desktop "$BUILD_DIR/dist/"
cp target/release/depict-server "$BUILD_DIR/dist/"
cp -r web/dist/* "$BUILD_DIR/dist/"

echo "Build complete: $BUILD_DIR"
echo "To run: WEBROOT=$BUILD_DIR/dist $BUILD_DIR/dist/depict-server"
```

## Files to Commit to Your Fork

1. **Updated Dockerfile** (with Ubuntu 22.04, cmake, nightly-2024-05-01)
2. **build.sh** (simplified build script)
3. **test_nightly_versions.sh** (for future testing)
4. **COMPLETE_BUILD_GUIDE.md** (this document)
5. **Code fixes:**
   - `server/src/main.rs` (Label pattern fix)
   - `Cargo.toml` (factorial version)

## Next Steps

1. ✅ Build succeeded in Docker
2. ⚠️ Access from host needs port mapping verification
3. 📝 Test SVG export functionality
4. 📝 Document web interface features
5. 📝 Create GitHub release with binaries
6. 📝 Update main README with build instructions

## Troubleshooting

### Can't access from host
```bash
# Check container has port mapping
docker ps
# Should show: 0.0.0.0:8000->8000/tcp

# Check server is running in container
docker exec <container-id> ps aux | grep depict-server

# Check server logs
docker exec <container-id> cat /workspace/build_output/*/logs/*.log
```

### Build fails in future
- Ensure using Ubuntu 22.04 (not 24.04)
- Ensure using nightly-2024-05-01 or later working version
- Ensure cmake is installed
- Ensure all code fixes are applied

### Server won't start
- Check WEBROOT is set and points to directory with web assets
- Check port 8000 isn't already in use
- Run in foreground to see errors

## Resources

- **Working Docker Hub image:** (create and push your image)
- **Test suite:** `test_nightly_versions.sh`
- **Original repo:** https://github.com/mstone/depict
- **Your fork:** https://github.com/jsavage/depict
- **Online demo:** https://mstone.info/depict/

## Success Metrics

- ✅ Desktop builds without errors
- ✅ Server builds without errors
- ✅ Web builds to WASM without errors
- ✅ Trunk bundles web assets successfully
- ✅ Server starts and serves on port 8000
- ✅ HTML page loads with WASM module
- ⏳ Web interface renders correctly (needs browser test)
- ⏳ SVG export works (needs functional test)

---

**Build Status:** SUCCESSFUL  
**Last Updated:** 2025-11-23 23:23 UTC  
**Build Time:** ~40 minutes  
**Container:** Ubuntu 22.04 + Rust nightly-2024-05-01