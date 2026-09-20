#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${COMMIT:?COMMIT is required}"

BUILD_NAME="depict-web-static-${VERSION}"
mkdir -p "$BUILD_NAME"

# Copy only the static files needed
cp web/dist/index.html "$BUILD_NAME/"
cp web/dist/*.wasm "$BUILD_NAME/"
cp web/dist/depict-web*.js "$BUILD_NAME/"
cp web/dist/*.css "$BUILD_NAME/" 2>/dev/null || true

# Create deployment README
cat > "$BUILD_NAME/README.txt" <<EOF
Depict Web - Static Deployment
Version: ${VERSION}
Build Date: $(date +%Y-%m-%d)
Commit: ${COMMIT}

FILE CONTENTS
=============
index.html
WebAssembly and JavaScript assets
Stylesheets

For more information:
https://github.com/jsavage/depict
EOF

# Create tarball
ARCHIVE="${BUILD_NAME}.tar.gz"
tar -czf "$ARCHIVE" "$BUILD_NAME"

echo "ARCHIVE=$ARCHIVE"
echo "BUILD_DIR=$BUILD_NAME"