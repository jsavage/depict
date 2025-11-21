#!/usr/bin/env bash
set -euo pipefail

# Depict Build System Setup Script
# Usage: ./setup_build_system.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

log "=== Depict Build System Setup ==="
echo ""

# Create directory structure
log "Creating directory structure..."
mkdir -p .github/workflows
mkdir -p diagnostics
mkdir -p build_output
mkdir -p test_results

# Add to .gitignore
log "Updating .gitignore..."
if [ -f .gitignore ]; then
    if ! grep -q "diagnostics/" .gitignore; then
        echo "" >> .gitignore
        echo "# Build system outputs" >> .gitignore
        echo "diagnostics/" >> .gitignore
        echo "build_output/" >> .gitignore
        echo "test_results/" >> .gitignore
    fi
else
    cat > .gitignore << 'EOF'
# Rust
target/
Cargo.lock

# Build system outputs
diagnostics/
build_output/
test_results/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
fi

# Make scripts executable
log "Making scripts executable..."
chmod +x diagnose.sh 2>/dev/null || warn "diagnose.sh not found"
chmod +x build.sh 2>/dev/null || warn "build.sh not found"
chmod +x test.sh 2>/dev/null || warn "test.sh not found"

# Check for required tools
log "Checking system requirements..."

check_tool() {
    if command -v "$1" &> /dev/null; then
        log "✓ $1 found: $($1 --version 2>&1 | head -1)"
        return 0
    else
        warn "✗ $1 not found"
        return 1
    fi
}

MISSING_TOOLS=0

if ! check_tool rustc; then
    error "Rust is not installed. Install from: https://rustup.rs/"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

if ! check_tool cargo; then
    error "Cargo is not installed."
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

if ! check_tool git; then
    warn "Git is not installed."
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

# Optional tools
check_tool nix || warn "Nix not installed (optional)"
check_tool docker || check_tool podman || warn "Docker/Podman not installed (optional)"

# Check WASM target
log "Checking WASM target..."
if rustup target list --installed 2>/dev/null | grep -q "wasm32-unknown-unknown"; then
    log "✓ WASM target installed"
else
    warn "WASM target not installed"
    log "Installing WASM target..."
    rustup target add wasm32-unknown-unknown || error "Failed to install WASM target"
fi

# Check for trunk
if ! command -v trunk &> /dev/null; then
    warn "trunk not installed"
    log "Do you want to install trunk now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Installing trunk..."
        cargo install trunk --locked || warn "Failed to install trunk"
    fi
fi

# Check for wasm-bindgen
if ! command -v wasm-bindgen &> /dev/null; then
    warn "wasm-bindgen-cli not installed"
    log "Do you want to install wasm-bindgen-cli now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Installing wasm-bindgen-cli..."
        cargo install wasm-bindgen-cli --locked || warn "Failed to install wasm-bindgen-cli"
    fi
fi

echo ""

if [ $MISSING_TOOLS -gt 0 ]; then
    error "Missing required tools. Please install them and run this script again."
    exit 1
fi

# Run initial diagnostic
log "Running initial diagnostic..."
if [ -f "./diagnose.sh" ]; then
    ./diagnose.sh
    
    LATEST_DIAG=$(find diagnostics -type d -name "20*" | sort | tail -1)
    if [ -d "$LATEST_DIAG" ]; then
        log "Diagnostic complete! Summary:"
        echo ""
        cat "$LATEST_DIAG/00_SUMMARY.txt"
        echo ""
        log "Full diagnostics saved to: $LATEST_DIAG"
    fi
else
    error "diagnose.sh not found. Please ensure all scripts are in the repository."
fi

# Prompt for initial build
echo ""
log "Setup complete! Would you like to attempt an initial build now? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    log "Starting build..."
    if [ -f "./build.sh" ]; then
        ./build.sh
    else
        error "build.sh not found."
        exit 1
    fi
    
    # Check build results
    LATEST_BUILD=$(find build_output -type f -name "BUILD_SUMMARY.txt" | sort | tail -1)
    if [ -f "$LATEST_BUILD" ]; then
        echo ""
        log "Build summary:"
        echo ""
        cat "$LATEST_BUILD"
    fi
    
    # Prompt for tests
    echo ""
    log "Would you like to run tests now? (y/n)"
    read -r test_response
    
    if [[ "$test_response" =~ ^[Yy]$ ]]; then
        if [ -f "./test.sh" ]; then
            ./test.sh
        else
            error "test.sh not found."
        fi
    fi
fi

echo ""
log "=== Setup Complete ==="
echo ""
log "Next steps:"
echo "  1. Review diagnostics: cat diagnostics/$(ls -t diagnostics/ | grep '^[0-9]' | head -1)/00_SUMMARY.txt"
echo "  2. Run build: ./build.sh"
echo "  3. Run tests: ./test.sh"
echo "  4. Read docs: cat BUILD_SYSTEM.md"
echo ""
log "For issues, share diagnostics/*.tar.gz with Claude or in GitHub issues"
echo ""

# Create quick reference card
cat > QUICK_START.txt << 'EOF'
==============================================
  Depict Build System - Quick Start
==============================================

DIAGNOSE PROJECT:
  ./diagnose.sh

BUILD PROJECT:
  ./build.sh                    # Auto-detect method
  ./build.sh --method cargo     # Use Cargo
  ./build.sh --method docker    # Use Docker
  ./build.sh --clean            # Clean build

RUN TESTS:
  ./test.sh
  ./test.sh --port 8080

VIEW RESULTS:
  Latest diagnostic summary:
    cat diagnostics/$(ls -t diagnostics/ | grep '^[0-9]' | head -1)/00_SUMMARY.txt
  
  Latest build summary:
    cat build_output/$(ls -t build_output/ | grep '^[0-9]' | head -1)/BUILD_SUMMARY.txt
  
  Latest test report:
    cat test_results/$(ls -t test_results/ | grep '^[0-9]' | head -1)/TEST_REPORT.txt

DOCKER:
  docker build -t depict-builder .
  docker run -it --rm -p 8080:8080 depict-builder

HELP:
  cat BUILD_SYSTEM.md

==============================================
EOF

log "Quick reference saved to: QUICK_START.txt"
