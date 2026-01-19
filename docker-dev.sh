#!/usr/bin/env bash
set -e

IMAGE_NAME="depict-builder"
IMAGE_TAG="ubuntu22.04-nightly-2024-11-01"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

REPO_DIR="$(pwd)"

docker run --rm -it \
    -v "$REPO_DIR:/workspace" \
    -v "$HOME/.pub-cache:/root/.pub-cache" \
    -v "$HOME/.flutter-cache:/root/.flutter-cache" \
    -w /workspace \
    "$FULL_IMAGE" \
    bash
