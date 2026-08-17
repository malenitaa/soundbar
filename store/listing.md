# Chrome Web Store — material de publicación

Todo lo que pide el formulario del store, listo para copiar y pegar.
El ZIP a subir se genera con `scripts/pack-extension.sh` (queda en `dist/`).

## Datos básicos

| Campo | Valor |
|---|---|
| Name | SoundBar Tabs |
| Category | Tools |
| Language | English (agregar español con los textos de abajo) |
| Homepage URL | https://github.com/malenitaa/soundbar |
| Privacy policy URL | https://github.com/malenitaa/soundbar/blob/main/extension/PRIVACY.md |

## Summary (máx. 132 caracteres)

**EN:**
> Per-tab volume, mute and pause. Lower a noisy tab without touching your call.

**ES:**
> Volumen, mute y pausa por pestaña. Bajá la pestaña ruidosa sin tocar tu llamada.

## Description

**EN:**

```
Your browser mixes every tab into one volume. SoundBar Tabs un-mixes them.

Click the icon to see every tab that's currently playing audio, each with
its own controls:

• Volume slider — lower YouTube to 30% while your Meet call stays at 100%
• Mute — one click, using the browser's native tab muting
• Play/pause — pause a tab's media without hunting for it

Paused or muted tabs stay in the list so you can always bring them back.

Private by design: no accounts, no analytics, no network requests, nothing
leaves your machine. Open source — audit it or contribute at
https://github.com/malenitaa/soundbar

Part of the SoundBar project, which also includes a free macOS menu bar
mixer for per-app volume.
```

**ES:**

```
Tu navegador mezcla todas las pestañas en un solo volumen. SoundBar Tabs
las separa.

Un click en el ícono te muestra todas las pestañas que están reproduciendo
audio, cada una con sus propios controles:

• Slider de volumen — bajá YouTube al 30% mientras tu llamada de Meet
  sigue al 100%
• Mute — un click, usando el silenciador nativo de pestañas
• Play/pausa — pausá el audio de una pestaña sin ir a buscarla

Las pestañas pausadas o muteadas quedan en la lista para que siempre
puedas recuperarlas.

Privada por diseño: sin cuentas, sin analytics, sin pedidos de red, nada
sale de tu máquina. Código abierto en https://github.com/malenitaa/soundbar

Parte del proyecto SoundBar, que también incluye un mixer gratuito de
barra de menú para macOS con volumen por app.
```

## Single purpose description (pestaña "Privacy" del formulario)

> Control the audio of individual browser tabs: adjust volume, mute, and
> play/pause the media of each tab that is playing sound.

## Justificación de permisos (los pide uno por uno)

- **tabs**: "Needed to list the tabs currently playing audio (title, icon,
  audible and muted state) and to toggle native tab muting."
- **scripting**: "Needed to adjust the volume of, and play/pause, the media
  elements of a tab when the user moves that tab's slider or presses its
  buttons."
- **storage**: "Stores the user's per-tab volume choices locally in session
  storage so sliders keep their position while the browser is open. No data
  leaves the device."
- **Host permission `<all_urls>`**: "Audio can play on any website, so the
  extension must be able to adjust media volume on whichever site the user's
  audible tabs are on. It only ever runs in response to a user action in the
  popup."
- **remote code**: No, the extension does not use remote code.

## Data usage (checkboxes)

Marcar que NO se recolecta ningún tipo de dato. Certificar los tres
compromisos de la Developer Program Policy (no vender datos, etc.) — todos
se cumplen porque no se recolecta nada.

## Assets

- `store/screenshot-1.png` — 1280×800, captura principal (obligatoria).
- `store/promo-small.png` — 440×280, tile promocional (opcional pero
  recomendado: aparece en las grillas del store).
- Ícono 128px: lo toma del ZIP (`icon128.png`).

## Pasos para publicar (una sola vez)

1. Entrar a https://chrome.google.com/webstore/devconsole con tu cuenta de
   Google y pagar el registro de desarrollador (US$5, única vez).
2. "New item" → subir el ZIP de `dist/`.
3. Pegar los textos de arriba en Store listing (EN, y agregar ES si querés).
4. En Privacy: single purpose + justificaciones + URL de privacidad +
   checkboxes de "no data collected".
5. Subir screenshot y promo tile.
6. Submit for review. Suele tardar de 1 a 3 días; llega mail cuando aprueba.

Al aprobar, cualquiera la encuentra buscando "SoundBar Tabs" en
chromewebstore.google.com (sirve para Chrome, Brave, Edge y Opera).
