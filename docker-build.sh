#!/usr/bin/env bash
# Build depict using Docker - ensures reproducible builds

set -euo pipefail

echo "=== Docker Build Script for Depict ==="
echo ""

# Configuration
IMAGE_NAME="depict-builder"
IMAGE_TAG="ubuntu22.04-nightly-2024-11-01"
CONTAINER_NAME="depict-build-$$"
LOG_FILE="build-$(date +%Y%m%d_%H%M%S).log"

# Parse arguments
BUILD_DOCKER_IMAGE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-image)
            BUILD_DOCKER_IMAGE=true
            shift
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--build-image] [--image-name NAME] [--image-tag TAG]"
            exit 1
            ;;
    esac
done

FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Build Docker image if requested
if [ "$BUILD_DOCKER_IMAGE" = true ]; then
    echo "Building Docker image: $FULL_IMAGE"
    docker build -t "$FULL_IMAGE" .
    echo "✓ Docker image built"
    echo ""
fi

# Check if image exists
if ! docker image inspect "$FULL_IMAGE" > /dev/null 2>&1; then
    echo "Error: Docker image $FULL_IMAGE not found"
    echo "Run with --build-image to build it first"
    exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Using image: $FULL_IMAGE"
echo "Project directory: $SCRIPT_DIR"
echo "Log file: $LOG_FILE"
echo ""

# Run the build inside Docker
echo "Starting Docker build container..."
echo "Full output will be logged to: $LOG_FILE"
echo ""

docker run --rm \
    -v "$SCRIPT_DIR:/workspace" \
    --name "$CONTAINER_NAME" \
    "$FULL_IMAGE" \
    bash -c '
        set -euo pipefail
        cd /workspace
        
        echo "=== Inside Docker Container ==="
        echo "Rust version: $(rustc --version)"
        echo "Cargo version: $(cargo --version)"
        echo "Trunk version: $(trunk --version)"
        echo "Build started: $(date)"
        echo ""
        
        # Make build script executable and run it
        chmod +x build.sh
        ./build.sh
        
        echo ""
        echo "Build completed: $(date)"
        echo "Build artifacts are in the workspace directory"
    ' 2>&1 | tee "$LOG_FILE"

BUILD_STATUS=${PIPESTATUS[0]}

echo ""
echo "================================================================"
if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ Docker build complete"
    echo "================================================================"
    echo ""
    echo "Build artifacts are in: $SCRIPT_DIR/build_*"
    echo "Build log saved to: $LOG_FILE"
    echo ""
    echo "To run the server:"
    echo "  cd $SCRIPT_DIR/build_*"
    echo "  ./run-server.sh"
else
    echo "❌ Docker build failed (exit code: $BUILD_STATUS)"
    echo "================================================================"
    echo ""
    echo "Check the log file for details: $LOG_FILE"
    echo ""
    echo "Last 50 lines of build output:"
    tail -50 "$LOG_FILE"
fi
echo ""