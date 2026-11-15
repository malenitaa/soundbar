# ADR-0004 · Mixing as a pure function: the tap is the last input buffer

**Date:** 15/11/2026 · **Status:** accepted · **Author:** malenitaa

## Context

Spike #1 measured what the IOProc receives. The aggregate lists the output device's own input streams *before* the tap: on a device with 1 out + 1 in, the input was `[(1 ch) device input, (2 ch) tap]`. The old loop copied input *i* into output *i*, so it played the device's input (a headset mic) instead of the app, and scrambled mono, multichannel and non-interleaved outputs (#2).

## Decision

**`TapMixer.mix` (pure, no Core Audio objects) zeroes the output, takes the tap from the last input buffer, and writes its channels frame by frame into the first output channels (averaged for a mono device). The IOProc only calls it.** It's the first seam opened for testing, and it brought the repo's first test target (`swift test`, Swift Testing).

## Alternatives considered

| Alternative | Why not |
|---|---|
| Compute the tap's buffer index from the output device's input stream count | Same ordering assumption, plus a property query and more state |
| Send stereo to `kAudioDevicePropertyPreferredChannelsForStereo` | More correct for devices whose stereo pair isn't 1–2, but left for later (documented limitation) |

## Consequences

- It relies on the tap streams coming after the subdevice's streams, as measured on macOS 27.2.
- The aggregate still contains the output device's input streams, even though they're never played (see `docs/AUDITORIA.md`).

## How it's verified

`Tests/SoundBarTests/TapMixerTests.swift`: 6 tests. They failed 4 of 6 before the fix and pass 6 of 6 after. On a loopback device: RMS 0.1061 at gain 0.5 and 0.0530 at 0.25.
