# Security

## Threat model, in plain terms

SoundBar is deliberately built to have almost no attack surface:

- **No network code.** Neither the app nor the extension makes any network
  request, ever. There is no server, no telemetry, no update channel, no
  place for your data to go.
- **No dependencies.** The app is pure Swift against Apple's frameworks;
  the extension is vanilla JavaScript. There is no third-party supply
  chain to compromise.
- **No persistence beyond preferences.** Audio is processed in memory in a
  realtime callback and never written anywhere. The extension stores only
  per-tab volume numbers, in session storage that the browser erases on
  exit.
- **Least privilege.** The app asks for exactly one permission (system
  audio capture — Apple's official API for adjusting other apps' audio,
  plus Apple events if you use the play/pause button). The extension's
  permissions are the minimum for listing audible tabs and adjusting
  their media.

## Hardening in place

- The macOS app is signed with the hardened runtime (blocks library
  injection and debugger attachment).
- Play/pause commands only ever target a hardcoded allowlist of bundle
  IDs (Spotify, Apple Music, Apple TV) — no dynamic script construction
  from untrusted input.
- The extension popup builds its UI exclusively with `textContent`
  (untrusted tab titles can't inject markup), enforces a strict CSP on
  extension pages, loads favicons over HTTPS only, and clamps all values
  that cross the page boundary. Code injected into pages runs only in
  response to your clicks in the popup.

## Reporting a vulnerability

If you find a security issue, please open a
[GitHub issue](https://github.com/malenitaa/soundbar/issues) — or, if it's
sensitive, use GitHub's private
[security advisory](https://github.com/malenitaa/soundbar/security/advisories/new)
form. Reports are very welcome; this is a small project and fixes ship
fast.
