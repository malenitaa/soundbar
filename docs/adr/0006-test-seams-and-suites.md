# ADR-0006 · Test seams and the two suites

**Date:** 15/11/2026 · **Status:** accepted · **Author:** malenitaa

## Context

Until 15/11/2026 the repo had no tests. The closing review added worst-case tests for the mixing, the model, bundle-ID grouping and the extension popup. Some of that code wasn't reachable from a test.

## Decision

**Open the minimum seams and keep two suites without dependencies: `swift test` (Swift Testing) for the app, and `node --test test/extension/popup.test.js` (Node's built-in runner) for the extension.**

- `MixerModel.canonicalBundleID` and `MixerModel.rootBundleID` (`Sources/SoundBar/MixerModel.swift`) went from `private static` to internal, so the tests can call them with `@testable import`. No behavior change.
- `TapMixer.mix` was already pure (ADR-0004).
- `extension/popup.js` is not modified for testing. The test loads it into a `node:vm` context with minimal stubs for `chrome` and `document`.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Test private functions through reflection | Fragile and banned in permanent tests |
| Jest or Vitest for the extension | Adds the first dependency to a project that promises none |
| Turn `popup.js` into an ES module to import it | Changes how the popup loads, for the tests' sake |

## Consequences

- `ModeloTests` builds a real `MixerModel` and real taps, with an empty process list: no app is muted, but the tests need a Mac with Core Audio. They wouldn't run on a Linux CI.
- The DOM stubs don't behave exactly like a browser (for example, a real `<input type=range>` clamps its value).

## How it's verified

`swift test` → 37 tests. `node --test test/extension/popup.test.js` → 12 tests.
