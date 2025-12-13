#!/usr/bin/env bash
# Script to run the depict server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WEBROOT="$SCRIPT_DIR/dist"
PORT=${PORT:-8000}

echo "Starting depict server..."
echo "Web root: $WEBROOT"
echo "Port: $PORT"
echo "Access at: http://localhost:$PORT"
echo ""

exec "$SCRIPT_DIR/dist/depict-server"
