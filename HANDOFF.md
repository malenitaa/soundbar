# SoundBar — handoff

**Status:** app and extension work and are tested; v0.2.1 (the current release) ships the output-device fix. Extension 0.2.2 isn't in the store yet. · **Last update:** 21/11/2026
**Language:** Swift (app, the right fit for Core Audio + SwiftUI menu bar) and vanilla JS (Chrome extension, required) · **Shape:** simple, no layers
**Run:** `./scripts/build-app.sh && open dist/SoundBar.app` · **Tests:** `swift test` and `node --test test/extension/popup.test.js` · **Deploy:** none (desktop app; releases are DMGs on GitHub)

## Roadmap

```mermaid
timeline
    title SoundBar
    section Done
        0.1 · Per-app mixer : process taps : grouping by responsible process
        0.2 · Polish : mute and play/pause : glass/solid panel : Chrome extension
        Closing review (15/11/2026) : spike #1 : layout fix : 49 tests : audit
        0.2.1 · Release the fix (21/11/2026) : universal DMG : SHA-256
    section Next
        Extension 0.2.2 · real-browser test : Web Store
        0.3 · Gaps vs. the reference : launch at login : remember levels
```

| Stage | What's in it | Status | Criteria (SPEC) |
|---|---|---|---|
| 0.1–0.2 | mixer, mute, play/pause, panel styles, extension | ✅ | CA-1…CA-13 |
| Closing review | spec, tests, worst-case run, audit, ADRs, docs | ✅ | all |
| 0.2.1 | release PR #3 + the closing review | ✅ | CA-2, CA-3 |
| Extension 0.2.2 | test in a real browser, send to the Web Store | ⏳ | — |
| 0.3 | parity gaps (see `docs/SPEC.md` §7) | ⏳ | — |

## What was done (latest first)
- 21/11 · v0.2.1 released (#10): universal DMG signed `adhoc,runtime`, minimum macOS 14.4, its SHA-256 in the notes and as an asset (recipe: `docs/interno/DISENO.md` §7). Built from a clean clone outside iCloud (see "To decide"). Published without listening to it first; the last check by ear is PR #3's.
- 15/11 · Closing review: `docs/SPEC.md` with a parity table, 31 new Swift tests and 12 Node tests (worst case), security review (`docs/AUDITORIA.md`), six ADRs, SECURITY.md corrected and given a tested-guarantees table. Extension 0.2.2: icons from the local cache (no network), `tabs` permission removed, stricter CSP. App version bumped to 0.2.1.
- 15/11 · Spike #1 closed: Apple Events work, crash cleanup works, buffer layout failed → #2, fixed in PR #3.
- 19/08 · FaceTime's call daemons grouped as FaceTime.
- 18/08 · v0.2.0: panel styles, icon, INSTALL.md.

## Next
1. Listen to the 0.2.1 DMG: lower an app on the built-in speakers, then on a headset or interface with a mic (the #2 case). It shipped without this check.
2. Load extension 0.2.2 unpacked in Chrome and check that titles and icons still show, then send it to the Web Store — #11.
3. Parity gaps: launch at login #12, remembering levels #13, sleep/wake and unplugging #14, permission-denied hint #15.

## Decisions I made (for veto)
- **Extension icons come from the browser's local favicon cache** (`favicon` permission) instead of the page's own icon URL, and the `tabs` permission was removed. You chose "fix now"; it's not tested in a real browser. `extension/manifest.json`, `popup.js` (`render`).
- **A corrupt stored tab volume shows as 100 %** (anything that isn't a finite number), and values are clamped to [0, 1]. `popup.js` (`getState`).
- **Muting a tab that closed while the popup was open does nothing** instead of throwing. `popup.js` (mute handler).
- **`setVolume(.nan)` stays as silence (0)**, documented by a test rather than changed. `ModeloTests.volumenNaNQuedaEnCero`.
- **The public audit doesn't describe H1**; details live in the gitignored `docs/interno/`.
- **App version 0.2.1, extension 0.2.2** (patch: fixes only).

## To decide
- `README.privado.md` was absorbed into `docs/interno/DISENO.md`. Delete the original?
- `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`: the README says "Issues and PRs welcome", but there are no outside contributors yet — #17.
- Move the clone out of iCloud Drive: on 15/11 iCloud had duplicated source files and git refs (`TapMixer 2.swift`, `.git/refs/heads/main 2`), which broke the build and `git log --all`. On 21/11 `build-app.sh` couldn't sign there either: iCloud adds `com.apple.FinderInfo` to `dist/SoundBar.app` and `codesign` rejects it. If the clone stays, `xattr -cr "$APP"` before signing works around it.
- Branch protection on `main` (audit I2, accepted for now) — #17.

## Pending and known debts
- Open audit items: the mic streams in the aggregate #5 (M1), the MAIN world #6 (L1), injection into tabs that navigated elsewhere #7 (L2), checksums in INSTALL.md, a DMG script and the extension ZIP per release #8 (L3; the 0.2.1 release already has its SHA-256), the observer never disconnects #9 (I1).
- Stereo always goes to channels 1–2, not the device's preferred pair — #16.
- The app doesn't detect a denied audio permission (the slider mutes instead of lowering) — #15.
- Play/pause icon lag (#4).
- **Observability:** by design there's no telemetry or crash reporting (zero network). The only signal is GitHub issues, and local logs (`log stream --predicate 'subsystem == "com.malenitaa.soundbar"'`). Nothing to declare in SECURITY.md because nothing is sent.
- **Deploy:** doesn't apply (desktop app and browser extension).

## Where everything is
| What | Where |
|---|---|
| Spec and criteria | `docs/SPEC.md` |
| Decisions | `docs/adr/` (`INDICE.md`) |
| Internal design | `docs/interno/DISENO.md` (gitignored) |
| Audit | `docs/AUDITORIA.md` |
| For others | `README.md`, `SECURITY.md`, `INSTALL.md`, `extension/PRIVACY.md` |
