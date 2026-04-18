#!/bin/bash
set -e

# Support common paths in Xcode/Terminal
export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v bun &> /dev/null; then
    echo "Error: bun not found. Please install bun (https://bun.sh) to build the standalone binary."
    echo "Run: curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

echo "Installing dependencies..."
bun install

echo "Compiling standalone binary using Bun..."
BINARY_PATH="dist/codingplan-service"
mkdir -p dist

# Bun compile bundles everything including the runtime and sqlite
bun build src/main.ts --compile --outfile "$BINARY_PATH"

# Try to sign the binary for macOS, but don't fail if it's not supported by the format
echo "Attempting to sign binary..."
codesign --remove-signature "$BINARY_PATH" || true
codesign -s - --force "$BINARY_PATH" || echo "Warning: Could not sign binary, skipping..."

echo "------------------------------------------------"
echo "Success! Standalone binary generated at: $BINARY_PATH"
echo "Size: $(du -h "$BINARY_PATH" | cut -f1)"
echo "This binary has NO dependencies on Node.js or Bun at runtime."
echo "------------------------------------------------"
