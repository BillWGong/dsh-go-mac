#!/usr/bin/env bash
# Fetch the pinned Peekaboo CLI used by Mac control. macOS 15+ only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/app/macos/Resources/peekaboo"
VERSION="4.9.8"
TAR_SHA="5b82b246cd7b257b68d15e136a8234848a8e70a5999cdf5526993fb860685bfe"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL --retry 3 -o "$TMP/peekaboo.tar.gz" \
  "https://github.com/openclaw/Peekaboo/releases/download/v$VERSION/peekaboo-macos-arm64.tar.gz"
echo "$TAR_SHA  $TMP/peekaboo.tar.gz" | shasum -a 256 -c -
tar -xzf "$TMP/peekaboo.tar.gz" -C "$TMP"
mkdir -p "$OUT"
cp "$TMP/peekaboo-macos-arm64/"{peekaboo,libswiftCompatibilitySpan.dylib,LICENSE,VERSION} "$OUT/"
chmod +x "$OUT/peekaboo"
echo "Peekaboo $VERSION -> $OUT"
