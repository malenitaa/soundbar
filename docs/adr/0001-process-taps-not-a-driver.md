# ADR-0001 · Core Audio process taps, not an audio driver

**Date:** 16/08/2026 (written down 15/11/2026) · **Status:** accepted · **Author:** malenitaa

## Context

Per-app volume on macOS used to need a virtual audio driver (Background Music, SoundSource): every app's audio is rerouted through a fake device. Drivers need installation with admin rights, survive the app that installed them (an orphaned Background Music driver was the starting point of this project) and touch every sound on the system. macOS 14.4 added process taps, which capture one process's output and can mute it at the source.

## Decision

**Each lowered app gets one private process tap (`mutedWhenTapped`) plus one private aggregate device on the default output. An IOProc replays the tap with the gain applied. At 100 % the tap is destroyed.**

- Taps are created lazily, on the first slider move below 100 %, so the audio permission is asked only when it's needed.
- 100 % (≥ 0.999) means no tap at all: zero added latency, and SoundBar is out of the audio path.
- Both objects are private, so no other process sees them and they die with SoundBar.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Virtual audio driver (HAL plug-in) | Needs installation, outlives the app, and routes all audio through it |
| One shared tap for every app | One misbehaving app would affect the others, and you can't hand a single app back at 100 % |
| A public (non-private) aggregate | Shows up in Audio MIDI Setup and other apps, and survives a crash |

## Consequences

- Minimum macOS is 14.4.
- Without the "system audio recording" permission the tap captures silence while the app stays muted. INSTALL.md documents it; the app doesn't detect it.
- Mixing correctness depends on the aggregate's buffer layout (see ADR-0004).

## How it's verified

- Spike #1: `kill -9` with an app at 50 % → the app is back at full volume within 1 s (RMS 0.106 → 0.212 on a loopback device).
- `TapMixerTests` for the mixing.
