const es = (chrome.i18n.getUILanguage() || "").startsWith("es");
const t = {
  empty: es ? "Ninguna pestaña está reproduciendo audio" : "No tabs are playing audio",
  reset: es ? "Restablecer" : "Reset",
  mute: es ? "Silenciar pestaña" : "Mute tab",
  unmute: es ? "Reactivar pestaña" : "Unmute tab",
  play: es ? "Reproducir" : "Play",
  pause: es ? "Pausar" : "Pause",
};

// ---- Per-tab state (volume + whether the user touched this tab) ----------
// storage.session clears on browser restart, which is exactly the lifetime
// we want: tab ids aren't stable across restarts anyway.

async function getState(tabId) {
  const key = `tab-${tabId}`;
  const stored = await chrome.storage.session.get(key);
  return stored[key] ?? { volume: 1 };
}

async function setState(tabId, patch) {
  const key = `tab-${tabId}`;
  const state = { ...(await getState(tabId)), ...patch };
  await chrome.storage.session.set({ [key]: state });
  return state;
}

// ---- Functions injected into the page (MAIN world) -----------------------

// Sets the volume on every current and future <audio>/<video> element.
// Web Audio-based players are out of reach from here, but the big ones
// (YouTube, Meet, Spotify Web) all use media elements for output.
function applyVolume(volume) {
  window.__soundbarVolume = volume;
  const apply = () => {
    document.querySelectorAll("audio, video").forEach((el) => {
      el.volume = window.__soundbarVolume;
    });
  };
  apply();
  if (!window.__soundbarObserver) {
    window.__soundbarObserver = new MutationObserver(apply);
    window.__soundbarObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
    });
  }
}

// Pauses whatever is playing, or resumes what we paused. Returns the new
// "is playing" state for this frame.
function togglePlayback() {
  const media = [...document.querySelectorAll("audio, video")];
  const playing = media.filter((el) => !el.paused && !el.ended);
  if (playing.length > 0) {
    window.__soundbarPausedElements = playing;
    playing.forEach((el) => el.pause());
    return false;
  }
  const toResume = window.__soundbarPausedElements?.length
    ? window.__soundbarPausedElements
    : media;
  toResume.forEach((el) => el.play().catch(() => {}));
  window.__soundbarPausedElements = null;
  return toResume.length > 0;
}

function isAnyMediaPlaying() {
  return [...document.querySelectorAll("audio, video")].some(
    (el) => !el.paused && !el.ended && el.readyState > 2
  );
}

// ---- Popup logic ---------------------------------------------------------

async function runInTab(tabId, func, args = []) {
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId, allFrames: true },
      world: "MAIN",
      func,
      args,
    });
    return results.some((frame) => frame.result === true);
  } catch {
    return false;
  }
}

function iconButton(label, title) {
  const button = document.createElement("button");
  button.textContent = label;
  button.title = title;
  return button;
}

async function render(list, tab) {
  const state = await getState(tab.id);
  const playing = await runInTab(tab.id, isAnyMediaPlaying);
  const muted = tab.mutedInfo?.muted ?? false;

  const container = document.createElement("div");
  container.className = "tab";

  const head = document.createElement("div");
  head.className = "tab-head";
  if (tab.favIconUrl && tab.favIconUrl.startsWith("http")) {
    const img = document.createElement("img");
    img.src = tab.favIconUrl;
    head.appendChild(img);
  }
  const title = document.createElement("span");
  title.className = "title";
  title.textContent = tab.title || tab.url;

  const playPause = iconButton(playing ? "⏸︎" : "▶︎", playing ? t.pause : t.play);
  playPause.addEventListener("click", async () => {
    await setState(tab.id, {});
    const nowPlaying = await runInTab(tab.id, togglePlayback);
    playPause.textContent = nowPlaying ? "⏸︎" : "▶︎";
    playPause.title = nowPlaying ? t.pause : t.play;
  });

  const pct = document.createElement("span");
  pct.className = "pct";
  head.append(title, playPause, pct);

  const row = document.createElement("div");
  row.className = "row";

  const muteButton = iconButton(muted ? "🔇" : "🔊", muted ? t.unmute : t.mute);
  muteButton.classList.toggle("active", muted);
  muteButton.addEventListener("click", async () => {
    const tabNow = await chrome.tabs.get(tab.id);
    const newMuted = !(tabNow.mutedInfo?.muted ?? false);
    await chrome.tabs.update(tab.id, { muted: newMuted });
    await setState(tab.id, {});
    muteButton.textContent = newMuted ? "🔇" : "🔊";
    muteButton.title = newMuted ? t.unmute : t.mute;
    muteButton.classList.toggle("active", newMuted);
  });

  const slider = document.createElement("input");
  slider.type = "range";
  slider.min = "0";
  slider.max = "100";
  const reset = iconButton("↺", t.reset);
  row.append(muteButton, slider, reset);

  const updateVolume = (volume) => {
    slider.value = String(Math.round(volume * 100));
    pct.textContent = `${Math.round(volume * 100)}%`;
    reset.disabled = volume >= 0.995;
  };
  updateVolume(state.volume);

  slider.addEventListener("input", async () => {
    const volume = Number(slider.value) / 100;
    updateVolume(volume);
    await runInTab(tab.id, applyVolume, [volume]);
    await setState(tab.id, { volume });
  });
  reset.addEventListener("click", async () => {
    updateVolume(1);
    await runInTab(tab.id, applyVolume, [1]);
    await setState(tab.id, { volume: 1 });
  });

  container.append(head, row);
  list.appendChild(container);
}

async function init() {
  const tabs = await chrome.tabs.query({ audible: true });

  // Also show tabs the user already touched (paused, muted, or adjusted):
  // a paused tab stops being "audible" but must not vanish from the panel.
  const stored = await chrome.storage.session.get(null);
  for (const key of Object.keys(stored)) {
    if (!key.startsWith("tab-")) continue;
    const id = Number(key.slice(4));
    if (tabs.some((tab) => tab.id === id)) continue;
    try {
      tabs.push(await chrome.tabs.get(id));
    } catch {
      chrome.storage.session.remove(key);
    }
  }

  const list = document.getElementById("tabs");
  const empty = document.getElementById("empty");
  if (tabs.length === 0) {
    empty.textContent = t.empty;
    empty.hidden = false;
    return;
  }
  for (const tab of tabs) {
    await render(list, tab);
  }
}

init();
