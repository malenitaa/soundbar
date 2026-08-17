# SoundBar

**Per-app volume mixer for macOS, right in your menu bar.**

macOS has one master volume for everything. If you're on a Meet call and want quiet background music, your only option is digging into each app's own volume control — if it has one. Windows solved this years ago with its volume mixer; SoundBar brings the same idea to the Mac.

- 🎚️ One slider per app that's currently playing audio
- 🪶 No drivers, no kernel extensions, nothing to uninstall later — built on Apple's official [Core Audio process tap API](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- 🔒 Audio is processed in memory on its way to your speakers, never recorded or stored, and the app makes zero network requests
- 🌐 UI in English and Spanish (follows your system language)
- 🧩 Includes a companion Chrome extension for **per-tab** volume

## Requirements

macOS 14.4 (Sonoma) or later.

## Install

Build from source (takes under a minute):

```bash
git clone https://github.com/malenitaa/soundbar.git
cd soundbar
./scripts/build-app.sh
open dist/SoundBar.app
```

Or grab `SoundBar.dmg` from [Releases](https://github.com/malenitaa/soundbar/releases).

The first time you lower an app's volume, macOS will ask for permission to capture system audio — that's the official API at work, and it's the only permission SoundBar needs.

## Per-tab volume (Chrome extension)

macOS sees your whole browser as a single audio source, so no native app can tell a Meet tab from a YouTube tab. The `extension/` folder ships a tiny Chrome extension that closes that gap: it lists the tabs currently playing audio and gives each one a volume slider.

To install it:

1. Open `chrome://extensions`
2. Enable **Developer mode** (top right)
3. Click **Load unpacked** and pick the `extension/` folder

It needs no build step and makes no network requests either.

## How it works

SoundBar watches Core Audio's process list for apps that are emitting sound. When you lower an app's slider, it creates a *process tap* for that app: the app's direct output is muted, its audio is captured, scaled by your chosen gain, and played through your output device — all inside one realtime callback, with no audible latency. Sliding back to 100% destroys the tap and the app talks to your speakers directly again, as if SoundBar had never been there.

This is the same mechanism Apple introduced in macOS 14 for screen recorders to capture app audio. Older tools in this space (like the now-abandoned Background Music) had to install a virtual audio driver system-wide; SoundBar leaves your audio stack untouched.

## Limitations

- Volume can be lowered per app, not boosted past 100% — by design, to keep the signal clean.
- Browser tabs share one slider at the OS level (that's what the Chrome extension is for).
- The tab extension controls standard `<audio>`/`<video>` playback, which covers YouTube, Meet, Spotify Web and most sites, but not the rare player built purely on Web Audio.

## Enjoyed it?

If this was useful and you'd like to support the project:

- [Cafecito](https://cafecito.app/rezamalena)
- [Ko-fi](https://ko-fi.com/malenitaa)

## License

[MIT](LICENSE)
