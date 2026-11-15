// node --test test/extension/popup.test.js   (sin dependencias, sin tocar popup.js)
// popup.js es un script clásico con chrome/document globales y llama a init()
// al cargarse: lo corremos con node:vm contra stubs mínimos.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const SOURCE = fs.readFileSync(path.join(__dirname, "..", "..", "extension", "popup.js"), "utf8");

class El {
  constructor(tag) {
    this.tag = tag; this.children = []; this.listeners = {}; this.className = "";
    this.textContent = ""; this.hidden = false; this.disabled = false;
    this.classList = { toggle() {} };
  }
  append(...c) { this.children.push(...c); }
  appendChild(c) { this.children.push(c); return c; }
  addEventListener(ev, fn) { this.listeners[ev] = fn; }
  all(tag) { return this.children.flatMap((c) => [c, ...c.all(tag)]).filter((e) => !tag || e.tag === tag); }
}

function load({ tabs = [], stored = {}, scripting, tabsGet, tabsUpdate } = {}) {
  const session = { ...stored };
  const list = new El("div"), empty = new El("p");
  const media = [];
  const window = {};
  const chrome = {
    i18n: { getUILanguage: () => "es" },
    runtime: { getURL: (path) => `chrome-extension://test${path}` },
    storage: { session: {
      get: async (k) => (k === null ? { ...session } : k in session ? { [k]: session[k] } : {}),
      set: async (o) => Object.assign(session, o),
      remove: (k) => { delete session[k]; },
    } },
    tabs: {
      query: async () => [...tabs],
      get: tabsGet || (async (id) => tabs.find((t) => t.id === id) || Promise.reject(new Error("No tab"))),
      update: tabsUpdate || (async () => {}),
    },
    scripting: { executeScript: scripting || (async () => [{ result: false }]) },
  };
  const document = {
    getElementById: (id) => (id === "tabs" ? list : empty),
    createElement: (tag) => new El(tag),
    querySelectorAll: () => media,
    documentElement: {},
  };
  const ctx = vm.createContext({ chrome, document, window, MutationObserver: class { observe() {} }, Number, Math, Promise, console });
  vm.runInContext(SOURCE, ctx);
  return { ctx, list, empty, session, media, window };
}
const tick = () => new Promise((r) => setImmediate(r));

test("applyVolume deja el volumen en [0,1] con valores que cruzaron la serialización", () => {
  for (const [input, esperado] of [[2, 1], [-1, 0], [Infinity, 1], [-Infinity, 0], ["0.5", 0.5], [null, 0], [undefined, 0], [{}, 0]]) {
    const { ctx, window, media } = load();
    const el = { volume: -1 }; media.push(el);
    ctx.applyVolume(input);
    assert.equal(window.__soundbarVolume, esperado, `entrada ${String(input)}`);
    assert.ok(el.volume >= 0 && el.volume <= 1);
  }
});

test("applyVolume con NaN no silencia: Number(NaN)||0 da 0 (documenta)", () => {
  const { ctx, window } = load();
  ctx.applyVolume(NaN);
  assert.equal(window.__soundbarVolume, 0);
});

test("el título hostil va como texto, nunca como HTML", async () => {
  const titulos = ['<img src=x onerror=alert(1)>', "'; DROP TABLE tabs;--", "‮txet lanoitcerid", "\u0000\n\n".repeat(50), "x".repeat(10000), "á".repeat(500)];
  for (const title of titulos) {
    const { list } = load({ tabs: [{ id: 1, title, url: "https://a.example", mutedInfo: {} }] });
    await tick(); await tick(); await tick();
    const spans = list.all("span").filter((s) => s.className === "title");
    assert.equal(spans.length, 1);
    assert.equal(spans[0].textContent, title);
  }
});

test("pestaña sin título ni favicon usa la url y no tira", async () => {
  const { list } = load({ tabs: [{ id: 1, title: "", url: "https://a.example", mutedInfo: {} }] });
  await tick(); await tick(); await tick();
  assert.equal(list.all("span").find((s) => s.className === "title").textContent, "https://a.example");
});

test("favicon: sale del caché local del navegador, nunca de la url que elige la página", async () => {
  for (const [url, fav, debeHaber] of [
    ["https://a/p", "https://tracker.example/x.png?id=1", true],
    ["http://a/p", undefined, true],
    ["javascript:alert(1)", "javascript:alert(1)", false],
    ["chrome://settings", undefined, false],
    [undefined, "https://a/x.png", false],
  ]) {
    const { list } = load({ tabs: [{ id: 1, title: "t", url, favIconUrl: fav, mutedInfo: {} }] });
    await tick(); await tick(); await tick();
    const imgs = list.all("img");
    assert.equal(imgs.length, debeHaber ? 1 : 0, String(url));
    if (debeHaber) {
      assert.ok(imgs[0].src.startsWith("chrome-extension://test/_favicon/?pageUrl="), imgs[0].src);
      assert.ok(!imgs[0].src.includes("tracker.example/x.png"), "usó favIconUrl");
    }
  }
});

test("estado guardado con volumen fuera de rango no rompe el slider", async () => {
  for (const volume of [5, -3, "abc", null]) {
    const { list } = load({ tabs: [{ id: 1, title: "t", url: "https://a", mutedInfo: {} }], stored: { "tab-1": { volume } } });
    await tick(); await tick(); await tick();
    const slider = list.all("input")[0];
    const n = Number(slider.value);
    assert.ok(Number.isFinite(n) && n >= 0 && n <= 100, `volume ${volume} dejó slider en ${slider.value}`);
  }
});

test("pestaña cerrada que quedó en storage se limpia y no aparece", async () => {
  const { list, session } = load({ tabs: [], stored: { "tab-99": { volume: 0.5 } } });
  await tick(); await tick(); await tick();
  assert.equal(list.children.length, 0);
  assert.equal("tab-99" in session, false);
});

test("claves tab-<basura> en storage no tiran el popup", async () => {
  const { list, empty } = load({ tabs: [], stored: { "tab-": {}, "tab-abc": {}, "tab--1": {} } });
  await tick(); await tick(); await tick();
  assert.ok(list.children.length === 0 && empty.hidden === false);
});

test("mutear una pestaña que se cerró a mitad de operación no deja una promesa rechazada sin manejar", async () => {
  const tab = { id: 1, title: "t", url: "https://a", mutedInfo: { muted: false } };
  let cerrada = false;
  const { list } = load({
    tabs: [tab],
    tabsGet: async () => { if (cerrada) throw new Error("No tab with id: 1"); return tab; },
  });
  await tick(); await tick(); await tick();
  const muteBtn = list.all("button")[1];
  cerrada = true;
  const rechazos = [];
  const h = (e) => rechazos.push(e);
  process.on("unhandledRejection", h);
  muteBtn.listeners.click();
  await tick(); await tick();
  process.off("unhandledRejection", h);
  assert.equal(rechazos.length, 0, "el click de mute dejó una promesa rechazada");
});

test("mover el slider con la pestaña cerrada (executeScript falla) igual guarda el estado sin tirar", async () => {
  const { list, session } = load({
    tabs: [{ id: 1, title: "t", url: "https://a", mutedInfo: {} }],
    scripting: async () => { throw new Error("No tab with id: 1"); },
  });
  await tick(); await tick(); await tick();
  const slider = list.all("input")[0];
  slider.value = "30";
  await slider.listeners.input();
  assert.equal(session["tab-1"].volume, 0.3);
});

test("togglePlayback sin ningún medio devuelve false", () => {
  const { ctx } = load();
  assert.equal(ctx.togglePlayback(), false);
});

test("togglePlayback: pausar y reanudar vuelve al mismo estado, aunque play() rechace", () => {
  const { ctx, media, window } = load();
  const el = { paused: false, ended: false, pause() { this.paused = true; }, play() { this.paused = false; return Promise.reject(new Error("NotAllowed")); } };
  media.push(el);
  assert.equal(ctx.togglePlayback(), false);
  assert.equal(el.paused, true);
  assert.equal(ctx.togglePlayback(), true);
});
