# ADR-0003 · Group audio processes by their responsible process (private symbol)

**Date:** 16/08/2026 (written down 15/11/2026) · **Status:** accepted · **Author:** malenitaa

## Context

Core Audio lists the processes that make sound, not apps. Safari's audio comes from a shared WebKit "Graphics and Media" process, Chrome's from helpers, FaceTime's from `avconferenced` and `callservicesd`. Showing those as sliders is unreadable. SoundBar's own replay also shows up as a process making sound, and tapping it silences everything (a real first-day bug).

## Decision

**Group process objects by `responsibility_get_pid_responsible_for_pid` (looked up with `dlsym`). Fall back to stripping `.helper` suffixes from the bundle ID, plus a small alias table for FaceTime's daemons. Always skip SoundBar's own pid and anything it is responsible for.**

## Alternatives considered

| Alternative | Why not |
|---|---|
| Parent pid (`ppid`) | XPC services are children of launchd, not of the app |
| Bundle ID heuristics only | Safari's WebKit process is `com.apple.WebKit.GPU`, which has no relation to Safari's ID |

## Consequences

- It relies on a private symbol. If it disappears, `dlsym` returns nil and grouping degrades to the heuristic. It doesn't crash.
- New daemons that carry another app's audio need an entry in `bundleAliases`.

## How it's verified

- The grouping tests for `rootBundleID` and `canonicalBundleID` (CA-8 in `docs/SPEC.md`). The self-exclusion (CA-9) has no test: it needs a live process list.
