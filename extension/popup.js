const es = (chrome.i18n.getUILanguage() || "").startsWith("es");
const t = {
  empty: es ? "Ninguna pestaña está reproduciendo audio" : "No tabs are playing audio",
  reset: es ? "Restablecer" : "Reset",
};

// Runs inside the page (MAIN world). Sets the volume on every current and
// future <audio>/<video> element. Web Audio-based players are out of reach
// from here, but the big ones (YouTube, Meet, Spotify Web) all use media
// elements for output.
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

async function setTabVolume(tabId, volume) {
  await chrome.scripting.executeScript({
    target: { tabId, allFrames: true },
    world: "MAIN",
    func: applyVolume,
    args: [volume],
  });
  await chrome.storage.session.set({ [`vol-${tabId}`]: volume });
}

function render(tab, savedVolume) {
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
  const pct = document.createElement("span");
  pct.className = "pct";
  head.append(title, pct);

  const row = document.createElement("div");
  row.className = "row";
  const slider = document.createElement("input");
  slider.type = "range";
  slider.min = "0";
  slider.max = "100";
  const reset = document.createElement("button");
  reset.textContent = "↺";
  reset.title = t.reset;
  row.append(slider, reset);

  const update = (volume) => {
    slider.value = String(Math.round(volume * 100));
    pct.textContent = `${Math.round(volume * 100)}%`;
    reset.disabled = volume >= 0.995;
  };
  update(savedVolume);

  slider.addEventListener("input", () => {
    const volume = Number(slider.value) / 100;
    update(volume);
    setTabVolume(tab.id, volume);
  });
  reset.addEventListener("click", () => {
    update(1);
    setTabVolume(tab.id, 1);
  });

  container.append(head, row);
  return container;
}

async function init() {
  const tabs = await chrome.tabs.query({ audible: true });
  const saved = await chrome.storage.session.get(null);
  const adjustedIds = new Set(
    Object.keys(saved)
      .filter((key) => key.startsWith("vol-") && saved[key] < 0.995)
      .map((key) => Number(key.slice(4)))
  );

  // Also show currently-silent tabs the user already adjusted, so they can
  // always bring the volume back up.
  for (const id of adjustedIds) {
    if (!tabs.some((tab) => tab.id === id)) {
      try {
        tabs.push(await chrome.tabs.get(id));
      } catch {
        // Tab was closed; ignore.
      }
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
    list.appendChild(render(tab, saved[`vol-${tab.id}`] ?? 1));
  }
}

init();
