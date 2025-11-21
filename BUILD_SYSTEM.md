# Depict Build System Documentation

This document describes the automated build, test, and diagnostic system for the depict project.

## Overview

The build system consists of four main components:

1. **diagnose.sh** - Captures complete project state for debugging
2. **build.sh** - Builds the project using multiple strategies
3. **test.sh** - Integration tests for web server and SVG export
4. **GitHub Actions** - Automated CI/CD pipeline

## Quick Start

### Fresh Fork Strategy

If you're deciding whether to start with a fresh fork:

```bash
# First, diagnose your current fork
cd your-current-fork
./diagnose.sh

# Archive the diagnostics for comparison
cp diagnostics/*.tar.gz ~/depict-diagnostics-old.tar.gz

# Then create fresh fork and compare
cd ~/
git clone https://github.com/mstone/depict.git depict-fresh
cd depict-fresh

# Copy scripts to fresh fork
# (Add diagnose.sh, build.sh, test.sh to the repository)

./diagnose.sh
./build.sh --method cargo
```

**Recommendation:** Keep your current fork if it has working desktop builds, but create the fresh fork in parallel to compare diagnostics.

## Script Details

### 1. diagnose.sh - Diagnostic Script

**Purpose:** Captures complete project state for debugging and sharing with collaborators (or Claude in future conversations).

**Usage:**
```bash
chmod +x diagnose.sh
./diagnose.sh
```

**What it captures:**

- System information (OS, kernel, architecture)
- Rust toolchain details (rustc, cargo, rustup versions)
- Project structure (Cargo.toml files, workspace members)
- Dependency trees (for each package)
- Features and build configurations
- Git status and history
- Nix configuration (if available)
- Build tool availability
- Initial build checks

**Output:**

- Creates `diagnostics/YYYYMMDD_HHMMSS/` directory
- Generates ~40+ individual `.txt` files with detailed information
- Creates `00_SUMMARY.txt` with quick overview
- Produces compressed `.tar.gz` archive for easy sharing

**Sharing with Claude:**

In future conversations, simply upload:
- The `diagnostics_YYYYMMDD_HHMMSS.tar.gz` file, OR
- Individual `.txt` files from the diagnostics directory, OR
- Just the `00_SUMMARY.txt` for quick context

This allows Claude to understand your exact environment and build state.

### 2. build.sh - Build Script

**Purpose:** Attempts to build depict using multiple strategies with fallback options.

**Usage:**
```bash
chmod +x build.sh

# Auto-detect best method
./build.sh

# Force specific method
./build.sh --method cargo
./build.sh --method nix
./build.sh --method docker

# Clean build
./build.sh --clean
```

**Build Methods:**

1. **Cargo (Direct)**
   - Best for: Development, debugging, Ubuntu/Debian systems
   - Requires: Rust/Cargo installed
   - Installs: trunk, wasm-bindgen-cli if needed
   - Builds: depict-desktop, depict-server, depict-web (WASM)

2. **Nix**
   - Best for: Reproducible builds, NixOS users
   - Requires: Nix with flakes enabled
   - Uses: flake.nix configuration
   - Most reproducible method

3. **Docker**
   - Best for: Clean environment, CI/CD, Ubuntu 22.04
   - Requires: Docker or Podman
   - Creates: Isolated build environment
   - Most portable method

**Output:**

- Creates `build_output/YYYYMMDD_HHMMSS/` directory
- `dist/` - Built binaries and web assets
- `logs/` - Detailed build logs for each step
- `BUILD_SUMMARY.txt` - Summary of build results

**Troubleshooting:**

If build fails, check logs in order:
1. `logs/10_desktop_build.log` - Desktop build
2. `logs/11_server_build.log` - Server build
3. `logs/12_web_wasm_build.log` - WASM compilation
4. `logs/13_trunk_build.log` - Web assets bundling

### 3. test.sh - Integration Test Script

**Purpose:** Validates that the web server works correctly and can export SVG files.

**Usage:**
```bash
chmod +x test.sh

# Auto-find server binary
./test.sh

# Specify server location
./test.sh --server-path ./target/release/depict-server

# Custom port
./test.sh --port 8080
```

**Tests Performed:**

1. **Port Listening Test**
   - Verifies server is listening on specified port
   - Checks process is running

2. **Server Responsiveness Test**
   - HTTP GET to root endpoint
   - Validates 200 OK response
   - Saves HTML content for inspection

3. **Page Content Test**
   - Checks for input elements (DSL textarea)
   - Verifies SVG/Canvas rendering elements
   - Looks for export functionality
   - Confirms JavaScript/WASM loading

4. **SVG Export Test**
   - Attempts to trigger SVG export
   - Downloads exported SVG file
   - Validates SVG structure and content
   - Checks for actual drawing elements

**Output:**

- Creates `test_results/YYYYMMDD_HHMMSS/` directory
- `TEST_REPORT.txt` - Complete test report
- `test_results.log` - Detailed test output
- `homepage.html` - Captured web page
- `exported.svg` - Exported SVG file (if successful)
- `server.log` - Server output during tests

**Test Validation:**

The script validates SVG files by checking:
- Valid XML/SVG structure
- Proper opening and closing tags
- Dimensions (viewBox or width/height)
- Drawing elements (rect, circle, path, text, etc.)
- Reasonable file size

### 4. GitHub Actions Workflow

**Purpose:** Automated CI/CD pipeline that runs on every push/PR.

**Setup:**
```bash
mkdir -p .github/workflows
# Copy build-and-test.yml to .github/workflows/
git add .github/workflows/build-and-test.yml
git commit -m "Add CI/CD pipeline"
git push
```

**Jobs:**

1. **diagnostics** - Runs diagnostic script
2. **build-cargo** - Builds with Cargo
3. **build-nix** - Builds with Nix (optional)
4. **build-docker** - Builds with Docker
5. **test** - Runs integration tests
6. **analysis** - Code quality checks (clippy, fmt, bloat)
7. **report** - Generates consolidated report

**Artifacts:**

All jobs upload artifacts that persist for 30-90 days:
- Diagnostic results
- Build logs
- Built binaries
- Test results
- Analysis reports

**Accessing Results:**

1. Go to your GitHub repository
2. Click "Actions" tab
3. Select a workflow run
4. Download artifacts from the bottom of the page

## Docker Build Environment

**Purpose:** Provides Ubuntu 22.04-based reproducible build environment.

**Usage:**

```bash
# Build the image
docker build -t depict-builder .

# Or with Podman
podman build -t depict-builder .

# Run interactive shell
docker run -it --rm -v $(pwd):/workspace depict-builder bash

# Inside container:
./diagnose.sh
./build.sh
./test.sh

# Run server and expose port
docker run -it --rm -p 8080:8080 -v $(pwd):/workspace depict-builder bash
# Inside: ./build.sh && ./test.sh
```

**Benefits:**

- Ubuntu 22.04 (avoids Ubuntu 24.04 issues)
- All dependencies pre-installed
- Consistent environment across machines
- Easy to share and reproduce

## Complete Workflow Example

### Starting Fresh

```bash
# 1. Create fresh fork or clone existing
git clone https://github.com/YOUR_USERNAME/depict.git
cd depict

# 2. Add build system files
# (Copy diagnose.sh, build.sh, test.sh, Dockerfile, .github/workflows/)

chmod +x *.sh

# 3. Run diagnostics first
./diagnose.sh

# Review summary
cat diagnostics/$(ls -t diagnostics/ | head -1)/00_SUMMARY.txt

# 4. Attempt build
./build.sh

# If build fails, try Docker
./build.sh --method docker

# 5. If build succeeds, run tests
./test.sh

# 6. Review all results
ls -la build_output/$(ls -t build_output/ | head -1)/
ls -la test_results/$(ls -t test_results/ | head -1)/
```

### Debugging Failed Builds

```bash
# 1. Collect diagnostics
./diagnose.sh

# 2. Try clean build
./build.sh --clean

# 3. Review specific error logs
cat build_output/latest/logs/*.log

# 4. Try alternate method
./build.sh --method docker

# 5. Share diagnostics
# Upload diagnostics/*.tar.gz to Claude or GitHub issue
```

### Sharing Results with Claude

For subsequent conversations with Claude:

**Option 1: Upload compressed diagnostics**
```bash
# Find latest diagnostic archive
ls -t diagnostics/*.tar.gz | head -1

# Upload this file to Claude in your next conversation
```

**Option 2: Upload specific files**
```bash
# Find latest diagnostic directory
LATEST=$(ls -t diagnostics/ | grep -E '^[0-9]' | head -1)

# Upload these key files:
diagnostics/$LATEST/00_SUMMARY.txt           # Overview
diagnostics/$LATEST/30_workspace_cargo_toml.txt  # Project structure
diagnostics/$LATEST/120_cargo_check.txt      # Build errors
diagnostics/$LATEST/95_current_commit.txt    # Git state
```

**Option 3: Share specific sections**

Just copy-paste relevant sections from `.txt` files in the diagnostics directory.

## Continuous Improvement

### Keeping Scripts Updated

```bash
# In your fork, create a branch for build system updates
git checkout -b update-build-system

# Modify scripts as needed
vim build.sh

# Test changes
./build.sh --clean

# Commit and push
git add *.sh
git commit -m "Update build system"
git push origin update-build-system
```

### Adding Custom Tests

Edit `test.sh` to add custom validation:

```bash
# Add after test_svg_export() function
test_custom_feature() {
    log "Test: Custom feature validation..."
    
    # Your test logic here
    
    if [ success ]; then
        pass "Custom test passed"
        save_result "custom_test" "PASS" "Details here"
        return 0
    else
        error "Custom test failed"
        save_result "custom_test" "FAIL" "Error details"
        return 1
    fi
}

# Add to main() function:
if test_custom_feature; then
    tests_passed=$((tests_passed + 1))
fi
```

## Troubleshooting Common Issues

### WASM Target Not Found

```bash
rustup target add wasm32-unknown-unknown
```

### Trunk Not Found

```bash
cargo install trunk --locked
```

### Permission Denied

```bash
chmod +x diagnose.sh build.sh test.sh
```

### Port Already in Use

```bash
# Kill process on port 8080
lsof -ti:8080 | xargs kill -9
```

### Docker Build Fails

```bash
# Try with more resources
docker build --memory=4g --cpus=2 -t depict-builder .

# Or use Podman
podman build -t depict-builder .
```

### Nix Flake Issues

```bash
# Update flake lock
nix flake update

# Clear Nix cache
nix-collect-garbage -d
```

## Platform-Specific Notes

### Ubuntu 22.04 (Recommended)

```bash
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libssl-dev curl git

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Run build system
./diagnose.sh && ./build.sh && ./test.sh
```

### Ubuntu 24.04 (Known Issues)

If encountering issues:
- Use Docker with Ubuntu 22.04 base
- Or use Nix for reproducible builds

### macOS

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Proceed normally
./diagnose.sh && ./build.sh && ./test.sh
```

### NixOS

```bash
# Ensure flakes enabled in /etc/nixos/configuration.nix:
# nix.settings.experimental-features = [ "nix-command" "flakes" ];

# Build directly with Nix
nix build .#desktop
nix build .#server
nix build .#web

# Or use build script
./build.sh --method nix
```

## Advanced Usage

### Custom Build Configurations

```bash
# Build only desktop
cargo build --release -p depict-desktop

# Build with specific features
cargo build --release -p depict-web --features "feature1,feature2"

# Build in Docker with custom base
docker build --build-arg BASE_IMAGE=ubuntu:22.04 -t depict-builder .
```

### Parallel Testing

```bash
# Test on multiple ports simultaneously
./test.sh --port 8080 &
./test.sh --port 8081 &
./test.sh --port 8082 &
wait
```

### Continuous Monitoring

```bash
# Watch for changes and rebuild
cargo watch -x "build -p depict-web"

# Or use the script
while true; do
    ./build.sh && ./test.sh
    sleep 300  # Every 5 minutes
done
```

## Support and Contribution

### Reporting Build Issues

When reporting issues, always include:

1. Diagnostic archive: `diagnostics/diagnostics_YYYYMMDD_HHMMSS.tar.gz`
2. Build logs: `build_output/YYYYMMDD_HHMMSS/logs/*.log`
3. System info: Output of `./diagnose.sh`
4. Steps to reproduce

### Contributing Improvements

1. Fork the repository
2. Create feature branch
3. Modify scripts
4. Test thoroughly with `./diagnose.sh && ./build.sh --clean && ./test.sh`
5. Submit PR with test results

## Appendix: File Structure

```
depict/
├── diagnose.sh              # Diagnostic script
├── build.sh                 # Build script
├── test.sh                  # Test script
├── Dockerfile               # Docker build environment
├── BUILD_SYSTEM.md          # This file
├── .github/
│   └── workflows/
│       └── build-and-test.yml  # CI/CD pipeline
├── diagnostics/             # Generated diagnostics (gitignored)
│   ├── YYYYMMDD_HHMMSS/
│   │   ├── 00_SUMMARY.txt
│   │   ├── 01_system_info.txt
│   │   └── ...
│   └── diagnostics_*.tar.gz
├── build_output/            # Generated builds (gitignored)
│   └── YYYYMMDD_HHMMSS/
│       ├── BUILD_SUMMARY.txt
│       ├── dist/           # Built artifacts
│       └── logs/           # Build logs
└── test_results/            # Generated tests (gitignored)
    └── YYYYMMDD_HHMMSS/
        ├── TEST_REPORT.txt
        ├── exported.svg
        └── ...
```

## Quick Reference

| Task | Command |
|------|---------|
| Diagnose project | `./diagnose.sh` |
| Build (auto) | `./build.sh` |
| Build (cargo) | `./build.sh --method cargo` |
| Build (docker) | `./build.sh --method docker` |
| Clean build | `./build.sh --clean` |
| Run tests | `./test.sh` |
| Test specific server | `./test.sh --server-path ./target/release/depict-server` |
| Docker shell | `docker run -it --rm depict-builder bash` |
| View latest diag | `cat diagnostics/$(ls -t diagnostics/ \| grep '^[0-9]' \| head -1)/00_SUMMARY.txt` |
| View latest build | `cat build_output/$(ls -t build_output/ \| grep '^[0-9]' \| head -1)/BUILD_SUMMARY.txt` |
| View latest test | `cat test_results/$(ls -t test_results/ \| grep '^[0-9]' \| head -1)/TEST_REPORT.txt` |

---

**Last Updated:** 2024-11-21
**Version:** 1.0
