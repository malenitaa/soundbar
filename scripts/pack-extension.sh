#!/bin/bash
# Packs the Chrome extension into a Web Store-ready ZIP in dist/.
set -euo pipefail
cd "$(dirname "$0")/../extension"

VERSION=$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' manifest.json)
OUT="../dist/soundbar-tabs-$VERSION.zip"
mkdir -p ../dist
rm -f "$OUT"
zip -q "$OUT" manifest.json popup.html popup.js icon128.png
echo "Built dist/soundbar-tabs-$VERSION.zip"
