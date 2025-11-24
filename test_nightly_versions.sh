#!/usr/bin/env bash
set -euo pipefail

# Test Multiple Nightly Versions Script
# Systematically tests nightly Rust versions to find one that works

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# The osqp fork was created on 2022-06-27
# Let's test nightlies from that point forward

NIGHTLIES=(
    "2022-07-01"   # Right after fork creation
    "2022-08-01"
    "2022-09-01"
    "2022-10-01"
    "2022-11-01"
    "2022-12-01"
    "2023-01-01"
    "2023-02-01"
    "2023-03-01"
    "2023-04-01"
    "2023-05-01"
    "2023-06-01"
    "2023-07-01"
    "2023-08-01"
    "2023-09-01"
    "2023-10-01"
    "2023-11-01"
    "2023-12-01"
    "2024-01-01"
    "2024-02-01"
    "2024-03-01"
    "2024-04-01"
    "2024-05-01"
    "2024-06-01"
    "2024-07-01"
    "2024-08-01"
    "2024-09-01"
    "2024-10-01"
    "2024-11-01"
)

RESULTS_DIR="nightly_test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

log "Testing ${#NIGHTLIES[@]} nightly versions"
log "Results will be saved to: $RESULTS_DIR"
echo ""

SUCCESSFUL_NIGHTLIES=()

for nightly in "${NIGHTLIES[@]}"; do
    log "========================================"
    log "Testing nightly-$nightly"
    log "========================================"
    
    # Install nightly
    if rustup install "nightly-$nightly" 2>&1 | tee "$RESULTS_DIR/install_$nightly.log"; then
        log "✓ Installed nightly-$nightly"
    else
        error "✗ Failed to install nightly-$nightly"
        echo "INSTALL_FAILED" > "$RESULTS_DIR/result_$nightly.txt"
        continue
    fi
    
    # Set as override
    rustup override set "nightly-$nightly"
    
    # Install WASM target
    if rustup target add wasm32-unknown-unknown 2>&1 | tee -a "$RESULTS_DIR/install_$nightly.log"; then
        log "✓ WASM target installed"
    else
        warn "⚠ WASM target install had issues"
    fi
    
    # Show version
    rustc --version > "$RESULTS_DIR/version_$nightly.txt"
    log "Rust version: $(rustc --version)"
    
    # Update dependencies to compatible versions
    log "Updating dependencies..."
    cargo update 2>&1 | tee "$RESULTS_DIR/update_$nightly.log" || true
    
    # Clean previous build artifacts
    cargo clean 2>/dev/null || true
    
    # Try building web
    log "Building depict-web..."
    if timeout 300 cargo build --release -p depict-web --target wasm32-unknown-unknown \
        > "$RESULTS_DIR/build_$nightly.log" 2>&1; then
        success "✓✓✓ SUCCESS with nightly-$nightly ✓✓✓"
        echo "SUCCESS" > "$RESULTS_DIR/result_$nightly.txt"
        SUCCESSFUL_NIGHTLIES+=("$nightly")
        
        # Check if binaries exist
        if [ -f "target/wasm32-unknown-unknown/release/depict_web.wasm" ]; then
            ls -lh target/wasm32-unknown-unknown/release/depict_web.wasm \
                > "$RESULTS_DIR/artifacts_$nightly.txt"
        fi
    else
        error "✗ Build failed with nightly-$nightly"
        echo "BUILD_FAILED" > "$RESULTS_DIR/result_$nightly.txt"
        
        # Extract error summary
        tail -50 "$RESULTS_DIR/build_$nightly.log" > "$RESULTS_DIR/errors_$nightly.txt"
    fi
    
    echo ""
    sleep 2  # Brief pause between tests
done

# Generate summary report
log "========================================"
log "Test Summary"
log "========================================"

{
    echo "=== Nightly Version Test Report ==="
    echo "Generated: $(date -Iseconds)"
    echo "Total versions tested: ${#NIGHTLIES[@]}"
    echo "Successful builds: ${#SUCCESSFUL_NIGHTLIES[@]}"
    echo ""
    
    if [ ${#SUCCESSFUL_NIGHTLIES[@]} -gt 0 ]; then
        echo "✓ SUCCESSFUL NIGHTLIES:"
        for nightly in "${SUCCESSFUL_NIGHTLIES[@]}"; do
            echo "  - nightly-$nightly"
        done
        echo ""
        echo "To use the first successful nightly:"
        echo "  rustup override set nightly-${SUCCESSFUL_NIGHTLIES[0]}"
    else
        echo "✗ NO SUCCESSFUL BUILDS FOUND"
        echo ""
        echo "Common failure patterns:"
        grep -h "error\[E" "$RESULTS_DIR"/errors_*.txt 2>/dev/null | sort | uniq -c | sort -rn | head -10
    fi
    echo ""
    
    echo "=== Results by Version ==="
    for nightly in "${NIGHTLIES[@]}"; do
        result=$(cat "$RESULTS_DIR/result_$nightly.txt" 2>/dev/null || echo "UNKNOWN")
        printf "%-20s %s\n" "nightly-$nightly" "$result"
    done
    
} | tee "$RESULTS_DIR/SUMMARY.txt"

echo ""
log "Detailed results saved to: $RESULTS_DIR"
log "View summary: cat $RESULTS_DIR/SUMMARY.txt"

if [ ${#SUCCESSFUL_NIGHTLIES[@]} -gt 0 ]; then
    success "Found working nightly version(s)!"
    exit 0
else
    error "No working nightly versions found"
    exit 1
fi