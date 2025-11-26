# GitHub Actions Workflows

This directory contains automated workflows for building and releasing depict.

## Available Workflows

### 1. Build Release (`build-release.yml`)

**Purpose:** Build all depict components and save as artifacts

**Trigger:** Manual (workflow_dispatch)

**What it does:**
- Builds desktop GUI
- Builds server
- Builds web interface (WASM)
- Creates organized release package
- Uploads artifacts (retained for 90 days)
- Runs basic tests

**How to run:**

1. Go to: https://github.com/YOUR_USERNAME/depict/actions
2. Click "Build Depict Release" workflow
3. Click "Run workflow"
4. (Optional) Select Rust nightly version
5. Click green "Run workflow" button

**Artifacts produced:**
- `depict-desktop-*` - Desktop binary
- `depict-server-*` - Server binary
- `depict-web-*` - Web assets
- `depict-complete-release-*` - Everything packaged together

**Build time:** ~15-20 minutes

### 2. Create Release (`create-release.yml`)

**Purpose:** Build and create a GitHub Release with downloadable packages

**Trigger:** Manual (workflow_dispatch)

**What it does:**
- Builds all components
- Creates release tarballs
- Generates checksums
- Creates GitHub Release with:
  - Complete package (server + web)
  - Desktop-only package
  - SHA256 checksums
  - Release notes

**How to run:**

1. Go to: https://github.com/YOUR_USERNAME/depict/actions
2. Click "Create Release" workflow
3. Click "Run workflow"
4. Fill in:
   - **Tag name:** e.g., `v0.3.1-working`
   - **Release name:** e.g., "Working Build v0.3.1"
   - **Pre-release:** Check if this is a pre-release
5. Click green "Run workflow" button

**Creates:**
- GitHub Release at: `/releases/tag/TAG_NAME`
- Downloadable tarballs
- Checksums file
- Formatted release notes

**Build time:** ~15-20 minutes

## Build Configuration

All workflows use:
- **OS:** Ubuntu 22.04 (required for webkit2gtk-4.0)
- **Rust:** nightly-2024-05-01 (default, configurable)
- **WASM target:** wasm32-unknown-unknown
- **Build tools:** trunk, wasm-bindgen-cli

## Code Fixes Applied

All workflows automatically apply these fixes:
1. Server Label pattern: Add `..` for missing `classes` field
2. Cargo.toml: Update factorial 0.3 → 0.4
3. Server binding: Change 127.0.0.1 → 0.0.0.0

## Caching

Workflows use GitHub Actions cache for:
- Cargo registry (~500 MB)
- Cargo git dependencies (~100 MB)
- Build artifacts (~2 GB)

This speeds up subsequent builds from ~20 minutes to ~10 minutes.

## Artifact Retention

- Build artifacts: 90 days
- GitHub Releases: Permanent (until manually deleted)

## Download Artifacts

### From Workflow Run:

1. Go to workflow run
2. Scroll to "Artifacts" section at bottom
3. Click to download ZIP files

### From Release:

1. Go to: https://github.com/YOUR_USERNAME/depict/releases
2. Find the release
3. Download `.tar.gz` files from "Assets"

## Testing

The build workflow includes basic tests:
- Server starts successfully
- Server responds on port 8000
- Web interface HTML loads
- WASM module is present

## Troubleshooting

### Workflow fails at "Install system dependencies"

→ Check that Ubuntu version is 22.04, not 24.04

### Workflow fails at "Build desktop"

→ webkit2gtk-4.0-dev not available (wrong Ubuntu version)

### Workflow fails at "Build web WASM"

→ Check nightly version is 2024-05-01 or later

### Artifacts not appearing

→ Build must complete successfully for artifacts to be uploaded

### Can't create release

→ Check repository has "Write" permissions for workflows
→ Check tag name doesn't already exist

## Local Testing

To test the workflow locally:

```bash
# Install act (GitHub Actions local runner)
# https://github.com/nektos/act

# Run build workflow
act workflow_dispatch -W .github/workflows/build-release.yml

# Note: May not work perfectly due to Docker-in-Docker issues
# Better to test actual deployment script:
./deploy.sh --method docker
```

## Customization

### Change Rust Version

Edit workflow files, change:
```yaml
toolchain: nightly-2024-05-01
```

### Add More Tests

Add steps to the `test` job in `build-release.yml`

### Change Artifact Retention

Edit workflow files, change:
```yaml
retention-days: 90
```

### Add More Build Variants

Add matrix builds for different configurations:
```yaml
strategy:
  matrix:
    nightly: [nightly-2024-05-01, nightly-2024-08-01]
```

## Security Notes

- Workflows run with `GITHUB_TOKEN` (automatic)
- No secrets required for basic builds
- Releases require `contents: write` permission
- Code fixes are visible in workflow logs

## Maintenance

### Update Working Nightlies

When new nightlies are confirmed working:

1. Update `WORKING_NIGHTLIES.txt`
2. Add to workflow input options
3. Test with build workflow

### Monitor Workflow Usage

- Check: Repository Settings → Actions → Usage
- GitHub Free: 2000 minutes/month
- Each build: ~20 minutes = ~100 builds/month

## Quick Reference

| Task | Workflow | Time | Output |
|------|----------|------|--------|
| Test build | build-release.yml | 15-20 min | Artifacts |
| Create release | create-release.yml | 15-20 min | GitHub Release |
| Local test | deploy.sh | 40 min | Local files |

## Example Usage

### Scenario 1: Test a Code Change

1. Push changes to repository
2. Run "Build Depict Release" workflow
3. Download artifacts
4. Test locally

### Scenario 2: Create Official Release

1. Verify build works with workflow
2. Run "Create Release" workflow
3. Tag: `v0.3.1-working`
4. Release name: "Working Build v0.3.1"
5. Release appears under /releases

### Scenario 3: Test Different Nightly

1. Run "Build Depict Release" workflow
2. Select different nightly from dropdown
3. Check if build succeeds
4. Update WORKING_NIGHTLIES.txt if successful

---

**Questions?** Open an issue at: https://github.com/jsavage/depict/issues
