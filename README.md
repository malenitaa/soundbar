# SoundBar

**Your Mac has one volume for everything. SoundBar gives every app — and every browser tab — its own.**

On a call while music plays in the background? On Windows you'd open the volume mixer. On a Mac, there isn't one: your only option is hunting through each app's own settings. SoundBar fixes that with two small tools:

- **SoundBar** (macOS menu bar app) — a slider for every app that's playing sound. Lower Spotify to 30% while your Meet call stays at 100%. Tap the speaker to mute an app entirely; Spotify, Apple Music and Apple TV also get a play/pause button.
- **SoundBar Tabs** (browser extension for Chrome, Brave and Edge) — the same idea inside your browser, where macOS can't see individual tabs. Volume, mute and pause for each tab that's playing audio.

No drivers. No kernel extensions. Nothing running that you can't quit from the menu bar, and nothing left behind if you delete it.

## Get the Mac app

1. Download `SoundBar.dmg` from the [latest release](https://github.com/malenitaa/soundbar/releases) (works on Apple Silicon and Intel, macOS 14.4+).
2. Open it and drag SoundBar to Applications.
3. First launch: right-click the app → **Open** (it's not notarized with Apple — it's a free open-source app).
4. The first time you lower a slider, macOS asks permission to "record system audio". That's Apple's official mechanism for adjusting other apps' audio — **nothing is recorded or stored**, and SoundBar makes zero network requests. The code is public, so you don't have to take our word for it.

Click the sliders icon in your menu bar and you're mixing.

## Get the browser extension

Until it lands on the Chrome Web Store, load it straight from this repo:

1. Download this repository (green **Code** button → Download ZIP) and unzip it.
2. Open `chrome://extensions` (or `brave://extensions`), enable **Developer mode**.
3. Click **Load unpacked** and choose the `extension/` folder.

Click the extension icon to see every tab that's playing audio, each with its own slider, mute and play/pause. Paused tabs stay in the list so you can bring them back.

## Good to know

- **Volume goes down, not up.** SoundBar attenuates; it won't boost past 100% or distort your audio.
- **Setting a slider back to 100% steps SoundBar out of the way completely** — audio flows directly from the app to your speakers again.
- **Why can't the Mac app separate browser tabs?** macOS sees a browser as a single audio source. That's exactly what SoundBar Tabs is for.
- **Privacy:** no accounts, no analytics, no network requests, in the app or the extension ([extension privacy policy](extension/PRIVACY.md)).

## For developers

Built in Swift on Apple's official [Core Audio process tap API](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) (macOS 14+): lowering a slider creates a tap that mutes the app's direct output and replays its audio at your chosen gain, in one realtime callback. Restoring 100% destroys the tap. The extension is vanilla Manifest V3, no build step.

```bash
git clone https://github.com/malenitaa/soundbar.git
cd soundbar
./scripts/build-app.sh
open dist/SoundBar.app
```

Issues and PRs welcome.

## Enjoyed it?

If this was useful and you'd like to support the project:

- [Cafecito](https://cafecito.app/rezamalena)
- [Ko-fi](https://ko-fi.com/malenitaa)

## License

[MIT](LICENSE)
