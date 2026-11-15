# SoundBar — specification

**Status:** current · **Last review:** 15/11/2026 · Written from the code and the README on that date. Lines marked `[to confirm]` were deduced from the code and are not stated anywhere else.

## 1. What it is and who it's for

A per-app volume mixer for the macOS menu bar, plus a Chrome extension for per-tab volume. It's for people who want to lower one sound source, such as music during a call, without touching the others. A Mac has no built-in way to do that.

## 2. What it does

**Mac app (SoundBar)**

1. Lists the apps that are playing sound, one row each, with name and icon. Helper processes are grouped under the app the user recognizes: Chrome's audio service shows as Chrome, Safari's WebKit process as Safari, and FaceTime's call daemons as FaceTime.
2. Lowers any listed app from 100 % down to 0 % with a slider, without affecting the others.
3. Mutes and unmutes an app with one click, restoring the previous level.
4. Resets an app to 100 %, which hands its audio straight back to the system.
5. Play/pause for Spotify, Apple Music and Apple TV.
6. Keeps paused apps listed for up to 30 minutes while their process is alive.
7. Follows a change of the default output device without losing the levels already set.
8. Two panel finishes, glass and solid. The choice is remembered across launches.
9. English or Spanish, following the system language.

**Browser extension (SoundBar Tabs)**

10. Lists the tabs that are playing audio, plus the ones paused or adjusted from the popup in this browser session.
11. Per-tab volume (0–100 %), mute (the browser's own tab mute) and play/pause of the page's media elements.
12. Remembers per-tab volumes until the browser closes.

## 3. What it doesn't do (on purpose)

- **No boost above 100 %.** It only attenuates, so it never clips. *(README, "Things that look like bugs")*
- **No per-tab control in the Mac app.** macOS sees a browser as one audio source; that's what the extension is for.
- **No network, no accounts, no telemetry, no update check** in either piece. *(SECURITY.md)*
- **No recording.** Audio only exists inside the realtime callback.
- **No drivers or kernel extensions.** Only public Core Audio process taps (macOS 14.4+).
- **No per-app output device choice and no master volume.** The system menu already has the master volume. `[to confirm]`
- **Per-app levels aren't saved.** When SoundBar or the app quits, that app is back at 100 %. `[to confirm]` See the parity table.

## 4. Non-negotiable principles

Changing any of these needs an ADR:

- Zero network and zero third-party code (no dependencies) in the app and the extension.
- At 100 % the tap is destroyed: SoundBar is completely out of the audio path.
- Taps and aggregate devices are private and die with the process, so a crash never leaves an app muted.
- Nothing from outside (process names, bundle IDs, tab titles) reaches an interpreter: the AppleScript bundle ID passes a hardcoded allowlist, and the popup writes with `textContent` only.
- Uninstalling leaves at most one preferences file.

## 5. Acceptance criteria

| # | Given | When | Then | Test |
|---|---|---|---|---|
| CA-1 | a tapped app and a stereo output | the IOProc runs at gain *g* | each output channel is the tap's channel × *g* | `TapMixerTests.stereoOutput` |
| CA-2 | an output device that also has inputs (headset, interface) | the IOProc runs | the tap is played, not the device's input | `TapMixerTests.outputDeviceWithItsOwnInputPlaysTheTapNotTheMic` |
| CA-3 | a mono, multichannel or non-interleaved output | the IOProc runs | L and R land in the first two channels (averaged for mono), the rest is silent | `TapMixerTests.monoOutputGetsTheAverage`, `.multichannelInterleavedOutput`, `.nonInterleavedOutput` |
| CA-4 | no tap buffer in the input | the IOProc runs | the output is silence | `TapMixerTests.noTapInputIsSilence` |
| CA-5 | an app at 50 % | SoundBar is killed (`kill -9`) | the app is back at full volume within 1 s | — (verified by hand, spike #1: RMS 0.106 → 0.212) |
| CA-6 | any volume request, including out-of-range values | `setVolume` | the stored level is clamped to [0, 1] (NaN → 0), and ≥ 0.999 snaps to 100 % with no tap | `ModeloTests.volumenesImposiblesQuedanEnRango`, `.volumenNaNQuedaEnCero`, `.casiCienPorCientoSeAjustaACien` |
| CA-7 | an app at *v* > 0 | mute, then unmute | it's at 0, then back at *v* | `ModeloTests.silenciarYReactivarDevuelveElVolumenPrevio`, `.resetEnMuteVuelveACienYElSiguienteToggleSilencia` |
| CA-8 | helper processes (`com.google.Chrome.helper`, `com.apple.avconferenced`) | apps are grouped | they share their app's slider | `TapMixerPeorCasoTests.rootBundleIDQuitaUnSoloSufijo`, `.canonicalBundleIDMapeaLosDemoniosDeFaceTime`, `.helperDeUnDemonioAliasadoTerminaEnFaceTime` |
| CA-9 | SoundBar's own audio output | apps are discovered | SoundBar never lists or taps itself | — |
| CA-10 | a bundle ID outside Spotify, Music and TV | play/pause is requested | nothing runs | `TapMixerPeorCasoTests.reproduccionSoloPermiteLaAllowlist` |
| CA-11 | a tab titled `<img src=x onerror=alert(1)>` | the popup renders | the title shows as literal text | `test/extension/popup.test.js`: "el título hostil va como texto…" |
| CA-12 | a volume value outside [0, 1], or not a number, reaching the page or read back from storage | `applyVolume` runs / the popup renders | the volume is clamped to [0, 1] | `popup.test.js`: "applyVolume deja el volumen en [0,1]…", "estado guardado con volumen fuera de rango…" |
| CA-13 | play/pause on Spotify or Music from the panel | the user clicks | the player toggles (one-time automation prompt) | — (verified by hand, spike #1) |

## 6. Edge cases and errors

- **Audio permission denied:** the tap captures silence while the app stays muted, so the slider *mutes* instead of lowering. INSTALL.md explains how to grant it. The app doesn't detect this. `[to confirm]` whether it should.
- **Tap creation fails** (no output device, Core Audio error): the slider goes back to 100 % and the error goes to the system log.
- **The tapped app quits:** its tap is destroyed and its level forgotten on the next refresh (every 2 s). Test: `ModeloTests.unaAppQueDesapareceSuelta_suEstadoEnElRefresh`.
- **A tab closes while the popup is open:** mute does nothing instead of throwing. Test: `popup.test.js`, "mutear una pestaña que se cerró…".
- **The default output changes:** every tap is rebuilt against the new device.
- **The device's stereo pair isn't channels 1–2:** SoundBar always uses 1–2. Known limitation (PR #3).
- **Sleep and wake, and an output device unplugged while tapped:** not verified.
- **Extension, players that are pure Web Audio:** the slider doesn't reach them; mute always works.

## 7. Parity with the reference

The README frames SoundBar as the Mac's missing equivalent of the Windows volume mixer. Background Music was the free tool the author used before. `[to confirm]` that these are the right references.

| Behavior of the reference | SoundBar? | Decision |
|---|---|---|
| One slider per app that's playing | yes | goes |
| Mute per app | yes | goes |
| Boost above 100 % (Background Music) | no | not on purpose (§3) |
| Remembers each app's level across restarts (Windows) | no | missing `[to confirm]` → #13 |
| Starts at login (Background Music) | no | missing → #12 |
| Survives the output device changing | yes | goes |
| Survives sleep/wake | not verified | missing check → #14 |
| Per-app output device (Windows) | no | not on purpose `[to confirm]` |
| "System sounds" slider (Windows) | no | out of scope for now |
| Uninstall leaves nothing behind (Background Music left an orphaned driver) | yes: one prefs plist | goes |

## 8. Out of scope for now

- Safari version of the extension (Safari doesn't support `tabs.query({audible})`).
- A "System sounds" slider.
- App Sandbox and notarization (see SECURITY.md, "What's less proven").
