# Build with Docker Image Workflow

This document explains the `build-with-docker-image.yml` workflow.

## Overview

This workflow builds depict using your verified working Docker image from the successful November 24, 2025 build.

**Docker Image:** `ghcr.io/jsavage/depict-builder:ubuntu22.04-nightly-2024-05-01`

## Key Features

### ✅ Clear Traceability
- All artifacts prefixed with `docker-image-build-`
- Build directory named with timestamp, build ID, and commit hash
- Comprehensive manifest file with all build details
- No conflicts with other workflows (manual trigger only)

### ✅ Fast Builds
- ~10-12 minutes (vs 15-20 from scratch)
- All dependencies pre-installed in container
- Only compiles code, no setup time

### ✅ Reliable
- Uses exact same environment as your successful build
- Proven configuration from November 24, 2025
- Ubuntu 22.04 + nightly-2024-05-01

## How to Use

### Running the Workflow

1. Go to: https://github.com/jsavage/depict/actions
2. Click: "Build with Docker Image"
3. Click: "Run workflow" button
4. (Optional) Enter a Build ID for identification
5. Click green "Run workflow" button
6. Wait: ~10-12 minutes

### Downloading Artifacts

After the workflow completes:

1. Scroll to bottom of workflow run page
2. Find "Artifacts" section
3. Download any of:
   - `docker-image-build-complete-*` - Everything (recommended)
   - `docker-image-build-desktop-*` - Just desktop binary
   - `docker-image-build-server-*` - Just server binary
   - `docker-image-build-web-*` - Just web assets
   - `docker-image-build-logs-*` - Build logs (for debugging)

### Using the Build

```bash
# Extract the complete build
tar -xzf docker-image-build-*.tar.gz
cd docker-image-build-*

# Run the server
./run_server.sh

# Or manually
WEBROOT=./dist PORT=8000 ./dist/depict-server
```

Access at: http://localhost:8000

## Build Output Structure

```
docker-image-build-YYYYMMDD-HHMMSS-buildid-commithash/
├── dist/
│   ├── depict-desktop          # Desktop binary
│   ├── depict-server           # Server binary
│   ├── depict-web-*.js         # JavaScript
│   ├── depict-web-*_bg.wasm    # WebAssembly
│   ├── index.html              # Web entry point
│   └── snippets/               # Additional assets
├── logs/
│   ├── desktop-build.log       # Desktop build log
│   ├── server-build.log        # Server build log
│   ├── web-build.log           # WASM build log
│   └── trunk-build.log         # Web assets build log
├── MANIFEST.txt                # Build information
├── README.txt                  # Quick start guide
└── run_server.sh               # Convenience script
```

## Traceability

Every build is uniquely identified:

### Build Directory Name Format
```
docker-image-build-YYYYMMDD-HHMMSS-buildid-commithash
                   |        |      |       |
                   |        |      |       └─ Git commit (first 7 chars)
                   |        |      └─────────  Build ID (from input)
                   |        └────────────────  Time (24h format)
                   └─────────────────────────  Date
```

Example: `docker-image-build-20251126-143022-manual-a1b2c3d`

### Artifact Names
All artifacts include the full commit hash for precise traceability:
- `docker-image-build-desktop-a1b2c3d4e5f6...`
- `docker-image-build-server-a1b2c3d4e5f6...`
- `docker-image-build-web-a1b2c3d4e5f6...`
- `docker-image-build-complete-a1b2c3d4e5f6...`

### Manifest File
Each build includes `MANIFEST.txt` with:
- Build ID and date
- Git commit and branch
- Workflow run ID
- Docker image used
- Component sizes
- Rust/Cargo versions

## Comparison with Other Workflows

| Workflow | Trigger | Build Time | Docker Image | Artifacts Prefix |
|----------|---------|------------|--------------|------------------|
| `build-release.yml` | Manual | 15-20 min | None (builds from scratch) | `depict-*` |
| `build-with-docker-image.yml` | **Manual** | **10-12 min** | **ghcr.io/jsavage/depict-builder** | **docker-image-build-*** |
| `fast-build.yml` | Auto (push) | 8-10 min | ghcr.io (if exists) | `depict-fast-*` |
| `create-release.yml` | Manual | 15-20 min | None | GitHub Release |

## Why This Workflow?

### Advantages
- ✅ Uses your proven successful build environment
- ✅ Faster than from-scratch builds
- ✅ Clear traceability (unique prefixes)
- ✅ No conflicts with other workflows
- ✅ Comprehensive build information
- ✅ Complete test suite included

### When to Use
- When you need a reliable build quickly
- When testing code changes
- When you want full traceability
- When other workflows have issues

### When NOT to Use
- For automatic CI on every push (use `fast-build.yml`)
- For creating GitHub Releases (use `create-release.yml`)
- For testing different Rust versions (use `build-release.yml`)

## Code Fixes Applied

The workflow automatically applies these fixes:

1. **Server Label Pattern**
   ```rust
   // From:
   Label{text, hpos, width, vpos}
   // To:
   Label{text, hpos, width, vpos, ..}
   ```

2. **Factorial Dependency**
   ```toml
   # From:
   factorial = "^0.3"
   # To:
   factorial = "0.4"
   ```

3. **Server Binding Address**
   ```rust
   // From:
   SocketAddr::from([127, 0, 0, 1], 8000)
   // To:
   SocketAddr::from([0, 0, 0, 0], 8000)
   ```

These fixes are required for successful compilation and proper operation.

## Docker Image Details

**Image:** `ghcr.io/jsavage/depict-builder:ubuntu22.04-nightly-2024-05-01`

**Contains:**
- Ubuntu 22.04
- Rust nightly-2024-05-01
- WASM target (wasm32-unknown-unknown)
- System dependencies:
  - build-essential
  - pkg-config
  - cmake
  - libssl-dev
  - libwebkit2gtk-4.0-dev (critical!)
  - libgtk-3-dev
  - libsoup2.4-dev
- Build tools:
  - trunk
  - wasm-bindgen-cli

**Size:** ~2.88 GB

**Created:** November 24, 2025

**Verified:** Working build successful

## Troubleshooting

### Workflow Fails to Start
**Issue:** "Could not pull image"  
**Solution:** Image must be public or workflow needs permissions

### Build Fails at Code Fixes
**Issue:** Files already modified  
**Solution:** Normal - sed commands use `|| true` to ignore errors

### No Artifacts Appear
**Issue:** Build must complete successfully  
**Solution:** Check logs artifact for error messages

### Server Won't Start Locally
**Issue:** Missing WEBROOT  
**Solution:** Use `./run_server.sh` or set `WEBROOT=./dist`

### Can't Access from Browser
**Issue:** Server binding to wrong address  
**Solution:** Should be fixed automatically (0.0.0.0), check logs

## Advanced Usage

### Custom Build ID
Use meaningful Build IDs for organization:
```
Build ID: "testing-new-parser"
Build ID: "release-candidate-1"
Build ID: "bugfix-123"
```

Result: `docker-image-build-20251126-143022-release-candidate-1-a1b2c3d`

### Comparing Builds
Download multiple complete builds and compare:
```bash
# Extract two builds
tar -xzf docker-image-build-20251126-143022-*.tar.gz
tar -xzf docker-image-build-20251126-150000-*.tar.gz

# Compare manifests
diff docker-image-build-20251126-143022-*/MANIFEST.txt \
     docker-image-build-20251126-150000-*/MANIFEST.txt

# Compare binary sizes
ls -lh docker-image-build-*/dist/depict-*
```

### Archiving Builds
Builds are retained for 90 days. To preserve important builds:

1. Download complete artifact
2. Store in safe location
3. Include manifest for traceability

## Integration with Other Tools

### CI/CD Pipeline
```yaml
# In another workflow
- uses: actions/download-artifact@v4
  with:
    name: docker-image-build-complete-${{ github.sha }}

- name: Deploy
  run: |
    tar -xzf docker-image-build-*.tar.gz
    # Deploy to server
```

### Local Testing
```bash
# Download artifact
# Extract
tar -xzf docker-image-build-*.tar.gz
cd docker-image-build-*

# Test locally
./run_server.sh

# Or test individual components
./dist/depict-desktop
```

## Maintenance

### Updating the Docker Image
If dependencies change:

1. Update `Dockerfile.working`
2. Build new image locally
3. Push to ghcr.io with new tag
4. Update workflow to use new tag

### Checking Image Status
```bash
# Pull and inspect
docker pull ghcr.io/jsavage/depict-builder:ubuntu22.04-nightly-2024-05-01
docker images | grep depict-builder

# Check what's inside
docker run -it --rm ghcr.io/jsavage/depict-builder:ubuntu22.04-nightly-2024-05-01 bash
# Inside: rustc --version, cargo --version, etc.
```

## Support

### Questions?
- Check workflow run logs
- Download logs artifact
- Review MANIFEST.txt in build
- Open issue: https://github.com/jsavage/depict/issues

### Reporting Issues
Include:
- Workflow run URL
- Build ID used
- Error messages from logs
- Expected vs actual behavior

---

**Workflow File:** `.github/workflows/build-with-docker-image.yml`  
**Docker Image:** `ghcr.io/jsavage/depict-builder:ubuntu22.04-nightly-2024-05-01`  
**Documentation:** This file (DOCKER_IMAGE_BUILD.md)  
**Last Updated:** November 26, 2025