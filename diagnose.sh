#!/usr/bin/env bash
set -euo pipefail

# depict Diagnostic Script
# Captures complete project state for debugging and analysis
# Usage: ./diagnose.sh

DIAG_DIR="diagnostics/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DIAG_DIR"

echo "=== Depict Project Diagnostics ==="
echo "Diagnostic output will be saved to: $DIAG_DIR"
echo ""

# Function to run command and save output
run_diag() {
    local name=$1
    local cmd=$2
    echo "Running: $name"
    {
        echo "=== $name ==="
        echo "Command: $cmd"
        echo "Timestamp: $(date -Iseconds)"
        echo ""
        eval "$cmd" 2>&1 || echo "Exit code: $?"
        echo ""
    } > "$DIAG_DIR/$name.txt"
}

# System Information
echo "Collecting system information..."
run_diag "01_system_info" "uname -a"
run_diag "02_os_release" "cat /etc/os-release"
run_diag "03_kernel" "uname -r"

# Rust Toolchain
echo "Collecting Rust toolchain information..."
run_diag "10_rustc_version" "rustc --version --verbose"
run_diag "11_cargo_version" "cargo --version"
run_diag "12_rustup_show" "rustup show"
run_diag "13_installed_targets" "rustup target list --installed"
run_diag "14_installed_components" "rustup component list --installed"
run_diag "15_rust_toolchains" "rustup toolchain list"

# Check for Nix
echo "Checking Nix installation..."
if command -v nix &> /dev/null; then
    run_diag "20_nix_version" "nix --version"
    run_diag "21_nix_info" "nix-shell --version"
    run_diag "22_nix_flake_info" "nix flake metadata --no-write-lock-file 2>&1 || echo 'Not a flake or flakes not enabled'"
else
    echo "Nix not installed" > "$DIAG_DIR/20_nix_version.txt"
fi

# Project Structure
echo "Analyzing project structure..."
run_diag "30_directory_tree" "find . -type f -name '*.toml' -o -name '*.nix' -o -name '*.rs' -o -name '*.html' | head -100"
run_diag "31_workspace_cargo_toml" "cat Cargo.toml"

# Find all Cargo.toml files
find . -name "Cargo.toml" -type f > "$DIAG_DIR/32_all_cargo_tomls.txt"

# Workspace Members
echo "Analyzing workspace members..."
if grep -q "\[workspace\]" Cargo.toml 2>/dev/null; then
    run_diag "33_workspace_members" "grep -A 20 '\[workspace\]' Cargo.toml"
fi

# Individual package Cargo.toml files
for pkg in depict-web depict-desktop depict-server depict-core depict; do
    if [ -f "$pkg/Cargo.toml" ]; then
        run_diag "34_${pkg}_cargo" "cat $pkg/Cargo.toml"
    elif [ -f "crates/$pkg/Cargo.toml" ]; then
        run_diag "34_${pkg}_cargo" "cat crates/$pkg/Cargo.toml"
    fi
done

# Dependency Trees
echo "Generating dependency trees..."
run_diag "40_full_dependency_tree" "cargo tree --all-features 2>&1 | head -500"

for pkg in depict-web depict-desktop depict-server depict-core; do
    if cargo metadata --no-deps 2>/dev/null | grep -q "\"name\":\"$pkg\""; then
        run_diag "41_${pkg}_tree" "cargo tree -p $pkg --all-features 2>&1 | head -200"
    fi
done

# Features Analysis
echo "Analyzing features..."
run_diag "50_metadata" "cargo metadata --format-version 1 --no-deps 2>&1"
run_diag "51_features_extract" "cargo metadata --format-version 1 --no-deps 2>&1 | grep -A 5 '\"features\"' || echo 'No features found'"

# Build Scripts
echo "Finding build scripts..."
run_diag "60_build_scripts" "find . -name 'build.rs' -type f"
for build_rs in $(find . -name "build.rs" -type f); do
    filename=$(echo "$build_rs" | sed 's/[^a-zA-Z0-9]/_/g')
    run_diag "61_build_script_${filename}" "cat $build_rs"
done

# Web-specific files
echo "Checking web-specific configuration..."
run_diag "70_trunk_toml" "cat Trunk.toml 2>&1 || echo 'Trunk.toml not found'"
run_diag "71_index_html" "find . -name 'index.html' -type f"
for html in $(find . -name "index.html" -type f | head -3); do
    filename=$(echo "$html" | sed 's/[^a-zA-Z0-9]/_/g')
    run_diag "72_html_${filename}" "cat $html"
done

# Nix Configuration
echo "Analyzing Nix configuration..."
run_diag "80_flake_nix" "cat flake.nix 2>&1 || echo 'flake.nix not found'"
run_diag "81_flake_lock" "cat flake.lock 2>&1 || echo 'flake.lock not found'"
run_diag "82_shell_nix" "cat shell.nix 2>&1 || echo 'shell.nix not found'"
run_diag "83_default_nix" "cat default.nix 2>&1 || echo 'default.nix not found'"

# Git Information
echo "Collecting Git information..."
run_diag "90_git_status" "git status"
run_diag "91_git_log" "git log --oneline --graph --all -20"
run_diag "92_git_remote" "git remote -v"
run_diag "93_git_branch" "git branch -a"
run_diag "94_git_tags" "git tag -l"
run_diag "95_current_commit" "git rev-parse HEAD && git log -1 --pretty=fuller"
run_diag "96_upstream_commits" "git log --oneline origin/main ^HEAD 2>&1 | head -20 || echo 'Cannot compare with upstream'"

# Check installed build tools
echo "Checking installed build tools..."
for tool in trunk wasm-pack wasm-bindgen cargo-udeps cargo-bloat cargo-watch; do
    tool_name=$(echo "$tool" | sed 's/-/_/g')
    if command -v "$tool" &> /dev/null; then
        run_diag "100_${tool_name}_version" "$tool --version"
    else
        echo "$tool not installed" > "$DIAG_DIR/100_${tool_name}_version.txt"
    fi
done

# Check for WASM target
echo "Checking WASM toolchain..."
run_diag "110_wasm_target_check" "rustup target list | grep wasm"
run_diag "111_wasm_bindgen_path" "which wasm-bindgen 2>&1 || echo 'wasm-bindgen not found'"

# Try basic cargo check operations
echo "Running cargo checks..."
run_diag "120_cargo_check" "cargo check --workspace 2>&1 | head -200"
run_diag "121_cargo_metadata_check" "cargo metadata --format-version 1 2>&1"

# Check for each package individually
for pkg in depict-web depict-desktop depict-server depict-core; do
    if cargo metadata --no-deps 2>/dev/null | grep -q "\"name\":\"$pkg\""; then
        run_diag "122_cargo_check_${pkg}" "cargo check -p $pkg 2>&1 | head -100"
    fi
done

# Try WASM-specific check
if rustup target list --installed | grep -q "wasm32-unknown-unknown"; then
    run_diag "123_cargo_check_wasm" "cargo check -p depict-web --target wasm32-unknown-unknown 2>&1 | head -200 || echo 'depict-web package not found or check failed'"
fi

# Cargo outdated check
if command -v cargo-outdated &> /dev/null; then
    run_diag "130_cargo_outdated" "cargo outdated"
fi

# Environment variables
echo "Capturing environment..."
run_diag "140_env_vars" "env | sort | grep -E '(RUST|CARGO|NIX|PATH)'"

# Disk space
echo "Checking disk space..."
run_diag "150_disk_space" "df -h ."

# Generate summary
echo "Generating summary..."
{
    echo "=== Depict Diagnostics Summary ==="
    echo "Generated: $(date -Iseconds)"
    echo "Directory: $DIAG_DIR"
    echo ""
    echo "## Quick Status"
    echo ""
    
    echo "Rust: $(rustc --version 2>&1 || echo 'NOT INSTALLED')"
    echo "Cargo: $(cargo --version 2>&1 || echo 'NOT INSTALLED')"
    echo "Nix: $(nix --version 2>&1 || echo 'NOT INSTALLED')"
    echo "Trunk: $(trunk --version 2>&1 || echo 'NOT INSTALLED')"
    echo ""
    
    echo "WASM Target: $(rustup target list --installed 2>&1 | grep wasm || echo 'NOT INSTALLED')"
    echo ""
    
    echo "## Workspace Packages"
    cargo metadata --no-deps 2>/dev/null | grep '"name":' | head -10 || echo "Could not determine packages"
    echo ""
    
    echo "## Git Status"
    echo "Current branch: $(git branch --show-current 2>&1 || echo 'unknown')"
    echo "Current commit: $(git rev-parse --short HEAD 2>&1 || echo 'unknown')"
    echo "Uncommitted changes: $(git status --porcelain | wc -l) files"
    echo ""
    
    echo "## Files Generated"
    ls -1 "$DIAG_DIR" | wc -l
    echo "diagnostic files created"
    echo ""
    
    echo "## Key Files"
    ls -1 "$DIAG_DIR"/*.txt | tail -10
    
} > "$DIAG_DIR/00_SUMMARY.txt"

# Create a compressed archive
echo ""
echo "Creating compressed archive..."
tar -czf "diagnostics/diagnostics_$(date +%Y%m%d_%H%M%S).tar.gz" -C "diagnostics" "$(basename "$DIAG_DIR")"

echo ""
echo "=== Diagnostics Complete ==="
echo "Results saved to: $DIAG_DIR"
echo "Summary: $DIAG_DIR/00_SUMMARY.txt"
echo "Archive: diagnostics/diagnostics_$(date +%Y%m%d_%H%M%S).tar.gz"
echo ""
echo "To view summary: cat $DIAG_DIR/00_SUMMARY.txt"
echo "To share: upload the .tar.gz file or individual .txt files from $DIAG_DIR"
