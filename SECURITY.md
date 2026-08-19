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
| List of apps currently playing sound (name, icon) | read | public system API, no permission needed |
| `~/Library/Preferences/com.malenitaa.soundbar.plist` | read/write | stores one value: your glass/solid panel choice |
| The system log | write | diagnostic messages only — app names, never audio |

**The browser extension:**

| What | Access | How |
| --- | --- | --- |
| Tabs playing audio (title, icon, mute state) | read | `tabs` permission |
| Media elements on pages | volume and pause, only when you click | `scripting` permission |
| Per-tab volume choices | read/write | browser session storage, erased when the browser closes |

That is the complete list, verified against the source: the app is seven short
Swift files with no dependencies, the extension is one JavaScript file with no
build step.

## What it never touches

- **No network.** Neither piece opens a socket — no update check, no crash
  reporting, no analytics, no telemetry. There is no place for your data to
  go.
- **No recording.** The audio permission's system prompt says "record", but
  audio exists only inside a realtime callback on its way to your speakers.
  It is never written to disk, kept in a buffer beyond the callback, or made
  available to anything else.
- **No microphone.** The permission covers other apps' *output*. Your mic is
  never opened.
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
  as literal text. Extension pages enforce a strict CSP, favicons load over
  HTTPS only, and volume values are re-clamped to [0, 1] after crossing the
  serialization boundary into the page. Code is injected into a page only in
  response to your clicks in the popup, and only the three small functions
  visible in `popup.js`.

## Hardening in place

- The app is signed with the **hardened runtime**, which blocks library
  injection and debugger attachment into a process holding an audio
  permission.
- Every tap and aggregate audio device the app creates is **private** — not
  visible to or usable by other processes — and destroyed the moment a
  slider returns to 100%, or when the app quits.

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
