#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLI_DIR="$ROOT_DIR/cli"
OUT_DIR="${1:-$ROOT_DIR/build/cli-dist}"

ARM_BUILD="$ROOT_DIR/build/cli-arm64"
X86_BUILD="$ROOT_DIR/build/cli-x86_64"

echo "Building chronote-cli (arm64)..."
swift build \
  --package-path "$CLI_DIR" \
  --configuration release \
  --arch arm64 \
  --build-path "$ARM_BUILD"

echo "Building chronote-cli (x86_64)..."
swift build \
  --package-path "$CLI_DIR" \
  --configuration release \
  --arch x86_64 \
  --build-path "$X86_BUILD"

mkdir -p "$OUT_DIR"
cp "$ARM_BUILD/release/chronote-cli" "$OUT_DIR/chronote-cli-arm64"
cp "$X86_BUILD/release/chronote-cli" "$OUT_DIR/chronote-cli-x86_64"

echo "Creating universal chronote-cli..."
lipo -create \
  "$OUT_DIR/chronote-cli-arm64" \
  "$OUT_DIR/chronote-cli-x86_64" \
  -output "$OUT_DIR/chronote-cli"

chmod +x "$OUT_DIR/chronote-cli" "$OUT_DIR/chronote-cli-arm64" "$OUT_DIR/chronote-cli-x86_64"

echo "Done."
echo "Output directory: $OUT_DIR"
ls -lh "$OUT_DIR"/chronote-cli*
