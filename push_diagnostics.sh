#!/usr/bin/env bash
set -euo pipefail

# Push Diagnostics to GitHub
# This script creates a separate branch with diagnostic files
# so they don't trigger workflows on main branch

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[PUSH-DIAG]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Find latest diagnostics
LATEST_DIAG=$(find diagnostics -type d -name "20*" | sort | tail -1)

if [ -z "$LATEST_DIAG" ] || [ ! -d "$LATEST_DIAG" ]; then
    error "No diagnostics directory found. Run ./diagnose.sh first"
    exit 1
fi

log "Found diagnostics: $LATEST_DIAG"

# Create a unique branch name
BRANCH_NAME="diagnostics/$(basename $LATEST_DIAG)"

log "Creating branch: $BRANCH_NAME"

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository"
    exit 1
fi

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)
log "Current branch: $CURRENT_BRANCH"

# Create and switch to diagnostics branch
log "Creating diagnostics branch..."
git checkout -b "$BRANCH_NAME" 2>/dev/null || {
    warn "Branch already exists, switching to it..."
    git checkout "$BRANCH_NAME"
}

# Create a docs directory for diagnostics (GitHub treats this specially)
mkdir -p docs/diagnostics/$(basename $LATEST_DIAG)

# Copy diagnostic files
log "Copying diagnostic files..."
cp -r "$LATEST_DIAG"/* "docs/diagnostics/$(basename $LATEST_DIAG)/"

# Create a README for this diagnostic
cat > "docs/diagnostics/$(basename $LATEST_DIAG)/README.md" << EOF
# Diagnostic Report - $(basename $LATEST_DIAG)

Generated: $(date -Iseconds)

## Quick Summary

\`\`\`
$(cat "$LATEST_DIAG/00_SUMMARY.txt" 2>/dev/null || echo "Summary not available")
\`\`\`

## Files in This Diagnostic

- **00_SUMMARY.txt** - Quick overview
- **01-03_system_*.txt** - System information
- **10-15_rust_*.txt** - Rust toolchain details
- **30-34_*cargo*.txt** - Project structure and Cargo files
- **40-41_*tree*.txt** - Dependency trees
- **50-51_*features*.txt** - Feature analysis
- **90-96_git_*.txt** - Git status and history
- **120-123_cargo_check_*.txt** - Build check results

## Key Information

### Rust Version
\`\`\`
$(cat "$LATEST_DIAG/10_rustc_version.txt" 2>/dev/null || echo "Not available")
\`\`\`

### Workspace Members
\`\`\`
$(cat "$LATEST_DIAG/33_workspace_members.txt" 2>/dev/null || echo "Not available")
\`\`\`

### WASM Target
\`\`\`
$(cat "$LATEST_DIAG/13_installed_targets.txt" 2>/dev/null | grep wasm || echo "WASM target status unknown")
\`\`\`

## How to Use This Data

Download the files and review them to understand the build environment state at this point in time.

To share with Claude or other developers, download the entire directory or specific files.
EOF

# Add files to git
log "Adding files to git..."
git add docs/diagnostics/

# Commit
log "Committing diagnostics..."
git commit -m "Add diagnostics from $(basename $LATEST_DIAG)" || {
    warn "Nothing to commit (files may already be committed)"
}

# Push to remote
log "Pushing to GitHub..."
echo ""
log "About to push branch: $BRANCH_NAME"
log "This branch will NOT trigger workflows on main"
echo ""

read -p "Continue with push? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push -u origin "$BRANCH_NAME"
    log "Successfully pushed diagnostics!"
    echo ""
    log "View on GitHub:"
    REPO_URL=$(git config --get remote.origin.url | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
    echo "  $REPO_URL/tree/$BRANCH_NAME/docs/diagnostics/$(basename $LATEST_DIAG)"
    echo ""
else
    warn "Push cancelled"
fi

# Return to original branch
log "Returning to branch: $CURRENT_BRANCH"
git checkout "$CURRENT_BRANCH"

echo ""
log "=== Summary ==="
log "Diagnostics branch: $BRANCH_NAME"
log "Current branch: $CURRENT_BRANCH"
echo ""
log "To view diagnostics on GitHub:"
echo "  1. Go to your repository"
echo "  2. Switch to branch: $BRANCH_NAME"
echo "  3. Navigate to: docs/diagnostics/$(basename $LATEST_DIAG)/"
echo ""
log "To share a link to diagnostics, copy the URL shown above"
