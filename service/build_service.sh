#!/bin/bash
set -e

# Support Homebrew Node.js in Xcode build phase
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v node &> /dev/null; then
    echo "Error: node not found in PATH."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "Error: npm not found in PATH."
    exit 1
fi

# Ensure dependencies are installed
npm install

# Build JS bundle
npm run build

echo "Bundle generated at dist/index.js"
