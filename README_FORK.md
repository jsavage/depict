# Depict - Working Build Configuration

This fork contains a verified working build configuration for [mstone/depict](https://github.com/mstone/depict).

## Status: ✅ BUILDS SUCCESSFULLY

**Last verified:** November 23, 2025  
**Build environment:** Ubuntu 22.04 + Rust nightly-2024-05-01  
**All components working:** Desktop, Server, Web (WASM)

## Quick Start (Recommended)

### Option 1: Docker (Easiest)

```bash
# Build image and run
docker-compose up depict-builder

# Inside container
./deploy.sh --method local

# Server will be available at http://localhost:8000
```

### Option 2: One-Command Deploy

```bash
# Clone this fork
git clone https://github.com/jsavage/depict.git
cd depict

# Run deployment script
chmod +x deploy.sh
./deploy.sh --method docker

# Access at http://localhost:8000
```

### Option 3: Manual Build

See [COMPLETE_BUILD_GUIDE.md](./COMPLETE_BUILD_GUIDE.md) for detailed instructions.

## What's Different in This Fork?

### Code Fixes Applied

1. **server/src/main.rs** (line 70): Fixed Label pattern to include `classes` field
2. **Cargo.toml**: Updated factorial dependency from 0.3 to 0.4

### Build Configuration

- **OS:** Ubuntu 22.04 (required - 24.04 won't work due to webkit version)
- **Rust:** nightly-2024-05-01 (or any 2024-05-01 through 2024-11-01)
- **Key dependencies:** webkit2gtk-4.0, cmake

### Additional Files

- `deploy.sh` - Automated deployment script
- `docker-compose.yml` - Easy container management
- `Dockerfile.working` - Verified working Docker configuration
- `COMPLETE_BUILD_GUIDE.md` - Comprehensive build documentation
- `test_nightly_versions.sh` - Automated nightly version testing

## Why These Specific Requirements?

### Ubuntu 22.04 Required

Ubuntu 24.04 ships with `libwebkit2gtk-4.1-dev`, but depict requires `libwebkit2gtk-4.0-dev`. Ubuntu 22.04 has the correct version.

### Nightly Rust Required

The project depends on a forked version of osqp (optimization library) that requires unstable Rust features. However, only nightlies from May 2024 onwards work - earlier versions fail compilation.

### Working Nightly Versions

Systematically tested 29 nightly versions:
- ❌ 2022-07-01 through 2024-04-01: All fail
- ✅ 2024-05-01 through 2024-11-01: All work

We recommend `nightly-2024-05-01` as the earliest stable working version.

## Build Times

- Docker image: ~25 minutes
- Desktop binary: ~8 minutes
- Server binary: ~4 minutes
- Web WASM: ~3 minutes
- Web assets (trunk): ~1 minute
- **Total: ~40 minutes**

## Output

```
deployment_YYYYMMDD_HHMMSS/
├── dist/
│   ├── depict-desktop          # 32 MB native GUI
│   ├── depict-server           # 16 MB HTTP server
│   ├── depict-web-*.js         # 36 KB JavaScript
│   ├── depict-web-*_bg.wasm    # 4.7 MB WebAssembly
│   ├── index.html              # Entry point
│   └── snippets/               # Additional assets
├── logs/
│   └── build_*.log             # Build logs
├── run_server.sh               # Start script
├── MANIFEST.txt                # Build information
└── QUICKSTART.txt              # Usage instructions
```

## Running the Server

```bash
# From build directory
WEBROOT=./dist PORT=8000 ./dist/depict-server

# Or use the provided script
./run_server.sh

# Server listens on http://localhost:8000
```

## Testing

Enter this example in the web interface:

```
person microwave food: open, start, stop / beep : heat
person food: eat
```

You should see a diagram with:
- Three boxes (person, microwave, food)
- Arrows showing interactions
- Labels on the arrows

Click "Export SVG" to download the diagram.

## Components

### Desktop GUI
- Native application using Dioxus framework
- Requires WebKitGTK 4.0
- Direct SVG export

### Server
- HTTP server serving web interface
- Built with Axum framework
- Serves static files from WEBROOT

### Web Interface
- Dioxus compiled to WebAssembly
- Runs entirely in browser
- Same functionality as desktop

## Architecture

```
depict-core (library)
    ├── DSL Parser
    ├── Layout Engine (osqp for optimization)
    └── SVG Generator
         │
         ├─→ Desktop (Dioxus native)
         └─→ Web (Dioxus WASM) → Server
```

## Dependencies

### System (Ubuntu 22.04)
```bash
build-essential
pkg-config
cmake
libssl-dev
curl
git
libwebkit2gtk-4.0-dev
libgtk-3-dev
libsoup2.4-dev
```

### Rust
```bash
rustup toolchain: nightly-2024-05-01
rustup target: wasm32-unknown-unknown
cargo tools: trunk, wasm-bindgen-cli
```

## Troubleshooting

### Build fails with webkit error
→ Ensure you're on Ubuntu 22.04, not 24.04

### Build fails with "feature may not be used on stable"
→ Ensure you're using nightly-2024-05-01 or later

### Server fails with "NotPresent"
→ Set WEBROOT environment variable to dist directory

### Can't connect to server from browser
→ Check server is on port 8000, not 8080 (default changed)
→ Ensure Docker port mapping: `-p 8000:8000`

### Trunk build fails
→ Run from web/ directory, not root
→ Ensure index.html exists in web/

## Development

### Making Changes

1. Modify code
2. Run `./deploy.sh --method local`
3. Test with `./run_server.sh`

### Testing Different Nightlies

```bash
chmod +x test_nightly_versions.sh
./test_nightly_versions.sh
```

Results saved to `nightly_test_results_*/`

## Contributing Back to Upstream

If you make improvements:

1. Test thoroughly with deploy.sh
2. Document changes in commit message
3. Submit PR to https://github.com/mstone/depict

Note: The code fixes in this fork address compatibility issues that may need upstream attention.

## Resources

- **Original repository:** https://github.com/mstone/depict
- **Online demo:** https://mstone.info/depict/
- **This fork:** https://github.com/jsavage/depict
- **Issue tracker:** Use GitHub Issues

## Files in This Repository

| File | Purpose |
|------|---------|
| `deploy.sh` | One-command build and deployment |
| `docker-compose.yml` | Container orchestration |
| `Dockerfile.working` | Verified Docker configuration |
| `COMPLETE_BUILD_GUIDE.md` | Comprehensive build documentation |
| `README_FORK.md` | This file |
| `test_nightly_versions.sh` | Automated nightly testing |
| `WORKING_NIGHTLIES.txt` | List of tested working nightlies |

## License

MIT License (same as upstream)

## Acknowledgments

- **Original author:** Michael Stone (mstone)
- **Original repo:** https://github.com/mstone/depict
- **Build system:** Developed with assistance from Claude (Anthropic)

## Support

For issues specific to this fork's build configuration, open an issue at:
https://github.com/jsavage/depict/issues

For general depict questions, refer to the upstream repository.

---

**Build Status:** ✅ Working  
**Last Tested:** 2025-11-23  
**Rust Version:** nightly-2024-05-01  
**OS:** Ubuntu 22.04 (Docker)