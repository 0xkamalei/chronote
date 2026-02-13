#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLI_DIR="$ROOT_DIR/cli"
OUT_DIR="${1:-$ROOT_DIR/build/cli-dist}"
TARGET_ARCH="${2:-}"  # Optional: arm64 or x86_64, empty means build all

ARM_BUILD="$ROOT_DIR/build/cli-arm64"
X86_BUILD="$ROOT_DIR/build/cli-x86_64"

mkdir -p "$OUT_DIR"

# Build for arm64
if [ -z "$TARGET_ARCH" ] || [ "$TARGET_ARCH" = "arm64" ]; then
    echo "Building chronote-cli (arm64)..."
    swift build \
      --package-path "$CLI_DIR" \
      --configuration release \
      --arch arm64 \
      --build-path "$ARM_BUILD"
    cp "$ARM_BUILD/release/chronote-cli" "$OUT_DIR/chronote-cli-arm64"
    chmod +x "$OUT_DIR/chronote-cli-arm64"
fi

# Build for x86_64
if [ -z "$TARGET_ARCH" ] || [ "$TARGET_ARCH" = "x86_64" ]; then
    echo "Building chronote-cli (x86_64)..."
    swift build \
      --package-path "$CLI_DIR" \
      --configuration release \
      --arch x86_64 \
      --build-path "$X86_BUILD"
    cp "$X86_BUILD/release/chronote-cli" "$OUT_DIR/chronote-cli-x86_64"
    chmod +x "$OUT_DIR/chronote-cli-x86_64"
fi

# Create universal binary only when building all
if [ -z "$TARGET_ARCH" ]; then
    echo "Creating universal chronote-cli..."
    lipo -create \
      "$OUT_DIR/chronote-cli-arm64" \
      "$OUT_DIR/chronote-cli-x86_64" \
      -output "$OUT_DIR/chronote-cli"
    chmod +x "$OUT_DIR/chronote-cli"
fi

echo "Done."
echo "Output directory: $OUT_DIR"
ls -lh "$OUT_DIR"/chronote-cli*
