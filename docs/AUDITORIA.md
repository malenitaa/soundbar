# Security and privacy review — SoundBar

**Date:** 15/11/2026 · **Version reviewed:** app 0.2.0 + `main` at `b45578f` (PR #3 merged), extension 0.2.1 → 0.2.2 · **Scope:** the Swift app (`Sources/`), build and packaging scripts, the Chrome extension (`extension/`), public docs (README, SECURITY, INSTALL, PRIVACY, `store/listing.md`), git history, the published release assets and the GitHub repository settings.

**What this is and isn't.** It's a technical self-assessment: a code review by an agent that didn't write the code, automated checks and manual tests. It is **not** a certification or a review by an accredited third party.

## Summary

| Severity | Found | Fixed | Accepted (with reason) | Open (issue) |
|---|---|---|---|---|
| Critical | 0 | — | — | — |
| High | 1 | 0 | 0 | 1 (handled privately) |
| Medium | 3 | 2 (M2, M3) | 0 | 1 (M1: text corrected, code pending) |
| Low | 5 | 1 (L4) | 2 (L5, L2 partly) | 2 (L1, L3) + L2's code |
| Info | 4 | 1 (I4) | 1 (I2) | 2 |

Automated checks: there's no package manager to audit (SwiftPM with zero dependencies; the extension has no `package.json`). Instead, a grep for process, network and file APIs: no `URLSession`, socket, `NWConnection`, `fetch`, `XMLHttpRequest`, `WebSocket`, `sendBeacon`, `eval`, `new Function`, `innerHTML` or `insertAdjacentHTML` anywhere. The only process launch is `/usr/bin/osascript` behind the allowlist. Git history: `gitleaks git --log-opts="--all"` → *no leaks found*; a regex sweep for keys and tokens over `git log -p --all` → no output.

Tests: `swift test` → 37 passed; `node --test test/extension/popup.test.js` → 12 passed.

## Findings

### [H1] Repository history
**Status:** open, handled privately. The details aren't published until it's resolved. It doesn't affect the app, the extension or anyone who uses them.

### [M1] "Your mic is never opened" wasn't exact
**Where:** `SECURITY.md` ("No microphone"), `Sources/SoundBar/ProcessTapController.swift` (the aggregate includes the whole output device), `Sources/SoundBar/TapMixer.swift` · **Status:** public text corrected; code change pending (issue)
**Evidence:** spike #1 measured the aggregate's input on an output device that has inputs: `[(1 ch) device input, (2 ch) tap]`. Up to v0.2.0 the IOProc copied input 0 to output 0, which is the device's input. Fixed on `main` by PR #3 (the tap is the last buffer, the rest is discarded). But the device's input streams are still part of the aggregate.
**Risk:** with a headset or an interface as the output, its mic may be *opened* while a slider is below 100 % (orange indicator; Bluetooth headsets switching to call mode), even though it's no longer played. Not verified on a real headset. In v0.2.0 (the current release) the old IOProc could replay it. Not verified either: the hardened-runtime build has no audio-input entitlement, so it may receive silence.
**Fix:** SECURITY.md now says exactly that. Turning those streams off with `kAudioDevicePropertyIOProcStreamUsage` and checking on a real headset is #5; releasing PR #3 as v0.2.1 is #10.

### [M2] The popup loaded page-chosen favicon URLs (network requests)
**Where:** `extension/popup.js` (`render`), `extension/manifest.json` · **Status:** fixed (extension 0.2.2)
**Evidence:** `img.src = tab.favIconUrl` for any `https://` URL. The CSP had no `img-src`. That contradicted PRIVACY.md ("no network requests"), SECURITY.md and the store listing.
**Risk:** a page can set its icon to `https://tracker/x?id=…` and learn when the popup is opened. It was also a false statement in the store privacy policy.
**Fix:** icons come from the browser's local cache (`favicon` permission, `chrome-extension://<id>/_favicon/?pageUrl=…`). The CSP adds `img-src 'self'; connect-src 'none'; font-src 'none'; media-src 'none'`. **Test:** `popup.test.js`, "favicon: sale del caché local del navegador…". **Not verified in a real browser** (#11).

### [M3] Extension permissions weren't minimal, and SECURITY.md omitted the broadest one
**Where:** `extension/manifest.json`, `SECURITY.md`, `store/listing.md` · **Status:** fixed (0.2.2)
**Evidence:** `"permissions": ["tabs", …]` and `"host_permissions": ["<all_urls>"]`, while SECURITY.md's "complete list" didn't mention the host permission.
**Fix:** `tabs` removed. With the host permission the extension already sees the title and URL of audible tabs, and `tabs.query({audible})`, `tabs.get` and `tabs.update({muted})` don't need it. SECURITY.md and the listing now name `<all_urls>`. **Not verified in a real browser** (inferred from Chrome's documentation).

### [L1] Code runs in the page's MAIN world
**Where:** `extension/popup.js` (`runInTab`, `world: "MAIN"`, `allFrames: true`) · **Status:** open (#6)
**Risk:** a page (or a third-party iframe) can read `window.__soundbarVolume`, pre-set `__soundbarObserver` to disable the observer, or fake the popup's playing state. Arguments are a number and results are compared with `=== true`, so nothing escalates.
**Fix:** `world: "ISOLATED"`. Media elements are shared between worlds. It needs testing on YouTube, Meet and Spotify Web.

### [L2] Code is injected when the popup opens, including into tabs that navigated elsewhere
**Where:** `extension/popup.js` (`render` → `isAnyMediaPlaying`; `init` re-lists the tabs saved in storage) · **Status:** text corrected; code pending (#7)
**Risk:** state is stored per tab ID, not per origin, so a tab adjusted on one site and then moved to another still gets the read-only `isAnyMediaPlaying` injected.
**Fix:** SECURITY.md and the listing now say "when the popup opens and when you click". The issue is to store the origin with the state and drop it when the origin changes.

### [L3] Distribution: no published checksums, no DMG script, unpacked extension from `main`
**Where:** `INSTALL.md`, `scripts/` · **Status:** open (#8)
**Fix:** publish the SHA-256 with each release and in INSTALL.md; commit `scripts/build-dmg.sh`; attach the extension ZIP to a tagged release and point INSTALL.md at it.

### [L4] SECURITY.md had inaccurate facts
**Where:** `SECURITY.md` ("seven short Swift files"; "public system API, no permission needed" while a private symbol is used) · **Status:** fixed
**Fix:** the file count is gone. The private `responsibility_get_pid_responsible_for_pid` symbol is named (ADR-0003).

### [L5] Private symbol called through `unsafeBitCast`
**Where:** `Sources/SoundBar/MixerModel.swift` (`responsibilityFunction`) · **Status:** accepted (see below)

### [I1] The page's MutationObserver is never disconnected
**Where:** `extension/popup.js` (`applyVolume`) · **Status:** open (#9)
After Reset to 100 %, the extension keeps forcing `el.volume = 1` on every DOM mutation, overriding the site's own volume control until reload.

### [I2] `main` isn't branch-protected · **Status:** accepted (one maintainer). Private vulnerability reporting, secret scanning and push protection are on.

### [I3] A donation handle in the README · **Status:** for the author to review (not verified).

### [I4] Unreachable pre-rewrite objects in the local clone · **Status:** fixed (`git gc --prune=now`, 15/11/2026; `fsck` shows 0 unreachable commits).

## Accepted with reason

| # | What | Why it's accepted | When it's reviewed |
|---|---|---|---|
| L5 | `unsafeBitCast` of a private symbol | Its argument is a pid from Core Audio, not attacker input. If the symbol disappears, `dlsym` returns nil and grouping falls back to the heuristic | Every major macOS release |
| I2 | No branch protection on `main` | Single maintainer; every change goes through a PR by habit | If more people get write access |
| — | `setVolume(.nan)` stores 0 (silence) | The slider can't produce NaN. Silence is the same result `ProcessTapController.gain` already gives (`ModeloTests.volumenNaNQuedaEnCero`) | If the volume ever comes from outside the slider |
| — | `rootBundleID` strips one helper suffix, not a chain like `.helper.helper` | No real app uses that; the worst case is an extra slider | If one shows up |

## What wasn't reviewed

- Behavior with a real headset or audio interface (M1); Bluetooth profile switching.
- The extension in a real Chrome, Brave or Edge after the 0.2.2 changes (M2, M3).
- Intel builds; sleep/wake with active taps; unplugging the output device while tapped.
- Whether the v0.2.0 DMG binary matches the tagged source (no reproducible build).
- Caches outside GitHub (Software Heritage, GH Archive).
