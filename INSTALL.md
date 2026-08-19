# Install and use (for anyone, no coding needed)

SoundBar has two independent pieces — install one or both:

- **SoundBar**, the Mac app: a volume slider for every app, in your menu bar.
- **SoundBar Tabs**, the browser extension: a volume slider for every tab, in
  Chrome, Brave or Edge.

Requirements: macOS 14.4 or newer for the app (Apple Silicon or Intel). The
extension only needs a Chromium browser, on any system.

## Before installing anything: check what you're about to run

This is open-source software you're downloading from the internet. Before
installing any app like this (this one included), it's good practice to look
at what it does. Here everything is short enough to actually read:

- [`Sources/SoundBar/`](Sources/SoundBar/) — the Mac app, seven short Swift
  files.
- [`extension/`](extension/) — the extension: one JavaScript file
  ([`popup.js`](extension/popup.js)), one HTML file, and its
  [`manifest.json`](extension/manifest.json).

Neither piece makes any network request, anywhere. What each one touches, in
detail: [SECURITY.md](SECURITY.md).

## The Mac app

1. Go to the [latest release](https://github.com/malenitaa/soundbar/releases/latest)
   and download `SoundBar-x.y.z.dmg`.
2. Open the `.dmg` and drag **SoundBar** onto the **Applications** folder next
   to it.
3. Open SoundBar from Applications. **The first time, macOS will warn you** —
   something like *"SoundBar cannot be opened because it is from an
   unidentified developer"*. That's Gatekeeper doing its job: this app is
   free and open source, so it isn't notarized through Apple's paid program.
   The supported way through:
   - **Right-click** (or Control-click) SoundBar in Applications and choose
     **Open**, then **Open** again in the dialog. On newer macOS versions the
     button may appear under **System Settings → Privacy & Security → Open
     Anyway**.
   - ⚠️ **Never disable Gatekeeper or any system protection to install
     software** — this app included. No legitimate app needs that; if
     instructions anywhere tell you to, be suspicious.
4. A sliders icon appears in your menu bar. Click it, and the panel lists
   every app currently playing sound.
5. **The first time you lower a slider**, macOS asks permission to *"record
   system audio"*. That is Apple's wording for its official
   volume-adjustment mechanism — the only one that exists. Nothing is
   recorded or stored, and the code is public so you don't have to take our
   word for it: see [SECURITY.md](SECURITY.md). Click **Allow**, and the
   slider works from then on.
6. Optional: the first time you use play/pause on Spotify, Apple Music or
   Apple TV, macOS asks one more permission (to control that app). Same
   deal — allow it once.

**If a slider mutes the app instead of lowering it:** the audio permission
was denied. Grant it in **System Settings → Privacy & Security → Screen &
System Audio Recording**, then try again.

**To uninstall:** quit SoundBar (the power icon in the panel) and drag it
from Applications to the Trash. It leaves behind only one small preferences
file (your glass/solid panel choice) at
`~/Library/Preferences/com.malenitaa.soundbar.plist`, which you can delete
too. The permissions you granted can be revoked any time in System Settings →
Privacy & Security.

## The browser extension

SoundBar Tabs is under review on the Chrome Web Store. Until it's published
there, load it straight from this repository — it takes a minute:

1. Download this repository: green **Code** button (top of the
   [repo page](https://github.com/malenitaa/soundbar)) → **Download ZIP**,
   then unzip it.
2. Open `chrome://extensions` (Brave: `brave://extensions`, Edge:
   `edge://extensions`).
3. Turn on **Developer mode** (a switch in the corner of that page).
4. Click **Load unpacked** and choose the `extension/` folder from the
   unzipped download.

Click the extension's icon while something is playing: every audible tab
appears with its own slider, mute and play/pause.

**To uninstall:** remove it from the same extensions page. It stores nothing
outside the browser.

## Questions first, issues second

If something seems off, check
[Things that look like bugs (and aren't)](README.md#things-that-look-like-bugs-and-arent)
in the README — then, by all means,
[open an issue](https://github.com/malenitaa/soundbar/issues).
