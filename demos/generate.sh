#!/usr/bin/env bash
# Generate demo screenshot
# Run from demos/ directory

set -e

echo "Generating flo demo screenshot..."

if ! command -v vhs &> /dev/null; then
    echo "Error: vhs is not installed"
    echo "Install with: brew install vhs"
    exit 1
fi

# Create build directory
mkdir -p build

# Generate simple demo
echo "→ Generating flo 17 demo..."
vhs demo-simple.tape

echo "✓ Done! Screenshot saved to build/:"
ls -lh build/ 2>/dev/null || echo "No files generated yet"
