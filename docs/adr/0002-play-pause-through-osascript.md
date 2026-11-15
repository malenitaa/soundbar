# ADR-0002 · Play/pause through `osascript` with a hardcoded allowlist

**Date:** 16/08/2026 (written down 15/11/2026, with spike #1's findings) · **Status:** accepted · **Author:** malenitaa

## Context

Spotify, Apple Music and Apple TV accept a `playpause` Apple Event. The command string has to name the target app, and app identities come from the system's process list, so in principle they're attacker-influenced.

## Decision

**`PlaybackControl` runs `/usr/bin/osascript -e 'tell application id "<bundle ID>" to playpause'` only for a bundle ID that is in a hardcoded three-entry set. The guard sits right before the interpolation.**

Spike #1 (15/11/2026) checked the hardened-runtime build: no `com.apple.security.automation.apple-events` entitlement is needed. The sender of the event is `osascript`, an Apple platform binary. TCC attributes the request to SoundBar, the responsible app, and shows the normal "wants to control Spotify" prompt.

## Alternatives considered

| Alternative | Why not |
|---|---|
| `NSAppleScript` or `NSAppleEventDescriptor` in-process | Would need the apple-events entitlement in the hardened runtime, and the same allowlist |
| Media-key emulation | Hits whatever app macOS considers "now playing", not the row the user clicked |
| A dynamic list of scriptable apps | Any non-hardcoded source reaching the interpolation is a script-injection hole |

## Consequences

- If this ever moves in-process, add the entitlement to `scripts/build-app.sh`.
- `try? process.run()` swallows errors. A denied permission fails silently (the button does nothing).
- The play/pause icon follows `kAudioProcessPropertyIsRunningOutput`, not the click, so it lags (#4).

## How it's verified

- Spike #1: with and without the entitlement, `status=0`. End to end on the v0.2.0 build with Spotify and Music.
- The allowlist test in `Tests/SoundBarTests` (CA-10 in `docs/SPEC.md`).
