#!/bin/bash
# Builds SoundBar.app into dist/. Pass --universal to build for both
# Apple Silicon and Intel (needed for release DMGs).
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH_FLAGS=""
if [[ "${1:-}" == "--universal" ]]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
fi

# shellcheck disable=SC2086 — ARCH_FLAGS is intentionally word-split
swift build -c release $ARCH_FLAGS
BIN_PATH="$(swift build -c release $ARCH_FLAGS --show-bin-path)/SoundBar"

APP="dist/SoundBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp "$BIN_PATH" "$APP/Contents/MacOS/SoundBar"

# Icon: regenerate with `swift scripts/make-icon.swift` if the design changes.
cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Hardened runtime: blocks code injection (DYLD insertion, debugger attach)
# and unsigned library loading into an app that holds an audio permission.
codesign --force --options runtime --sign - "$APP"
echo "Built $APP"
