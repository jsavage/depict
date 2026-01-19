#!/usr/bin/env bash
set -e

IMAGE_NAME="depict-builder"
IMAGE_TAG="ubuntu22.04-nightly-2024-11-01"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/pubspec.yaml" ]]; then
  PROJECT_DIR="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/depict_flutter/pubspec.yaml" ]]; then
  PROJECT_DIR="$SCRIPT_DIR/depict_flutter"
else
  echo "Error: Could not find pubspec.yaml"
  exit 1
fi

HOST_UID=$(id -u)
HOST_GID=$(id -g)
# was --rm -it
docker run --rm -it \
  -e HOME=/tmp \
  -e GIT_CONFIG_GLOBAL=/tmp/gitconfig \
  -v "$SCRIPT_DIR:/workspace" \
  -v "$HOME/.pub-cache:/tmp/.pub-cache" \
  -v "$HOME/.flutter-cache:/tmp/.flutter-cache" \
  -w "/workspace/$(basename "$PROJECT_DIR")" \
  "$FULL_IMAGE" \
  bash -c "git config --global --add safe.directory /opt/flutter && flutter $*"
