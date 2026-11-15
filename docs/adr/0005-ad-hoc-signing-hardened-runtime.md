# ADR-0005 · Ad-hoc signing with hardened runtime; no notarization, no sandbox yet

**Date:** 16/08/2026 (written down 15/11/2026) · **Status:** accepted · **Author:** malenitaa

## Context

SoundBar is free and open source. Notarization needs a paid Apple Developer account. The app holds the system-audio permission, so code injection into it matters.

## Decision

**`scripts/build-app.sh` signs ad-hoc with `--options runtime` and no entitlements file. Releases are universal DMGs, not notarized and not sandboxed.** INSTALL.md shows the supported way past Gatekeeper's warning and says never to disable Gatekeeper.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Developer ID + notarization | Costs a yearly fee; can be revisited |
| App Sandbox | Needs audio-input and apple-events entitlements and may break tap creation; to be evaluated with time |
| No hardened runtime | Leaves DYLD injection open into a process with an audio permission |

## Consequences

- With an ad-hoc signature, TCC ties the permission to the binary's hash: every new build asks for the audio and automation permissions again. `[to confirm]` whether that's what users see on updates.
- macOS warns on first open.

## How it's verified

`codesign -dvv --entitlements - SoundBar.app` → `flags=0x10002(adhoc,runtime)`, no entitlements (checked on the v0.2.0 DMG, spike #1).
