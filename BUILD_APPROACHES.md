# Build Approaches Comparison

This document compares different approaches for building depict in GitHub Actions.

## Overview

| Approach | Build Time | Setup Time | Maintenance | Caching |
|----------|-----------|------------|-------------|---------|
| **From Scratch** | 15-20 min | 0 min | None | Partial |
| **Pre-built Container (GHCR)** | 8-10 min | 10 min once | Low | Full |
| **Docker Hub** | 8-10 min | Manual | Medium | Full |
| **Self-hosted Runner** | 5-8 min | Hours | High | Full |

## Approach 1: From Scratch (Current)

**Files:** `build-release.yml`, `create-release.yml`

### How It Works
```yaml
runs-on: ubuntu-22.04

steps:
  - Install system packages (3 min)
  - Install Rust nightly (2 min)
  - Install WASM target (1 min)
  - Install trunk/wasm-bindgen (3 min)
  - Build code (10-12 min)
```

### Pros
✅ No Docker image to maintain  
✅ Always fresh dependencies  
✅ Works immediately after push  
✅ Transparent (all steps visible)  
✅ GitHub Actions cache helps

### Cons
❌ 15-20 minutes per build  
❌ Reinstalls tools every time  
❌ Downloads Rust every time  
❌ Higher GitHub Actions minutes usage

### Best For
- Occasional builds
- Testing different configurations
- When you want full transparency
- When you don't want to maintain images

### Current Usage
- 15-20 min × ~100 builds/month = **1,500-2,000 minutes/month**
- GitHub Free tier: 2,000 minutes/month
- **At capacity**

## Approach 2: Pre-built Container (GHCR) - RECOMMENDED

**Files:** `build-docker-image.yml`, `fast-build.yml`

### How It Works
```yaml
# Step 1: Build image once (run manually)
- Build Dockerfile.working
- Push to ghcr.io/jsavage/depict/builder

# Step 2: Use in builds
runs-on: ubuntu-latest
container:
  image: ghcr.io/jsavage/depict/builder:latest

steps:
  - Checkout code
  - cargo build (8-10 min)
```

### Setup (One Time)

```bash
# 1. Add the workflow files
git add .github/workflows/build-docker-image.yml
git add .github/workflows/fast-build.yml
git commit -m "Add fast build using pre-built container"
git push

# 2. Run "Build and Push Docker Image" workflow manually
# This builds the image once (~10 minutes)

# 3. All future builds use fast-build.yml automatically
```

### Pros
✅ **8-10 minutes** per build (50% faster)  
✅ Free hosting (GitHub Container Registry)  
✅ Automatic updates when Dockerfile changes  
✅ Better caching (entire environment pre-built)  
✅ Reduces Actions minutes by ~50%  
✅ No external accounts needed

### Cons
⚠️ One-time 10 min setup  
⚠️ Need to rebuild image if dependencies change  
⚠️ 500 MB storage used (free tier: 500MB)

### Best For
- **Frequent builds** (your use case)
- Consistent environment
- Reducing Actions minutes
- Production workflows

### Monthly Savings
- 8-10 min × 100 builds = **800-1,000 minutes/month**
- Saves: 50% of Actions minutes
- **Well under free tier limit**

## Approach 3: Docker Hub

**Similar to GHCR but uses Docker Hub**

### Setup
```bash
# Push your existing container
docker commit f28ec3c2c63b jsavage/depict-builder:latest
docker login
docker push jsavage/depict-builder:latest
```

### Workflow
```yaml
container:
  image: docker.io/jsavage/depict-builder:latest
```

### Pros
✅ Uses your exact working container  
✅ No rebuild needed initially  
✅ Public or private images

### Cons
❌ Requires Docker Hub account  
❌ Manual push process  
❌ Rate limits on free tier  
❌ Pull limits (200/6hrs anonymous)

### Best For
- Quick testing
- Sharing with others
- When GHCR isn't available

## Approach 4: Self-hosted Runner

**Advanced - Not Recommended Initially**

### How It Works
- Set up your dev server as GitHub Actions runner
- Builds run directly on your machine
- Fastest but requires maintenance

### Pros
✅ Fastest (5-8 min)  
✅ No Actions minutes used  
✅ Uses your exact environment

### Cons
❌ Server must be always on  
❌ Security considerations  
❌ Network requirements  
❌ Complex setup  
❌ Maintenance overhead

### Best For
- High-volume builds (>500/month)
- Enterprise use
- When you have dedicated hardware

## Recommended Strategy

### Phase 1: Current Setup (Now)
Use `build-release.yml` for occasional manual builds.

**When to use:**
- Testing code changes
- Creating releases
- Quarterly builds

### Phase 2: Add Fast Builds (Recommended)
Implement GHCR approach for regular builds.

```bash
# 1. Add workflow files (see artifacts above)
git add .github/workflows/build-docker-image.yml
git add .github/workflows/fast-build.yml

# 2. Run docker image build once
# Go to Actions → "Build and Push Docker Image" → Run workflow

# 3. Enable automatic builds
# Every push to main triggers fast-build.yml
```

**When to use:**
- Every code change
- CI/CD pipeline
- Automated testing

### Phase 3: Hybrid Approach (Best)
Keep both workflows:

- `fast-build.yml` - Automatic on every push (8-10 min)
- `build-release.yml` - Manual for releases (15-20 min, more thorough)
- `create-release.yml` - Manual for GitHub releases

## Comparison Example

### Building After Code Change

**Approach 1 (From Scratch):**
```
1. Push code
2. Wait 15-20 minutes
3. Download artifacts
Total: 15-20 minutes
```

**Approach 2 (Pre-built Container):**
```
1. Push code
2. Wait 8-10 minutes (automatic)
3. Download artifacts
Total: 8-10 minutes
```

**Approach 3 (Docker Hub - Manual):**
```
1. Push code
2. Trigger workflow manually
3. Wait 8-10 minutes
4. Download artifacts
Total: 8-10 minutes + manual trigger
```

## Cost Analysis (GitHub Free Tier)

### Approach 1 (Current)
- Minutes: 2,000/month (included)
- Storage: 500 MB (included)
- Usage: 1,500-2,000 min/month
- **Status: At capacity** ⚠️

### Approach 2 (GHCR)
- Minutes: 2,000/month (included)
- Storage: 500 MB (included)
- Usage: 800-1,000 min/month
- Image: ~500 MB
- **Status: 50% capacity** ✅

### Approach 3 (Docker Hub)
- Actions minutes: 800-1,000/month
- Docker Hub: Free (up to rate limits)
- **Status: 50% capacity** ✅

## Implementation Steps for GHCR (Recommended)

### 1. Create Workflow Files

Save these on your host:

```bash
cd ~/jdcs/claude2/depict

# Create docker image build workflow
cat > .github/workflows/build-docker-image.yml << 'EOF'
[Content from build-docker-image-workflow artifact]
EOF

# Create fast build workflow  
cat > .github/workflows/fast-build.yml << 'EOF'
[Content from fast-build-workflow artifact]
EOF
```

### 2. Commit and Push

```bash
git add .github/workflows/build-docker-image.yml
git add .github/workflows/fast-build.yml
git commit -m "Add fast build workflow using GHCR"
git push origin main
```

### 3. Build Docker Image Once

1. Go to: https://github.com/jsavage/depict/actions
2. Click "Build and Push Docker Image"
3. Click "Run workflow"
4. Wait ~10 minutes

Image will be pushed to: `ghcr.io/jsavage/depict/builder:latest`

### 4. Automatic Builds

Now every push triggers `fast-build.yml` automatically!

## Monitoring

### Check Actions Usage
1. Go to: Settings → Billing → Plans and usage
2. View: Actions minutes used
3. Monitor: Storage used

### Check Container Registry
1. Go to: Profile → Packages
2. View: Your containers
3. Monitor: Storage used

## Troubleshooting

### Image Pull Fails
```yaml
# Add registry login
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Cache Miss
```yaml
# Ensure cache key matches
cache:
  path: target
  key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
```

### Build Slower Than Expected
- Check: Are caches being used?
- Check: Is image being pulled or built?
- Check: Network connectivity

## Summary Recommendation

**For your use case (frequent builds, GitHub Free tier):**

✅ **Implement Approach 2 (GHCR)** 
- Add two workflow files
- Run image build once (10 min setup)
- Get 50% faster builds forever
- Stay well under Actions limits

This gives you:
- 8-10 minute builds (vs 15-20)
- Automatic on every push
- ~50% savings in Actions minutes
- Free container hosting
- Better than current setup

**Next Steps:**
1. Copy the two artifact files above
2. Commit and push
3. Run "Build and Push Docker Image" workflow once
4. Enjoy faster builds! 🚀
