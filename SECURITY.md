# Security

SoundBar is a local tool with no server, no account and no network access.
This document says exactly what each piece touches, what it deliberately never
does, and how it handles data it did not create.

## Reporting a vulnerability

Open an issue at https://github.com/malenitaa/soundbar/issues — or, if it's
sensitive, use GitHub's private
[security advisory form](https://github.com/malenitaa/soundbar/security/advisories/new).
Reports are very welcome; this is a small project and fixes ship fast.

## What it touches

**The Mac app:**

| What | Access | How |
| --- | --- | --- |
| Audio of apps you lower | processed in memory, never written | macOS system-audio permission, asked on first use |
| Play/pause for Spotify, Apple Music, Apple TV | one Apple event per click | macOS automation permission, asked on first use |
| List of apps currently playing sound (name, icon) | read | public Core Audio API, plus one private but long-stable system function (`responsibility_get_pid_responsible_for_pid`) to group helper processes under their app; no permission needed |
| `~/Library/Preferences/com.malenitaa.soundbar.plist` | read/write | stores one value: your glass/solid panel choice |
| The system log | write | diagnostic messages only — app names, never audio |

**The browser extension:**

| What | Access | How |
| --- | --- | --- |
| Tabs playing audio (title, address, mute state) | read | host permission for all sites (`<all_urls>`), which Chrome shows as "read and change your data on all websites" |
| Those tabs' icons | read from the browser's local icon cache, never downloaded | `favicon` permission |
| Media elements on pages | volume and pause when you click; a read-only "is anything playing?" check when the popup opens | `scripting` permission, on the same sites |
| Per-tab volume choices | read/write | browser session storage, erased when the browser closes |

That is the complete list, verified against the source on 15/11/2026: the app
is a handful of short Swift files with no dependencies, the extension is one
JavaScript file with no build step.

## What it never touches

- **No network.** Neither piece opens a socket — no update check, no crash
  reporting, no analytics, no telemetry. There is no place for your data to
  go.
- **No recording.** The audio permission's system prompt says "record", but
  audio exists only inside a realtime callback on its way to your speakers.
  It is never written to disk, kept in a buffer beyond the callback, or made
  available to anything else.
- **No microphone recording.** The permission covers other apps' *output*,
  and SoundBar never reads or plays your mic. One caveat: if your output
  device has its own mic (a USB or Bluetooth headset, an audio interface),
  macOS may show that mic as in use while a slider is below 100%, because
  the device is opened as a whole. Version 0.2.0 could replay that input
  instead of the app's audio; that's fixed on `main` and in the next release.
- **No credentials, no personal files, no browsing history.** The extension
  never reads page content either — it only touches media elements' volume
  and play state, and only in response to your clicks.
- **No third-party code.** The app is pure Swift against Apple's frameworks;
  the extension is vanilla JavaScript. There is no supply chain to
  compromise.

## Untrusted input

Names and titles shown in the panels come from other apps and web pages, so
they are treated as hostile:

- **In the app**, app names are rendered as plain text by the UI framework —
  they cannot inject anything. The play/pause command interpolates a bundle
  ID into an AppleScript string, but **only after checking it against a
  hardcoded three-entry allowlist**, so no attacker-controlled string can
  ever reach the interpolation. ⚠️ *If you edit `PlaybackControl.swift`:
  that allowlist guard is the entire injection defense. Making the list
  dynamic, or moving the guard, silently creates a script-injection hole.
  There is a comment in the code saying so.*
- **In the extension popup**, tab titles are written to the DOM with
  `textContent`, never `innerHTML` — a tab named `<img onerror=...>` renders
  as literal text. Extension pages enforce a strict CSP (no network connections, images only
  from the extension itself), tab icons come from the browser's local cache
  instead of the page's own icon address, and volume values are re-clamped to
  [0, 1] both when read back from storage and after crossing the
  serialization boundary into the page. Code is injected into a page only
  when you open the popup (a read-only check for playing media) and when you
  click in it, and only the three small functions visible in `popup.js`.

## Hardening in place

- The app is signed with the **hardened runtime**, which blocks library
  injection and debugger attachment into a process holding an audio
  permission.
- Every tap and aggregate audio device the app creates is **private** — not
  visible to or usable by other processes — and destroyed the moment a
  slider returns to 100%, or when the app quits, even if it crashes.

## What's tested

Only what has a test, or was checked by hand in the [15/11/2026 review](docs/AUDITORIA.md), goes here.

| Guarantee | Where | Test |
| --- | --- | --- |
| An app is back at full volume if SoundBar crashes | `ProcessTapController.swift` (private tap + aggregate) | — (checked by hand: `kill -9` with an app at 50%, back to 100% within 1 s; spike #1) |
| The mic of an output device is never played | `TapMixer.swift` | `TapMixerTests.outputDeviceWithItsOwnInputPlaysTheTapNotTheMic` |
| Volume is clamped to [0, 1]; 100% removes the tap | `MixerModel.swift` (`setVolume`) | `ModeloTests.volumenesImposiblesQuedanEnRango`, `.casiCienPorCientoSeAjustaACien` |
| Only Spotify, Music and TV can receive an Apple event | `PlaybackControl.swift` | `TapMixerPeorCasoTests.reproduccionSoloPermiteLaAllowlist` |
| Tab titles are shown as text, never as HTML | `extension/popup.js` | `test/extension/popup.test.js` ("el título hostil…") |
| Tab icons never load a page-chosen address | `extension/popup.js`, `manifest.json` CSP | `popup.test.js` ("favicon: sale del caché local…") |
| Volumes reaching a page or read from storage stay in [0, 1] | `extension/popup.js` | `popup.test.js` ("applyVolume deja el volumen en [0,1]…", "estado guardado con volumen fuera de rango…") |

## What's less proven

- The app is developed and daily-driven on **Apple Silicon**; the Intel half
  of the universal build is compiled and signed the same way but has seen
  little real-world use.
- The extension is exercised on **Chrome and Brave**. Edge runs the same
  engine and should behave identically, but has seen less use. There is no
  Safari or Firefox version.
- The app uses the hardened runtime but is **not yet App Sandboxed**:
  sandboxing an audio-tap app requires entitlement work that can break tap
  creation, and it will be done carefully rather than quickly.
- The app is **not notarized** with Apple (it's a free open-source project);
  macOS will warn on first open. [INSTALL.md](INSTALL.md) explains the
  supported way through that warning — never disable Gatekeeper for this or
  any app.
