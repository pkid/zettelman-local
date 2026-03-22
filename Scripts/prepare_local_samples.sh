#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$ROOT_DIR/Evaluation/.local-samples"
mkdir -p "$DEST_DIR"

SOURCES=(
  "/Users/yashu/Downloads/IMG_6829.HEIC"
  "/Users/yashu/Downloads/IMG_6830.HEIC"
  "/Users/yashu/Downloads/IMG_6831.HEIC"
  "/Users/yashu/Downloads/IMG_6832.HEIC"
)

for src in "${SOURCES[@]}"; do
  if [[ ! -f "$src" ]]; then
    echo "Missing sample: $src" >&2
    exit 1
  fi
  cp -f "$src" "$DEST_DIR/"
done

echo "Prepared local samples in $DEST_DIR"
