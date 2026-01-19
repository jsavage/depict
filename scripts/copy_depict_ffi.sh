#!/usr/bin/env bash
set -euo pipefail

echo "[copy_depict_ffi] Starting"
sudo chown -R jsavage:jsavage \
  /home/jsavage/jdcs/claude2/depict/depict_flutter/build
echo "[copy_depict_ffi] chown completed"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/depict_flutter"

RUST_LIB="$ROOT_DIR/ffi/target/debug/libdepict_ffi.so"
FLUTTER_BUNDLE="$FLUTTER_DIR/build/linux/x64/release/bundle/lib"

RUST_ARTIFACT_DIR="$ROOT_DIR/target/release"
RUST_LIB="$RUST_ARTIFACT_DIR/libdepict_ffi.so"

echo "[copy_depict_ffi] Project root:"
echo "  $ROOT_DIR"

echo "[copy_depict_ffi] Flutter project:"
echo "  $FLUTTER_DIR"

echo "[copy_depict_ffi] Expected Rust library path:"
echo "  $RUST_LIB"

echo "[copy_depict_ffi] Expected Flutter bundle directory:"
echo "  $FLUTTER_BUNDLE"

# --- Sanity checks ---

if [ ! -f "$RUST_LIB" ]; then
  echo
  echo "[copy_depict_ffi] ERROR: Rust library not found"
  echo "[copy_depict_ffi] This usually means depict_ffi has not been built"
  echo
  echo "[copy_depict_ffi] Try running:"
  echo "  cargo build -p depict_ffi"
  exit 1
fi

if [ ! -d "$FLUTTER_BUNDLE" ]; then
  echo
  echo "[copy_depict_ffi] ERROR: Flutter bundle directory not found"
  echo "[copy_depict_ffi] Flutter has probably not been built yet"
  echo
  echo "[copy_depict_ffi] Try running:"
  echo "  ./docker-flutter.sh run -d linux"
  exit 1
fi

# --- Copy ---

echo
echo "[copy_depict_ffi] Copying libdepict_ffi.so into Flutter bundle"
cp -v "$RUST_LIB" "$FLUTTER_BUNDLE/"

echo
echo "[copy_depict_ffi] Verifying bundle contents:"
ls -l "$FLUTTER_BUNDLE"

echo
echo "[copy_depict_ffi] Done."
cp -v target/release/libdepict_ffi.so depict_flutter/libdepict_ffi.so
echo "[copy_depict_ffi] Also copied the library into position to be used for use by './depict-flutter.sh test'"
