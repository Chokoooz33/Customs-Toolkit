import { t, getLang, setLang, applyDocumentLang } from "./i18n.js";
import { icon } from "./icons.js";
import { D, Dec } from "./decimal.js";
import {
  CONFIG, CURRENCIES, currency, calculateDuty, parsePercentage, calculateDifference,
  UNIT_PAIRS, UNIT_DIRS, convertUnit, awbDigits, awbFormatted, airlineFor, TRANSOM_URL,
} from "./calc.js";
import { loadTariff, tariffState, searchTariff, formatHS, normalizeHS, findByCode, getItem } from "./tariff.js";
import * as cloud from "./cloud.js";
import { APP_VERSION } from "./config.js";

// ============================================================ state

const LOCAL_SETTINGS_KEY = "customs_toolkit_settings_v1";
const GOLD_CACHE_KEY = "customs_toolkit.gold_price_snapshot.v1";

const app = {
  session: null,
  profile: null,
  settings: readLocal(LOCAL_SETTINGS_KEY) ?? { appearance: "system", service_area: null },
  recent: [],
  shipments: [],
  calcs: [],
  authMode: "signin",
  installEvent: null,
};

const root = document.getElementById("app");
const tabbar = document.getElementById("tabbar");

function readLocal(key) {
  try { return JSON.parse(localStorage.getItem(key)); } catch { return null; }
}
function writeLocal(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch {}
}

const esc = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const $ = (sel, el = root) => el.querySelector(sel);
const $$ = (sel, el = root) => [...el.querySelectorAll(sel)];
const userId = () => app.session?.user?.id;
const omr = (d) => (d ? `${d.toFixed(3)} OMR` : "—");

let toastTimer;
function toast(msg) {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 2200);
}

async function copyText(text, msg = t("copied")) {
  try { await navigator.clipboard.writeText(text); toast(msg); } catch { toast(t("error_generic")); }
}

function reportError(err) {
  console.error(err);
  toast(err?.message || t("error_generic"));
}

// ============================================================ settings / theme

function applyTheme() {
  const a = app.settings.appearance;
  if (a === "light" || a === "dark") document.documentElement.dataset.theme = a;
  else delete document.documentElement.dataset.theme;
  const dark = a === "dark" || (a !== "light" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.querySelector('meta[name="theme-color"]').content = dark ? "#04172d" : "#07264a";
}

async function updateSettings(patch) {
  app.settings = { ...app.settings, ...patch };
  writeLocal(LOCAL_SETTINGS_KEY, app.settings);
  applyTheme();
  if (userId()) {
    cloud.saveSettings(userId(), {
      language: getLang(),
      appearance: app.settings.appearance,
      service_area: app.settings.service_area,
    }).catch(reportError);
  }
}

// ============================================================ shared UI pieces

function pageHead(title, { back = false, large = false, actions = "" } = {}) {
  return `<header class="page-head ${large ? "large" : ""}">
    ${back ? `<button class="icon-btn" data-back aria-label="Back">${icon("back", 20, 'class="flip"')}</button>` : ""}
    <h1>${esc(title)}</h1>${actions}
  </header>`;
}

function seg(name, options, value) {
  return `<div class="seg" role="radiogroup" data-seg="${name}">${options
    .map(([v, label]) => `<button type="button" role="radio" aria-checked="${v === value}" class="${v === value ? "on" : ""}" data-v="${esc(v)}">${esc(label)}</button>`)
    .join("")}</div>`;
}

function bindSeg(name, onChange, el = root) {
  const g = el.querySelector(`[data-seg="${name}"]`);
  g?.addEventListener("click", (e) => {
    const b = e.target.closest("button[data-v]");
    if (!b) return;
    g.querySelectorAll("button").forEach((x) => { x.classList.toggle("on", x === b); x.setAttribute("aria-checked", x === b); });
    onChange(b.dataset.v);
  });
}

function currencySelect(name, value) {
  const ar = getLang() === "ar";
  return `<select class="input" data-cur="${name}" aria-label="${esc(t("duty_currency"))}">${CURRENCIES.map(
    (c) => `<option value="${c.code}" ${c.code === value ? "selected" : ""}>${c.code} · ${esc(ar ? c.ar : c.en)}</option>`
  ).join("")}</select>`;
}

function toolCard(route, iconName, title, desc) {
  return `<button class="card tool-card" data-go="${route}">
    <span class="tool-icon">${icon(iconName, 24)}</span>
    <span class="grow"><h3>${esc(title)}</h3><p>${esc(desc)}</p></span>
    <span class="chev">${icon("chev", 18, 'class="flip"')}</span>
  </button>`;
}

function miniTool(route, iconName, title) {
  return `<button class="card mini-tool" data-go="${route}"><span class="tool-icon">${icon(iconName, 20)}</span><b>${esc(title)}</b></button>`;
}

function emptyState(iconName, title, desc) {
  return `<div class="empty"><span class="tool-icon lg">${icon(iconName, 30)}</span><h3>${esc(title)}</h3><p>${esc(desc)}</p></div>`;
}

function hsRow(it) {
  return `<button class="list-item" data-hs="${it.id}">
    <span class="grow stack-s" style="gap:3px">
      <span class="row" style="gap:8px"><span class="hs-code">${formatHS(it.code)}</span>${it.status === "prohibited" ? `<span class="badge bad">${esc(t("status_prohibited"))}</span>` : ""}</span>
      <span class="hs-desc" dir="rtl">${esc(it.ar ?? "")}</span>
      ${it.en ? `<span class="hs-desc en">${esc(it.en)}</span>` : ""}
    </span>
    <span class="rate-pill">${esc(it.duty ?? "—")}</span>
  </button>`;
}

function bindCommon() {
  $$("[data-go]").forEach((b) => b.addEventListener("click", () => go(b.dataset.go)));
  $$("[data-back]").forEach((b) =>
    b.addEventListener("click", () => (history.length > 1 ? history.back() : go("/tools")))
  );
}

// ============================================================ router

function go(path) {
  location.hash = "#" + path;
}

function currentRoute() {
  const h = location.hash.replace(/^#/, "") || "/home";
  const [path, query = ""] = h.split("?");
  return { path, params: new URLSearchParams(query) };
}

const ROOT_TABS = ["/home", "/tools", "/saved", "/more"];

async function render() {
  window.scrollTo(0, 0);
  applyDocumentLang();
  if (!cloud.configured) return renderNotConfigured();
  if (!cloud.libraryLoaded) return renderLibraryMissing();
  if (app.recovering) return renderRecovery();
  if (!app.session) return renderAuth();
  if (!app.settings.service_area) return renderServiceSelection();

  const { path, params } = currentRoute();
  const isRoot = ROOT_TABS.includes(path);
  renderTabbar(isRoot ? path : null);
  root.classList.toggle("no-tabs", !isRoot);

  const views = {
    "/home": app.settings.service_area === "sea" ? renderSeaHome : renderHome,
    "/tools": renderTools,
    "/saved": renderSaved,
    "/more": renderMore,
    "/tool/duty": renderDuty,
    "/tool/hs": renderHSSearch,
    "/tool/hs-detail": renderHSDetail,
    "/tool/diff": renderDifference,
    "/tool/units": renderUnits,
    "/tool/gold": renderGold,
    "/tool/track": renderTrack,
    "/tool/board": renderBoard,
  };
  if (!views[path]) { go("/home"); return; }
  views[path](params);
}

function renderTabbar(active) {
  if (!active) { tabbar.classList.add("hidden"); return; }
  const items = [["/home", "home", "tab_home"], ["/tools", "grid", "tab_tools"], ["/saved", "bookmark", "tab_saved"], ["/more", "more", "tab_more"]];
  tabbar.innerHTML = items
    .map(([p, ic, k]) => `<button class="${p === active ? "on" : ""}" data-tab="${p}" aria-current="${p === active ? "page" : "false"}">${icon(ic, 21)}<span>${esc(t(k))}</span></button>`)
    .join("");
  tabbar.classList.remove("hidden");
  tabbar.querySelectorAll("[data-tab]").forEach((b) => b.addEventListener("click", () => go(b.dataset.tab)));
}

// ============================================================ auth screens

function brandHero(subtitle = t("app_subtitle")) {
  return `<section class="hero">
    <div class="brand"><img src="icons/brandmark.png" alt="">
      <div><h2>${esc(t("app_name"))}</h2><div class="kicker">CUSTOMS TOOLKIT</div></div>
    </div>
    <p style="margin:12px 0 0;opacity:.85;font-size:14px">${esc(subtitle)}</p>
  </section>`;
}

function langToggle() {
  return `<button class="btn ghost lang-toggle" data-lang-toggle>${icon("globe", 18)} ${getLang() === "ar" ? "English" : "العربية"}</button>`;
}

function bindLangToggle() {
  $("[data-lang-toggle]")?.addEventListener("click", () => {
    setLang(getLang() === "ar" ? "en" : "ar");
    render();
  });
}

function renderNotConfigured() {
  tabbar.classList.add("hidden");
  root.innerHTML = `${langToggle()}<div class="auth-wrap">${brandHero()}
    <div class="notice">${icon("database", 20)}<div><b>${esc(t("auth_not_configured_title"))}</b><br>${esc(t("auth_not_configured_desc"))}</div></div>
  </div>`;
  bindLangToggle();
}

function renderLibraryMissing() {
  tabbar.classList.add("hidden");
  root.innerHTML = `${langToggle()}<div class="auth-wrap">${brandHero()}
    <div class="notice error">${icon("alert", 20)}<div>${esc(t("auth_library_missing"))}</div></div>
    <button class="btn block" data-reload>${icon("refresh", 18)} ${esc(t("reload"))}</button>
  </div>`;
  bindLangToggle();
  $("[data-reload]").addEventListener("click", () => location.reload());
}

function passwordField(name, label, autocomplete) {
  return `<label class="field">${esc(label)}
    <span class="password-wrap"><input class="input" type="password" name="${name}" required minlength="8" autocomplete="${autocomplete}" dir="ltr">
    <button type="button" data-peek aria-label="${esc(t("auth_show_password"))}">${icon("eye", 20)}</button></span>
  </label>`;
}

function renderAuth() {
  tabbar.classList.add("hidden");
  const mode = app.authMode;
  const title = mode === "signup" ? t("auth_sign_up") : mode === "forgot" ? t("auth_forgot") : t("auth_sign_in");
  root.innerHTML = `${langToggle()}<div class="auth-wrap">
    ${brandHero(t("auth_welcome"))}
    <form class="card stack" id="auth-form" novalidate>
      ${mode !== "forgot" ? seg("auth", [["signin", t("auth_sign_in")], ["signup", t("auth_sign_up")]], mode) : `<h2 style="margin:0">${esc(title)}</h2>`}
      ${mode === "signup" ? `<label class="field">${esc(t("auth_full_name"))}<input class="input" name="name" required autocomplete="name"></label>` : ""}
      <label class="field">${esc(t("auth_email"))}<input class="input" type="email" name="email" required autocomplete="email" dir="ltr" inputmode="email"></label>
      ${mode !== "forgot" ? passwordField("password", t("auth_password"), mode === "signup" ? "new-password" : "current-password") : ""}
      ${mode === "signup" ? `<p class="hint">${esc(t("auth_password_rule"))}</p>` : ""}
      <p class="error-text hidden" id="auth-error" role="alert"></p>
      <div class="notice info hidden" id="auth-info"></div>
      <button class="btn block" type="submit">${icon(mode === "forgot" ? "share" : "lock", 18)} ${esc(mode === "signup" ? t("auth_sign_up") : mode === "forgot" ? t("auth_send_reset") : t("auth_sign_in"))}</button>
      ${mode === "signin" ? `<button class="btn ghost" type="button" data-auth="forgot">${esc(t("auth_forgot"))}</button>` : ""}
      ${mode === "forgot" ? `<button class="btn ghost" type="button" data-auth="signin">${esc(t("auth_back_to_sign_in"))}</button>` : ""}
    </form>
  </div>`;
  bindLangToggle();
  bindSeg("auth", (v) => { app.authMode = v; renderAuth(); });
  $$("[data-auth]").forEach((b) => b.addEventListener("click", () => { app.authMode = b.dataset.auth; renderAuth(); }));
  bindPeek();

  const form = $("#auth-form");
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const err = $("#auth-error"), info = $("#auth-info"), btn = form.querySelector('button[type="submit"]');
    err.classList.add("hidden"); info.classList.add("hidden");
    if (!form.checkValidity()) { form.reportValidity(); return; }
    const f = new FormData(form);
    const email = String(f.get("email")).trim();
    btn.disabled = true;
    try {
      if (mode === "signin") {
        await cloud.signIn(email, String(f.get("password")));
      } else if (mode === "signup") {
        const data = await cloud.signUp(email, String(f.get("password")), String(f.get("name")).trim());
        if (!data.session) { info.textContent = t("auth_check_email"); info.classList.remove("hidden"); }
      } else {
        await cloud.sendPasswordReset(email);
        info.textContent = t("auth_reset_sent"); info.classList.remove("hidden");
      }
    } catch (ex) {
      err.textContent = ex.message || t("error_generic");
      err.classList.remove("hidden");
    } finally {
      btn.disabled = false;
    }
  });
}

function bindPeek() {
  $$("[data-peek]").forEach((b) =>
    b.addEventListener("click", () => {
      const input = b.previousElementSibling;
      input.type = input.type === "password" ? "text" : "password";
    })
  );
}

function renderRecovery() {
  tabbar.classList.add("hidden");
  root.innerHTML = `<div class="auth-wrap">${brandHero()}
    <form class="card stack" id="recovery-form">
      <h2 style="margin:0">${esc(t("auth_new_password"))}</h2>
      ${passwordField("password", t("auth_new_password"), "new-password")}
      <p class="hint">${esc(t("auth_password_rule"))}</p>
      <p class="error-text hidden" id="auth-error" role="alert"></p>
      <button class="btn block" type="submit">${esc(t("auth_set_password"))}</button>
    </form></div>`;
  bindPeek();
  $("#recovery-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    if (!form.checkValidity()) { form.reportValidity(); return; }
    try {
      await cloud.updatePassword(String(new FormData(form).get("password")));
      app.recovering = false;
      toast(t("auth_password_updated"));
      go("/home");
      render();
    } catch (ex) {
      const err = $("#auth-error");
      err.textContent = ex.message; err.classList.remove("hidden");
    }
  });
}

// ============================================================ service selection

function renderServiceSelection() {
  tabbar.classList.add("hidden");
  root.classList.add("no-tabs");
  const card = (area, ic, title, desc, badge) => `<button class="card tool-card" data-area="${area}" style="padding:20px;border-radius:24px">
    <span class="tool-icon lg">${icon(ic, 32)}</span>
    <span class="grow stack-s" style="gap:6px"><h3 style="font-size:20px">${esc(title)}</h3><p>${esc(desc)}</p>
      <span class="tiny" style="color:var(--brand-gold);font-weight:800">${esc(badge)}</span></span>
    <span class="chev">${icon("chev", 18, 'class="flip"')}</span></button>`;
  root.innerHTML = `<div class="stack" style="padding-top:calc(24px + env(safe-area-inset-top))">
    ${brandHero()}
    <div><h2 style="margin:0 0 4px">${esc(t("service_choose_title"))}</h2><p class="muted" style="margin:0">${esc(t("service_choose_desc"))}</p></div>
    ${card("air", "plane", t("service_air_title"), t("service_air_desc"), t("service_air_badge"))}
    ${card("sea", "ship", t("service_sea_title"), t("service_sea_desc"), t("service_sea_badge"))}
  </div>`;
  $$("[data-area]").forEach((b) =>
    b.addEventListener("click", async () => {
      await updateSettings({ service_area: b.dataset.area });
      go("/home");
      render();
    })
  );
}

// ============================================================ home

function heroChips() {
  const ts = tariffState();
  return `<div class="chips"><span class="chip">${esc(t("dashboard_oman"))}</span><span class="chip gold">${esc(t("dashboard_tariff_2026"))}</span>
    ${ts.status === "ready" ? `<span class="chip">${esc(t("dashboard_offline"))}</span>` : ""}</div>`;
}

function recentSearchesCard() {
  return `<section class="card stack-s"><div class="row between"><b>${esc(t("dashboard_recent_searches"))}</b>
    ${app.recent.length ? `<button class="btn ghost small" data-clear-recent>${esc(t("clear_history"))}</button>` : ""}</div>
    ${app.recent.length
      ? `<div class="list">${app.recent.map((r) => `<button class="list-item" data-recent="${esc(r.query)}"><span class="hs-code">${esc(formatHS(r.normalized_query))}</span><span class="grow"></span><span class="chev">${icon("chev", 16, 'class="flip"')}</span></button>`).join("")}</div>`
      : `<p class="muted small" style="margin:0">${esc(t("no_recent_searches"))}</p>`}
  </section>`;
}

function bindRecent() {
  $$("[data-recent]").forEach((b) => b.addEventListener("click", () => go("/tool/hs?q=" + encodeURIComponent(b.dataset.recent))));
  $("[data-clear-recent]")?.addEventListener("click", async () => {
    try { await cloud.clearRecentSearches(userId()); app.recent = []; render(); } catch (e) { reportError(e); }
  });
}

function goldMiniCard() {
  const snap = readLocal(GOLD_CACHE_KEY);
  return `<button class="card gold-card stack-s" data-go="/tool/gold" style="text-align:start;width:100%">
    <div class="row between"><b>${esc(t("dashboard_gold_oman"))}</b><span class="badge info">${esc(t("dashboard_gold_karat_24"))}</span></div>
    <div class="row" style="align-items:baseline"><span class="price">${snap ? esc(snap.price24) : "—"}</span><span class="muted small">OMR · ${esc(t("dashboard_gold_per_gram"))}</span></div>
    <span class="muted tiny">${esc(t("dashboard_gold_source"))}</span>
  </button>`;
}

function installCard() {
  const standalone = matchMedia("(display-mode: standalone)").matches || navigator.standalone;
  if (standalone) return "";
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  if (!app.installEvent && !ios) return "";
  return `<section class="card install-banner"><span class="tool-icon">${icon("download", 22)}</span>
    <div class="grow"><b>${esc(t("install_app"))}</b><p class="muted small" style="margin:2px 0 0">${esc(ios ? t("install_ios") : t("install_desc"))}</p></div>
    ${app.installEvent ? `<button class="btn" data-install>${esc(t("install_app"))}</button>` : ""}</section>`;
}

function bindInstall() {
  $("[data-install]")?.addEventListener("click", async () => {
    app.installEvent.prompt();
    await app.installEvent.userChoice;
    app.installEvent = null;
    render();
  });
}

function renderHome() {
  const ts = tariffState();
  root.innerHTML = `${pageHead(t("tab_home"), { large: true })}<div class="stack">
    <section class="hero"><div class="brand"><img src="icons/brandmark.png" alt="">
      <div><h2>${esc(t("app_name"))}</h2><div class="kicker">CUSTOMS TOOLKIT</div></div></div>${heroChips()}</section>
    ${installCard()}
    ${goldMiniCard()}
    <h2 class="section-title">${esc(t("dashboard_primary_tool"))}</h2>
    ${toolCard("/tool/hs", "search", t("tool_hscode_search"), ts.status === "ready" ? t("records_count", ts.items.length) : t("dashboard_tariff_card_desc"))}
    <h2 class="section-title">${esc(t("dashboard_quick_tools"))}</h2>
    <div class="grid-2">
      ${miniTool("/tool/track", "plane", t("tool_air_cargo_tracking"))}
      ${miniTool("/tool/board", "box", t("tool_cargo_board"))}
      ${miniTool("/tool/duty", "money", t("tool_duty_calculator"))}
      ${miniTool("/tool/diff", "percent", t("tool_diff_calculator"))}
      ${miniTool("/tool/units", "scale", t("tool_unit_converter"))}
      ${miniTool("/tool/gold", "chart", t("tool_gold_price"))}
    </div>
    ${recentSearchesCard()}
  </div>`;
  bindCommon(); bindRecent(); bindInstall();
  refreshGold(false).then((changed) => { if (changed && currentRoute().path === "/home") renderHome(); });
}

function renderSeaHome() {
  const ts = tariffState();
  root.innerHTML = `${pageHead(t("service_sea_title"), { large: true })}<div class="stack">
    <section class="hero"><div class="brand"><img src="icons/brandmark.png" alt="">
      <div><h2>${esc(t("service_sea_title"))}</h2><div class="kicker">SEA PORT CLEARANCE</div></div></div>
      <p style="margin:12px 0 0;opacity:.85;font-size:14px">${esc(t("sea_dashboard_subtitle"))}</p>${heroChips()}</section>
    ${installCard()}
    <h2 class="section-title">${esc(t("sea_hs_focus"))}</h2>
    ${toolCard("/tool/hs", "search", t("tool_hscode_search"), ts.status === "ready" ? t("records_count", ts.items.length) : t("sea_hs_card_desc"))}
    ${toolCard("/tool/duty", "money", t("tool_duty_calculator"), t("tool_duty_calculator_desc"))}
    ${toolCard("/tool/units", "scale", t("tool_unit_converter"), t("tool_unit_converter_desc"))}
    ${recentSearchesCard()}
  </div>`;
  bindCommon(); bindRecent(); bindInstall();
}

// ============================================================ tools list

function renderTools() {
  const sea = app.settings.service_area === "sea";
  const cards = sea
    ? [
        ["/tool/hs", "search", "tool_hscode_search", "sea_hs_card_desc"],
        ["/tool/duty", "money", "tool_duty_calculator", "tool_duty_calculator_desc"],
        ["/tool/units", "scale", "tool_unit_converter", "tool_unit_converter_desc"],
      ]
    : [
        ["/tool/track", "plane", "tool_air_cargo_tracking", "tool_air_cargo_tracking_desc"],
        ["/tool/board", "box", "tool_cargo_board", "tool_cargo_board_desc"],
        ["/tool/units", "scale", "tool_unit_converter", "tool_unit_converter_desc"],
        ["/tool/hs", "search", "tool_hscode_search", "tool_hscode_search_desc"],
        ["/tool/diff", "percent", "tool_diff_calculator", "tool_diff_calculator_desc"],
        ["/tool/duty", "money", "tool_duty_calculator", "tool_duty_calculator_desc"],
        ["/tool/gold", "chart", "tool_gold_price", "tool_gold_price_desc"],
      ];
  root.innerHTML = `${pageHead(sea ? t("service_sea_title") : t("tab_tools"), { large: true })}<div class="stack">
    ${cards.map(([r, ic, k, d]) => toolCard(r, ic, t(k), t(d))).join("")}</div>`;
  bindCommon();
}

// ============================================================ HS search & detail

let hsTimer;
function renderHSSearch(params) {
  const ts = tariffState();
  const initial = params.get("q") ?? "";
  root.innerHTML = `${pageHead(t("tool_hscode_search"), { back: true })}<div class="stack">
    <div class="stack-s">
      <input class="input" id="hs-q" type="search" placeholder="${esc(t("hs_search_placeholder"))}" value="${esc(initial)}" autocomplete="off" enterkeyhint="search">
      <p class="hint">${esc(t("partial_search_hint"))}</p>
    </div>
    <div id="hs-results"></div>
  </div>`;
  bindCommon();
  const input = $("#hs-q");
  const run = () => {
    const out = $("#hs-results");
    if (!out) return;
    const q = input.value.trim();
    if (tariffState().status !== "ready") {
      out.innerHTML = tariffState().status === "error"
        ? `<div class="notice error">${icon("alert")}<div>${esc(t("tariff_not_installed_desc"))}</div></div>`
        : `<div class="empty"><span class="spinner"></span><p>${esc(t("loading_tariff"))}</p></div>`;
      return;
    }
    if (!q) {
      out.innerHTML = recentSearchesCard();
      bindRecent();
      return;
    }
    if (q.length < 2 && !normalizeHS(q)) {
      out.innerHTML = emptyState("search", t("search_more_characters_title"), t("search_more_characters_desc"));
      return;
    }
    const res = searchTariff(q, 160);
    if (!res.total) {
      out.innerHTML = emptyState("search", t("no_results_found"), "");
      return;
    }
    out.innerHTML = `<p class="muted small" style="margin:0 4px 8px">${esc(t("hs_results_count", res.total))}${res.truncated ? " · " + esc(t("showing_top_results", res.items.length)) : ""}</p>
      <div class="card" style="padding:0 16px"><div class="list">${res.items.map(hsRow).join("")}</div></div>`;
    $$("[data-hs]", out).forEach((b) => b.addEventListener("click", () => openHS(getItem(+b.dataset.hs), input.value.trim())));
  };
  input.addEventListener("input", () => { clearTimeout(hsTimer); hsTimer = setTimeout(run, 120); });
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") input.blur(); });
  if (ts.status !== "ready") loadTariff().then(run, run);
  run();
  if (!initial) input.focus();
}

function openHS(item, query) {
  if (!item) return;
  const q = query || item.code;
  const n = normalizeHS(q);
  if (n && userId()) {
    app.recent = [{ query: q, normalized_query: n }, ...app.recent.filter((r) => r.normalized_query !== n)].slice(0, 10);
    cloud.addRecentSearch(userId(), q, n).catch(reportError);
  }
  go("/tool/hs-detail?code=" + item.code + "&i=" + item.id);
}

function renderHSDetail(params) {
  const ts = tariffState();
  if (ts.status !== "ready") {
    root.innerHTML = `${pageHead(t("hs_detail"), { back: true })}<div class="empty"><span class="spinner"></span></div>`;
    bindCommon();
    loadTariff().then(() => renderHSDetail(params), () => {});
    return;
  }
  const it = getItem(+params.get("i")) ?? findByCode(params.get("code"));
  if (!it) { go("/tool/hs"); return; }
  const kv = (k, v, cls = "") => (v ? `<div class="kv"><span>${esc(k)}</span><b class="${cls}">${esc(v)}</b></div>` : "");
  const hier = (label, code, ar, en) =>
    ar || en
      ? `<div class="stack-s" style="gap:2px;padding:8px 0;border-bottom:1px solid var(--subtle-border)"><span class="tiny muted">${esc(label)} <span class="hs-code">${esc(code)}</span></span>
         ${ar ? `<span dir="rtl">${esc(ar)}</span>` : ""}${en ? `<span class="muted small" dir="ltr">${esc(en)}</span>` : ""}</div>`
      : "";
  root.innerHTML = `${pageHead(t("hs_detail"), { back: true })}<div class="stack">
    <section class="card stack-s">
      <div class="row between"><span class="hs-code" style="font-size:24px">${formatHS(it.code)}</span>
        <span class="badge ${it.status === "prohibited" ? "bad" : "ok"}">${esc(t(it.status === "prohibited" ? "status_prohibited" : "status_normal"))}</span></div>
      ${it.ar ? `<p style="margin:4px 0 0;font-size:18px" dir="rtl">${esc(it.ar)}</p>` : ""}
      ${it.en ? `<p class="muted" style="margin:0" dir="ltr">${esc(it.en)}</p>` : ""}
    </section>
    <section class="card result-card">
      <div class="row between"><span class="muted">${esc(t("duty_rate"))}</span><span class="big-number" style="color:var(--brand-primary)">${esc(it.duty ?? "—")}</span></div>
      ${kv(t("procedure"), it.procedure)}
    </section>
    <div class="btn-row">
      <button class="btn" data-go="/tool/duty?hs=${it.code}&i=${it.id}">${icon("money", 18)} ${esc(t("duty_calculate_for_hs"))}</button>
    </div>
    ${it.status === "prohibited" ? `<div class="notice error">${icon("alert")}<div><b>${esc(t("permit_prohibited"))}</b></div></div>` : ""}
    <section class="card stack-s"><b>${esc(t("permit_requirement"))}</b><p class="muted small" style="margin:0">${esc(t("permit_verification_required"))}</p>
      <a class="btn secondary" href="${CONFIG.omanHSRequirementsURL}" target="_blank" rel="noopener">${icon("external", 18)} ${esc(t("permit_open_official"))}</a>
      <p class="hint">${esc(t("permit_captcha_notice"))}</p></section>
    <section class="card"><b>${esc(t("hierarchy"))}</b>
      ${hier(t("chapter"), it.chapter, it.chapterAr, it.chapterEn)}
      ${hier(t("heading"), it.heading, it.headingAr, it.headingEn)}
      ${hier(t("subheading"), formatHS(it.code.slice(0, 6)), it.subAr, it.subEn)}
    </section>
    <section class="card"><b>${esc(t("trade_agreements"))}</b>
      ${kv(t("indicator_ind"), it.ind, "mono")}${kv(t("indicator_efta"), it.efta, "mono")}${kv(t("indicator_sg"), it.sg, "mono")}${kv(t("indicator_usa"), it.usa, "mono")}
    </section>
    <section class="card">${kv(t("source_reference"), t("official_tariff_source"))}${kv(t("source_page"), it.page ? String(it.page) : "")}</section>
    <div class="btn-row">
      <button class="btn secondary" data-copy-code>${icon("copy", 18)} ${esc(t("copy_hs_code"))}</button>
      <button class="btn secondary" data-copy-desc>${icon("copy", 18)} ${esc(t("copy_description"))}</button>
    </div>
  </div>`;
  bindCommon();
  $("[data-copy-code]").addEventListener("click", () => copyText(it.code));
  $("[data-copy-desc]").addEventListener("click", () => copyText([it.ar, it.en].filter(Boolean).join("\n")));
}

// ============================================================ duty calculator

const dutyState = () => ({
  lookup: "hs_code", term: "CIF", importer: "company", docs: "original",
  hsQuery: "", item: null,
  values: {
    cif: { text: "", currency: "OMR", rate: "" },
    cfr: { text: "", currency: "OMR", rate: "" },
    cost: { text: "", currency: "OMR", rate: "" },
    freight: { text: "", currency: "OMR", rate: "" },
  },
});
let duty = dutyState();

function dutyResult() {
  let dutyRate, isEstimate = false, hsCode = null;
  if (duty.lookup === "quick_estimate") { dutyRate = CONFIG.quickEstimateDutyRate; isEstimate = true; }
  else {
    if (!duty.item) return null;
    dutyRate = parsePercentage(duty.item.duty);
    if (!dutyRate) return null;
    hsCode = duty.item.code;
  }
  const val = (k) => {
    const v = duty.values[k];
    return { amount: Dec.parse(v.text), currency: v.currency, rate: v.currency === "OMR" ? D(1) : Dec.parse(v.rate) };
  };
  return calculateDuty({
    deliveryTerm: duty.term, cif: val("cif"), cfr: val("cfr"), cost: val("cost"), freight: val("freight"),
    dutyRate, importerType: duty.importer, documentStatus: duty.docs, hsCode, isEstimate,
  });
}

function valueField(key, label) {
  const v = duty.values[key];
  const showRate = v.currency !== "OMR";
  return `<div class="stack-s" data-val="${key}">
    <label class="field">${esc(label)}
      <div class="input-row"><input class="input num" inputmode="decimal" data-amount value="${esc(v.text)}" placeholder="0.000">${currencySelect(key, v.currency)}</div>
    </label>
    <div class="stack-s ${showRate ? "" : "hidden"}" data-rate-wrap>
      <label class="field">${esc(t("duty_exchange_rate_to_omr"))}<input class="input num" inputmode="decimal" data-rate value="${esc(v.rate)}" placeholder="${esc(t("duty_exchange_rate_required"))}"></label>
      <p class="hint" data-rate-hint>${esc(t("duty_exchange_rate_hint", v.currency))}</p>
    </div>
  </div>`;
}

function dutyResultHTML(r) {
  if (!r) return "";
  const pct = (d) => `${d.mul(100).toPlain(2)}%`;
  const rows = [
    duty.term === "FOB" || duty.term === "EXW" ? [t("duty_cost_value"), omr(r.costOMR)] : null,
    duty.term === "FOB" || duty.term === "EXW" ? [t("duty_freight_value"), omr(r.freightOMR)] : null,
    duty.term !== "CIF" ? [t("duty_insurance_auto"), omr(r.insuranceOMR)] : null,
    [t("duty_cif_omr"), omr(r.cifOMR)],
    [t("duty_duty_rate"), pct(r.dutyRate)],
    [t("duty_duty_amount"), omr(r.dutyOMR)],
    [t("duty_vat_base"), omr(r.vatBaseOMR)],
    [t("duty_vat_rate"), pct(r.vatRate)],
    [t("duty_vat_amount"), omr(r.vatOMR)],
    [t("duty_total_taxes"), omr(r.totalTaxesOMR)],
    r.documentationGuaranteeOMR.gt(0) ? [t("duty_documentation_guarantee"), omr(r.documentationGuaranteeOMR)] : null,
    [t("duty_bayan_documentation"), omr(r.bayanDocumentationOMR)],
  ].filter(Boolean);
  return `<section class="card result-card" id="duty-report">
    <div class="row between" style="margin-bottom:6px"><b>${esc(t("duty_result_title"))}</b>
      ${r.hsCode ? `<span class="hs-code">${formatHS(r.hsCode)}</span>` : `<span class="badge warn">${esc(t("duty_method_quick"))}</span>`}</div>
    ${rows.map(([k, v]) => `<div class="kv"><span>${esc(k)}</span><b>${esc(v)}</b></div>`).join("")}
    <div class="total"><span>${esc(t("duty_total_payable"))}</span><b>${r.totalPayableOMR.toFixed(3)} OMR</b></div>
    ${r.isEstimate ? `<p class="hint" style="margin-top:10px">${esc(t("duty_estimate_disclaimer"))}</p>` : ""}
  </section>
  <div class="btn-row no-print">
    <button class="btn secondary" data-duty="copy">${icon("copy", 18)} ${esc(t("duty_copy_result"))}</button>
    ${navigator.share ? `<button class="btn secondary" data-duty="share">${icon("share", 18)} ${esc(t("duty_share_result"))}</button>` : ""}
    <button class="btn secondary" data-duty="print">${icon("print", 18)} ${esc(t("duty_print"))}</button>
    <button class="btn" data-duty="save">${icon("save", 18)} ${esc(t("save_calculation"))}</button>
  </div>`;
}

function dutyText(r) {
  const lines = [
    t("duty_report_title"),
    r.hsCode ? `HS: ${formatHS(r.hsCode)}` : t("duty_method_quick"),
    `${t("duty_delivery_term")}: ${r.deliveryTerm}`,
    `${t("duty_cif_omr")}: ${omr(r.cifOMR)}`,
    `${t("duty_duty_amount")}: ${omr(r.dutyOMR)}`,
    `${t("duty_vat_amount")}: ${omr(r.vatOMR)}`,
  ];
  if (r.documentationGuaranteeOMR.gt(0)) lines.push(`${t("duty_documentation_guarantee")}: ${omr(r.documentationGuaranteeOMR)}`);
  lines.push(`${t("duty_bayan_documentation")}: ${omr(r.bayanDocumentationOMR)}`, `${t("duty_total_payable")}: ${omr(r.totalPayableOMR)}`, "", t("duty_generated_by"));
  return lines.join("\n");
}

function renderDuty(params) {
  const hs = params.get("hs");
  if (hs && duty.item?.code !== hs) {
    if (tariffState().status !== "ready") {
      root.innerHTML = `${pageHead(t("tool_duty_calculator"), { back: true })}<div class="empty"><span class="spinner"></span></div>`;
      bindCommon();
      loadTariff().then(() => renderDuty(params), () => {});
      return;
    }
    duty = dutyState();
    duty.item = getItem(+params.get("i")) ?? findByCode(hs);
    duty.hsQuery = duty.item?.code ?? hs;
  }
  if (tariffState().status === "idle") loadTariff().catch(() => {});

  const termHint = { CIF: "duty_cif_hint", CFR: "duty_cfr_hint", FOB: "duty_fob_exw_hint", EXW: "duty_fob_exw_hint" }[duty.term];
  root.innerHTML = `${pageHead(t("tool_duty_calculator"), {
    back: true,
    actions: `<button class="icon-btn" data-duty-reset aria-label="${esc(t("reset"))}">${icon("refresh", 18)}</button>`,
  })}<div class="stack">
    <div class="notice info">${icon("info")}<div><b>${esc(t("duty_import_only"))}</b> — ${esc(t("duty_import_only_desc"))}</div></div>

    <section class="card stack">
      <b>${esc(t("duty_hs_method"))}</b>
      ${seg("lookup", [["hs_code", t("duty_method_hs")], ["description", t("duty_method_description")], ["quick_estimate", t("duty_method_quick")]], duty.lookup)}
      <div id="lookup-area"></div>
    </section>

    <section class="card stack">
      <b>${esc(t("duty_customs_value"))}</b>
      <label class="field">${esc(t("duty_delivery_term"))}${seg("term", ["CIF", "CFR", "FOB", "EXW"].map((x) => [x, x]), duty.term)}</label>
      <p class="hint">${esc(t(termHint))}</p>
      ${duty.term === "CIF" ? valueField("cif", t("duty_cif_value")) : ""}
      ${duty.term === "CFR" ? valueField("cfr", t("duty_cfr_value")) : ""}
      ${duty.term === "FOB" || duty.term === "EXW" ? valueField("cost", t("duty_cost_value")) + valueField("freight", t("duty_freight_value")) : ""}
      ${duty.term !== "CIF" ? `<div class="kv"><span>${esc(t("duty_insurance_auto"))}</span><b data-insurance>—</b></div>` : ""}
    </section>

    <section class="card stack">
      <b>${esc(t("duty_declaration_details"))}</b>
      <label class="field">${esc(t("duty_importer_type"))}${seg("importer", [["company", t("duty_company") + " · 15 OMR"], ["personal", t("duty_personal") + " · 5 OMR"]], duty.importer)}</label>
      <label class="field">${esc(t("duty_documents"))}${seg("docs", [["original", t("duty_documents_original")], ["not_original", t("duty_documents_not_original")]], duty.docs)}</label>
      <p class="hint">${esc(t("duty_guarantee_rule"))}</p>
    </section>

    <div id="duty-result" class="stack"></div>

    <section class="card stack-s no-print"><b>${esc(t("duty_official_source"))}</b><p class="muted small" style="margin:0">${esc(t("duty_official_note"))}</p>
      <a class="btn secondary" href="${CONFIG.omanDutyCalculatorURL}" target="_blank" rel="noopener">${icon("external", 18)} ${esc(t("duty_open_official_calculator"))}</a></section>
  </div>`;
  bindCommon();

  $("[data-duty-reset]").addEventListener("click", () => { duty = dutyState(); go("/tool/duty"); renderDuty(new URLSearchParams()); });
  bindSeg("lookup", (v) => { duty.lookup = v; if (v === "quick_estimate") { duty.item = null; duty.hsQuery = ""; } renderLookup(); updateDuty(); });
  bindSeg("term", (v) => { duty.term = v; renderDuty(new URLSearchParams()); });
  bindSeg("importer", (v) => { duty.importer = v; updateDuty(); });
  bindSeg("docs", (v) => { duty.docs = v; updateDuty(); });

  $$("[data-val]").forEach((wrap) => {
    const key = wrap.dataset.val, v = duty.values[key];
    wrap.querySelector("[data-amount]").addEventListener("input", (e) => { v.text = e.target.value; updateDuty(); });
    wrap.querySelector("[data-rate]").addEventListener("input", (e) => { v.rate = e.target.value; updateDuty(); });
    wrap.querySelector("[data-cur]").addEventListener("change", (e) => {
      v.currency = e.target.value;
      v.rate = v.currency === "OMR" ? "" : currency(v.currency).suggested;
      wrap.querySelector("[data-rate]").value = v.rate;
      wrap.querySelector("[data-rate-wrap]").classList.toggle("hidden", v.currency === "OMR");
      wrap.querySelector("[data-rate-hint]").textContent = t("duty_exchange_rate_hint", v.currency);
      updateDuty();
    });
  });
  renderLookup();
  updateDuty();
}

function renderLookup() {
  const area = $("#lookup-area");
  if (!area) return;
  if (duty.lookup === "quick_estimate") {
    area.innerHTML = `<div class="notice">${icon("alert")}<div><b>${esc(t("duty_quick_estimate_title"))}</b><br>${esc(t("duty_quick_estimate_desc"))}</div></div>`;
    return;
  }
  const placeholder = duty.lookup === "hs_code" ? t("hs_search_placeholder") : t("duty_description_placeholder");
  area.innerHTML = `<div class="suggest">
      <input class="input ${duty.lookup === "hs_code" ? "num" : ""}" id="duty-hs" value="${esc(duty.hsQuery)}" placeholder="${esc(placeholder)}" autocomplete="off" ${duty.lookup === "hs_code" ? 'inputmode="numeric"' : ""}>
      <div id="duty-suggest"></div>
    </div>
    <div id="duty-selected"></div>`;
  const input = $("#duty-hs");
  const update = () => {
    duty.hsQuery = input.value;
    const q = input.value.trim();
    const list = $("#duty-suggest");
    let matches = [];
    if (q.length >= 2 && tariffState().status === "ready") {
      matches = searchTariff(q, 8).items;
      const n = normalizeHS(q);
      const exact = n && matches.find((m) => m.code === n);
      if (exact) duty.item = exact;
      else if (duty.item?.code !== n) duty.item = null;
    } else if (duty.item?.code !== normalizeHS(q)) duty.item = null;
    const showList = matches.length && !(duty.item && duty.item.code === normalizeHS(q));
    list.innerHTML = showList ? `<div class="suggest-list list">${matches.map(hsRow).join("")}</div>` : "";
    $$("[data-hs]", list).forEach((b) =>
      b.addEventListener("click", () => {
        duty.item = getItem(+b.dataset.hs);
        duty.hsQuery = duty.item.code;
        input.value = duty.item.code;
        list.innerHTML = "";
        renderSelected();
        updateDuty();
      })
    );
    renderSelected();
    updateDuty();
  };
  input.addEventListener("input", update);
  if (tariffState().status !== "ready") loadTariff().then(update, () => {});
  renderSelected();
}

function renderSelected() {
  const el = $("#duty-selected");
  if (!el) return;
  const it = duty.item;
  el.innerHTML = it
    ? `<div class="card inner row" style="margin-top:4px"><span class="grow stack-s" style="gap:2px"><span class="hs-code">${formatHS(it.code)}</span>
        <span class="small">${esc((getLang() === "ar" ? it.ar : it.en) || it.ar || it.en || "")}</span></span>
        <span class="rate-pill">${esc(it.duty ?? "—")}</span>
        <button class="icon-btn" data-clear-hs aria-label="${esc(t("clear"))}">${icon("trash", 16)}</button></div>`
    : "";
  el.querySelector("[data-clear-hs]")?.addEventListener("click", () => {
    duty.item = null; duty.hsQuery = "";
    const input = $("#duty-hs");
    if (input) input.value = "";
    renderSelected(); updateDuty();
  });
}

function updateDuty() {
  const r = dutyResult();
  const ins = $("[data-insurance]");
  if (ins) ins.textContent = r ? omr(r.insuranceOMR) : "—";
  const out = $("#duty-result");
  if (!out) return;
  out.innerHTML = dutyResultHTML(r);
  if (!r) return;
  const text = dutyText(r);
  $$("[data-duty]", out).forEach((b) =>
    b.addEventListener("click", async () => {
      const a = b.dataset.duty;
      if (a === "copy") copyText(text, t("duty_copied"));
      else if (a === "share") navigator.share({ title: t("duty_report_title"), text }).catch(() => {});
      else if (a === "print") window.print();
      else if (a === "save") {
        b.disabled = true;
        try {
          await cloud.saveCalculation(userId(), "duty", r.hsCode ? formatHS(r.hsCode) : t("duty_method_quick"), {
            text, total: r.totalPayableOMR.toFixed(3), term: r.deliveryTerm, hs: r.hsCode,
          });
          app.calcs = null; // refetch on Saved tab
          toast(t("saved_calculation"));
        } catch (e) { reportError(e); } finally { b.disabled = false; }
      }
    })
  );
}

// ============================================================ difference calculator

const diff = { mode: "tax_difference", amount: "", condition: "duty_and_vat", currency: "OMR", rate: "", convention: "multiply" };

function renderDifference() {
  root.innerHTML = `${pageHead(t("tool_diff_calculator"), { back: true })}<div class="stack">
    <section class="card stack">
      ${seg("mode", [["tax_difference", t("mode_tax_difference")], ["original_amount", t("mode_original_amount")]], diff.mode)}
      <label class="field" id="diff-amount-label">${esc(t(diff.mode === "tax_difference" ? "enter_5_percent_amount" : "enter_original_amount"))}
        <input class="input num" inputmode="decimal" id="diff-amount" value="${esc(diff.amount)}" placeholder="0.000"></label>
      <p class="error-text hidden" id="diff-amount-err">${esc(t("invalid_amount_error"))}</p>
      <label class="field">${esc(t("condition"))}${seg("condition", [["duty_and_vat", t("condition_duty_and_vat")], ["vat_only", t("condition_vat_only")]], diff.condition)}</label>
      <div class="notice info">${icon("info")}<div>${esc(t("temporary_adjustment_notice"))}</div></div>
    </section>
    <section class="card stack">
      <label class="field">${esc(t("select_target_currency"))}${currencySelect("diff", diff.currency)}</label>
      <div class="stack ${diff.currency === "OMR" ? "hidden" : ""}" id="diff-rate-wrap">
        <label class="field">${esc(t("enter_customs_exchange_rate"))}<input class="input num" inputmode="decimal" id="diff-rate" value="${esc(diff.rate)}"></label>
        <p class="error-text hidden" id="diff-rate-err">${esc(t("invalid_exchange_rate_error"))}</p>
        <p class="hint">${esc(t("convention_pending_notice"))}</p>
        ${seg("convention", [["multiply", t("convention_multiply")], ["divide", t("convention_divide")]], diff.convention)}
      </div>
    </section>
    <div id="diff-result" class="stack"></div>
  </div>`;
  bindCommon();
  bindSeg("mode", (v) => { diff.mode = v; $("#diff-amount-label").firstChild.textContent = t(v === "tax_difference" ? "enter_5_percent_amount" : "enter_original_amount"); updateDiff(); });
  bindSeg("condition", (v) => { diff.condition = v; updateDiff(); });
  bindSeg("convention", (v) => { diff.convention = v; updateDiff(); });
  $("#diff-amount").addEventListener("input", (e) => { diff.amount = e.target.value; updateDiff(); });
  $("#diff-rate").addEventListener("input", (e) => { diff.rate = e.target.value; updateDiff(); });
  $('[data-cur="diff"]').addEventListener("change", (e) => {
    diff.currency = e.target.value;
    $("#diff-rate-wrap").classList.toggle("hidden", diff.currency === "OMR");
    updateDiff();
  });
  updateDiff();
}

function updateDiff() {
  const amount = Dec.parse(diff.amount);
  const rate = Dec.parse(diff.rate);
  $("#diff-amount-err").classList.toggle("hidden", !diff.amount.trim() || !!(amount && !amount.isNeg()));
  const rateBad = diff.currency !== "OMR" && diff.rate.trim() && !(rate && rate.gt(0));
  $("#diff-rate-err").classList.toggle("hidden", !rateBad);
  const out = $("#diff-result");
  const needRate = diff.currency !== "OMR" && !(rate && rate.gt(0));
  const r = !amount || needRate ? null : calculateDifference({ ...diff, amount, currencyCode: diff.currency, rate });
  if (!r) { out.innerHTML = ""; return; }
  const digits = currency(r.currencyCode).digits;
  const text = [
    `${t(diff.mode === "tax_difference" ? "entered_tax_difference" : "mode_original_amount")}: ${r.amount.toFixed(3)} OMR`,
    `${t("calculated_5_percent_original")}: ${r.original.toFixed(3)} OMR`,
    `${t("adjustment")}: -${r.adjustment.toFixed(3)} OMR`,
    `${t("adjusted_omr_value")}: ${r.adjusted.toFixed(3)} OMR`,
    r.currencyCode !== "OMR" ? `${t("exchange_rate")}: ${r.rate.toPlain(6)}` : null,
    `${t("final_declaration_value")}: ${r.finalValue.toFixed(digits)} ${r.currencyCode}`,
  ].filter(Boolean).join("\n");
  out.innerHTML = `<section class="card result-card">
    <b>${esc(t("calculation_summary"))}</b>
    ${diff.mode === "tax_difference" ? `<div class="kv"><span>${esc(t("entered_tax_difference"))}</span><b>${r.amount.toFixed(3)} OMR</b></div>` : ""}
    <div class="kv"><span>${esc(t("calculated_5_percent_original"))}</span><b>${r.original.toFixed(3)} OMR</b></div>
    <div class="kv"><span>${esc(t("adjustment"))}</span><b>-${r.adjustment.toFixed(3)} OMR</b></div>
    <div class="kv"><span>${esc(t("adjusted_omr_value"))}</span><b>${r.adjusted.toFixed(3)} OMR</b></div>
    ${r.currencyCode !== "OMR" ? `<div class="kv"><span>${esc(t("exchange_rate"))}</span><b>${r.rate.toPlain(6)} (${r.convention === "divide" ? "÷" : "×"})</b></div>` : ""}
    <div class="total"><span>${esc(t("final_declaration_value"))}</span><b>${r.finalValue.toFixed(digits)} ${r.currencyCode}</b></div>
  </section>
  <div class="btn-row"><button class="btn secondary" data-diff="copy">${icon("copy", 18)} ${esc(t("copy_result"))}</button>
    <button class="btn" data-diff="save">${icon("save", 18)} ${esc(t("save_calculation"))}</button></div>`;
  $('[data-diff="copy"]', out).addEventListener("click", () => copyText(text));
  const saveBtn = $('[data-diff="save"]', out);
  saveBtn.addEventListener("click", async () => {
    saveBtn.disabled = true;
    try {
      await cloud.saveCalculation(userId(), "difference", `${r.finalValue.toFixed(digits)} ${r.currencyCode}`, { text });
      app.calcs = null;
      toast(t("saved_calculation"));
    } catch (err) { reportError(err); } finally { saveBtn.disabled = false; }
  });
}

// ============================================================ unit converter

const units = { pair: "carat_gram", dir: "carat_to_gram", value: "", density: "" };

function renderUnits() {
  const d = UNIT_DIRS[units.dir];
  root.innerHTML = `${pageHead(t("tool_unit_converter"), { back: true })}<div class="stack">
    <div class="filter-row" role="tablist">${UNIT_PAIRS.map((p) => `<button class="${p.id === units.pair ? "on" : ""}" data-pair="${p.id}">${esc(t("pair_" + p.id))}</button>`).join("")}</div>
    <section class="card stack">
      <div class="row between"><b>${esc(t("conversion_type"))}</b>
        <button class="btn ghost" data-swap>${icon("swap", 18)} ${esc(t("swap"))}</button></div>
      <div class="row" style="justify-content:center;gap:14px;font-size:20px;font-weight:800" dir="ltr"><span>${esc(d.from)}</span>${icon("chev", 18)}<span style="color:var(--brand-primary)">${esc(d.to)}</span></div>
      <label class="field">${esc(t("enter_value"))} (${esc(d.from)})<input class="input num" inputmode="decimal" id="u-val" value="${esc(units.value)}" placeholder="0"></label>
      ${d.density ? `<label class="field">${esc(t("density"))}<input class="input num" inputmode="decimal" id="u-den" value="${esc(units.density)}" placeholder="g/mL"></label><p class="hint">${esc(t("density_hint"))}</p>` : ""}
      <p class="error-text hidden" id="u-err"></p>
    </section>
    <section class="card result-card stack-s"><span class="muted">${esc(t("converted_result"))}</span><div class="big-number" id="u-out">—</div>
      <button class="btn secondary" data-u-copy>${icon("copy", 18)} ${esc(t("copy_result"))}</button></section>
    <section class="card stack-s"><b>${esc(t("conversion_rule"))}</b><p class="muted small" style="margin:0">${esc(t("conversion_rule_desc"))}</p></section>
  </div>`;
  bindCommon();
  $$("[data-pair]").forEach((b) => b.addEventListener("click", () => {
    units.pair = b.dataset.pair;
    units.dir = UNIT_PAIRS.find((p) => p.id === units.pair).dirs[0];
    renderUnits();
  }));
  $("[data-swap]").addEventListener("click", () => {
    const p = UNIT_PAIRS.find((x) => x.id === units.pair);
    units.dir = p.dirs[0] === units.dir ? p.dirs[1] : p.dirs[0];
    renderUnits();
  });
  $("#u-val").addEventListener("input", (e) => { units.value = e.target.value; updateUnits(); });
  $("#u-den")?.addEventListener("input", (e) => { units.density = e.target.value; updateUnits(); });
  $("[data-u-copy]").addEventListener("click", () => copyText($("#u-out").textContent));
  updateUnits();
}

function updateUnits() {
  const d = UNIT_DIRS[units.dir];
  const out = $("#u-out"), err = $("#u-err");
  err.classList.add("hidden");
  out.textContent = "—";
  if (!units.value.trim()) return;
  const v = Dec.parse(units.value);
  if (!v || v.isNeg()) { err.textContent = t("invalid_amount_error"); err.classList.remove("hidden"); return; }
  let den = null;
  if (d.density) {
    den = Dec.parse(units.density);
    if (!den || !den.gt(0)) { if (units.density.trim()) { err.textContent = t("density_required_error"); err.classList.remove("hidden"); } return; }
  }
  const r = convertUnit(v, units.dir, den);
  if (r) out.textContent = `${r.toPlain(6)} ${d.to}`;
}

// ============================================================ gold price

let goldLoading = false;

/** Refreshes through the Supabase Edge Function when the 10-minute cache is stale. Returns true if data changed. */
async function refreshGold(force) {
  const snap = readLocal(GOLD_CACHE_KEY);
  if (goldLoading || (!force && snap && Date.now() - snap.fetchedAt < 10 * 60 * 1000)) return false;
  goldLoading = true;
  try {
    const data = await cloud.fetchGoldPrice();
    if (!data?.price24) throw new Error("no price");
    writeLocal(GOLD_CACHE_KEY, { ...data, fetchedAt: Date.now() });
    return true;
  } catch (e) {
    if (force) throw e;
    return false;
  } finally {
    goldLoading = false;
  }
}

function renderGold(_, error = null) {
  const snap = readLocal(GOLD_CACHE_KEY);
  const fmtTime = (ms) => new Date(ms).toLocaleString(getLang() === "ar" ? "ar-OM" : "en-GB", { dateStyle: "medium", timeStyle: "short" });
  root.innerHTML = `${pageHead(t("gold_price_title"), { back: true })}<div class="stack">
    <section class="card gold-card stack">
      <div class="row between"><b>${esc(t("dashboard_gold_oman"))}</b><span class="badge info">${esc(t("dashboard_gold_karat_24"))}</span></div>
      <div class="row" style="align-items:baseline"><span class="price">${snap ? esc(snap.price24) : "—"}</span><span class="muted">OMR · ${esc(t("dashboard_gold_per_gram"))}</span></div>
      ${snap ? `<div class="gold-grid">${[24, 22, 21, 18].map((k) => `<div><span>${k}K</span><b>${esc(snap["price" + k])}</b></div>`).join("")}</div>` : ""}
      ${snap ? `<p class="hint">${esc(t("dashboard_gold_last_update"))}: ${esc(snap.sourceUpdatedText || fmtTime(snap.fetchedAt))}</p>` : ""}
      ${goldLoading ? `<p class="hint"><span class="spinner"></span> ${esc(t("dashboard_gold_loading"))}</p>` : ""}
      ${error ? `<div class="notice">${icon("alert")}<div>${esc(t("dashboard_gold_unavailable"))}<br><span class="muted">${esc(t("gold_needs_function"))}</span></div></div>` : ""}
      <div class="btn-row">
        <button class="btn" data-gold-refresh ${goldLoading ? "disabled" : ""}>${icon("refresh", 18)} ${esc(t("dashboard_gold_refresh"))}</button>
        <a class="btn secondary" href="${CONFIG.trustedGoldPriceURL}" target="_blank" rel="noopener">${icon("external", 18)} ${esc(t("dashboard_gold_view_source"))}</a>
      </div>
      <p class="hint">${esc(t("dashboard_gold_source"))}</p>
    </section>
  </div>`;
  bindCommon();
  $("[data-gold-refresh]").addEventListener("click", () => loadGold(true));
  if (!snap && !goldLoading && !error) loadGold(false);
}

async function loadGold(force) {
  const p = refreshGold(force || !readLocal(GOLD_CACHE_KEY));
  renderGold();
  try { await p; renderGold(); } catch (e) { console.warn(e); renderGold(null, e); }
}

// ============================================================ air cargo tracking

let trackAWB = "";

function renderTrack() {
  root.innerHTML = `${pageHead(t("tool_air_cargo_tracking"), { back: true })}<div class="stack">
    <section class="hero"><h2 style="font-size:20px">${esc(t("tracking_awb_title"))}</h2><p style="margin:6px 0 0;opacity:.85">${esc(t("tracking_two_sources_hint"))}</p></section>
    <form class="card stack" id="track-form">
      <label class="field">${esc(t("tracking_awb_number"))}
        <input class="input num" id="awb" inputmode="numeric" autocomplete="off" placeholder="${esc(t("tracking_awb_placeholder"))}" value="${esc(awbFormatted(trackAWB))}" maxlength="12"></label>
      <p class="hint">${esc(t("tracking_awb_auto_format_hint"))}</p>
      <p class="error-text hidden" id="awb-err">${esc(t("tracking_invalid_awb"))}</p>
      <button class="btn block" type="submit">${icon("search", 18)} ${esc(t("tracking_track_shipment"))}</button>
    </form>
    <div id="track-result" class="stack"></div>
  </div>`;
  bindCommon();
  const input = $("#awb");
  input.addEventListener("input", () => {
    const d = awbDigits(input.value).slice(0, 11);
    trackAWB = d;
    input.value = awbFormatted(d);
  });
  $("#track-form").addEventListener("submit", (e) => {
    e.preventDefault();
    const ok = awbDigits(trackAWB).length === 11;
    $("#awb-err").classList.toggle("hidden", ok);
    if (ok) showTrackResult();
  });
  if (awbDigits(trackAWB).length === 11) showTrackResult();
}

async function showTrackResult() {
  const awb = awbDigits(trackAWB);
  const airline = airlineFor(awb);
  if (!app.shipments) await loadShipments();
  const onBoard = app.shipments?.some((s) => s.awb === awb);
  $("#track-result").innerHTML = `
    <div class="row between"><h2 style="margin:0;font-size:18px">${esc(t("tracking_results_title"))}</h2><span class="hs-code" style="font-size:18px">${awbFormatted(awb)}</span></div>
    <section class="card stack-s">
      <div class="row"><span class="tool-icon">${icon("plane", 22)}</span><div class="grow"><b>${esc(t("tracking_airline_source"))}</b>
        <div class="muted small">${airline ? `${esc(airline.name)} · <span class="ltr">${esc(airline.iata)} ${airline.prefix}</span>` : esc(t("tracking_airline_unknown"))}</div></div>
        <span class="badge info">${esc(t("tracking_source_ready"))}</span></div>
      ${airline ? `<a class="btn secondary" href="${esc(airline.url)}" target="_blank" rel="noopener">${icon("external", 18)} ${esc(t("tracking_open_official_source"))}</a>` : ""}
    </section>
    <section class="card stack-s">
      <div class="row"><span class="tool-icon">${icon("box", 22)}</span><div class="grow"><b>${esc(t("tracking_airport_confirmation"))}</b>
        <div class="muted small">${esc(t("tracking_transom_source"))}</div></div><span class="badge info">${esc(t("tracking_source_ready"))}</span></div>
      <a class="btn secondary" href="${TRANSOM_URL}" target="_blank" rel="noopener">${icon("external", 18)} ${esc(t("tracking_open_official_source"))}</a>
    </section>
    <div class="notice info">${icon("info")}<div>${esc(t("tracking_web_note"))}</div></div>
    <div class="btn-row">
      <button class="btn secondary" data-copy-awb>${icon("copy", 18)} ${esc(awbFormatted(awb))}</button>
      <button class="btn" data-add-board ${onBoard ? "disabled" : ""}>${icon(onBoard ? "check" : "bookmark", 18)} ${esc(t(onBoard ? "tracking_already_on_board" : "tracking_add_to_board"))}</button>
    </div>`;
  $("[data-copy-awb]").addEventListener("click", () => copyText(awb));
  $("[data-add-board]").addEventListener("click", async (e) => {
    e.currentTarget.disabled = true;
    try {
      const row = await cloud.addShipment(userId(), awb, airline?.name ?? null);
      app.shipments = [row, ...(app.shipments ?? []).filter((s) => s.id !== row.id)];
      toast(t("tracking_added"));
      showTrackResult();
    } catch (err) { reportError(err); }
  });
}

// ============================================================ cargo board

const CARGO_STATES = ["unknown", "in_transit", "not_arrived", "partial", "arrived"];
const STATE_BADGE = { arrived: "ok", partial: "warn", in_transit: "info", not_arrived: "bad", unknown: "mute" };
const STATE_PRIORITY = { partial: 0, arrived: 1, in_transit: 2, not_arrived: 3, unknown: 4 };
let boardFilter = "all", boardQuery = "";

async function loadShipments() {
  try { app.shipments = await cloud.listShipments(); } catch (e) { reportError(e); app.shipments = []; }
}

async function renderBoard() {
  if (!app.shipments) {
    root.innerHTML = `${pageHead(t("tool_cargo_board"), { back: true })}<div class="empty"><span class="spinner"></span></div>`;
    bindCommon();
    await loadShipments();
    if (currentRoute().path !== "/tool/board") return;
  }
  root.innerHTML = `${pageHead(t("tool_cargo_board"), {
    back: true,
    actions: `<button class="icon-btn" data-go="/tool/track" aria-label="${esc(t("tool_air_cargo_tracking"))}">${icon("plane", 18)}</button>`,
  })}<div class="stack">
    <input class="input" type="search" id="board-q" placeholder="${esc(t("cargo_board_search_placeholder"))}" value="${esc(boardQuery)}">
    <div class="filter-row">${["all", ...CARGO_STATES].map((s) => `<button class="${s === boardFilter ? "on" : ""}" data-filter="${s}">${esc(s === "all" ? t("cargo_board_filter_all") : t("cargo_state_" + s))}</button>`).join("")}</div>
    <div id="board-list" class="stack"></div>
  </div>`;
  bindCommon();
  $("#board-q").addEventListener("input", (e) => { boardQuery = e.target.value; renderBoardList(); });
  $$("[data-filter]").forEach((b) => b.addEventListener("click", () => {
    boardFilter = b.dataset.filter;
    $$("[data-filter]").forEach((x) => x.classList.toggle("on", x === b));
    renderBoardList();
  }));
  renderBoardList();
}

function renderBoardList() {
  const out = $("#board-list");
  const q = boardQuery.trim().toLowerCase();
  const qd = awbDigits(q);
  const items = (app.shipments ?? [])
    .filter((s) => boardFilter === "all" || s.state === boardFilter)
    .filter((s) => !q || (qd && s.awb.includes(qd)) || (s.airline ?? "").toLowerCase().includes(q))
    .sort((a, b) => (STATE_PRIORITY[a.state] ?? 9) - (STATE_PRIORITY[b.state] ?? 9) || (a.added_at < b.added_at ? 1 : -1));
  if (!items.length) {
    out.innerHTML = emptyState("box", t("cargo_board_empty_title"), t("cargo_board_empty_description"));
    return;
  }
  out.innerHTML = `<p class="muted small" style="margin:0 4px">${esc(t("cargo_board_active_shipments"))}: ${items.length}</p>` +
    items.map((s) => {
      const airline = airlineFor(s.awb);
      return `<section class="card stack-s" data-ship="${s.id}">
        <div class="row between"><span class="hs-code" style="font-size:18px">${awbFormatted(s.awb)}</span><span class="badge ${STATE_BADGE[s.state] ?? "mute"}">${esc(t("cargo_state_" + s.state))}</span></div>
        <div class="muted small">${esc(s.airline || t("tracking_airline_unknown"))}</div>
        <div class="row">
          <label class="field grow">${esc(t("tracking_set_status"))}
            <select class="input" data-state>${CARGO_STATES.map((st) => `<option value="${st}" ${st === s.state ? "selected" : ""}>${esc(t("cargo_state_" + st))}</option>`).join("")}</select></label>
        </div>
        <label class="field">${esc(t("tracking_note"))}<input class="input" data-note value="${esc(s.note ?? "")}" maxlength="300"></label>
        <div class="btn-row">
          ${airline ? `<a class="btn secondary" href="${esc(airline.url)}" target="_blank" rel="noopener">${icon("plane", 16)} ${esc(airline.iata)}</a>` : ""}
          <a class="btn secondary" href="${TRANSOM_URL}" target="_blank" rel="noopener">${icon("box", 16)} Transom</a>
          <button class="btn danger" data-remove aria-label="${esc(t("cargo_board_remove_shipment"))}">${icon("trash", 18)}</button>
        </div>
      </section>`;
    }).join("");
  $$("[data-ship]", out).forEach((card) => {
    const id = card.dataset.ship;
    const ship = app.shipments.find((s) => s.id === id);
    card.querySelector("[data-state]").addEventListener("change", async (e) => {
      ship.state = e.target.value;
      try { await cloud.updateShipment(id, { state: ship.state }); renderBoardList(); } catch (err) { reportError(err); }
    });
    let noteTimer;
    card.querySelector("[data-note]").addEventListener("input", (e) => {
      ship.note = e.target.value;
      clearTimeout(noteTimer);
      noteTimer = setTimeout(() => cloud.updateShipment(id, { note: ship.note }).catch(reportError), 600);
    });
    card.querySelector("[data-remove]").addEventListener("click", async () => {
      if (!confirm(t("cargo_board_remove_shipment") + "?")) return;
      try {
        await cloud.removeShipment(id);
        app.shipments = app.shipments.filter((s) => s.id !== id);
        renderBoardList();
      } catch (err) { reportError(err); }
    });
  });
}

// ============================================================ saved

async function renderSaved() {
  root.innerHTML = `${pageHead(t("saved_title"), { large: true })}<div id="saved-list" class="stack"><div class="empty"><span class="spinner"></span></div></div>`;
  if (!app.calcs) {
    try { app.calcs = await cloud.listCalculations(); } catch (e) { reportError(e); app.calcs = []; }
  }
  if (currentRoute().path !== "/saved") return;
  const out = $("#saved-list");
  if (!app.calcs.length) {
    out.innerHTML = emptyState("bookmark", t("saved_empty_title"), t("saved_empty_desc"));
    return;
  }
  const fmt = (s) => new Date(s).toLocaleString(getLang() === "ar" ? "ar-OM" : "en-GB", { dateStyle: "medium", timeStyle: "short" });
  out.innerHTML = `<p class="muted small" style="margin:0 4px">${icon("database", 14)} ${esc(t("cloud_synced"))}</p>` +
    app.calcs.map((c) => `<details class="card" data-calc="${c.id}">
      <summary class="row between"><span class="grow"><span class="${c.payload?.hs ? "hs-code" : ""}">${esc(c.title)}</span>
        <span class="muted tiny" style="display:block">${esc(t(c.kind === "duty" ? "tool_duty_calculator" : "tool_diff_calculator"))} · ${esc(fmt(c.created_at))}</span></span>
        ${c.payload?.total ? `<b class="mono ltr">${esc(c.payload.total)} OMR</b>` : ""}</summary>
      <pre style="white-space:pre-wrap;font:13px/1.5 var(--mono);margin:12px 0" dir="auto">${esc(c.payload?.text ?? "")}</pre>
      <div class="btn-row"><button class="btn secondary" data-calc-copy>${icon("copy", 18)} ${esc(t("copy_result"))}</button>
        <button class="btn danger" data-calc-del>${icon("trash", 18)} ${esc(t("delete"))}</button></div>
    </details>`).join("");
  $$("[data-calc]", out).forEach((el) => {
    const c = app.calcs.find((x) => String(x.id) === el.dataset.calc);
    el.querySelector("[data-calc-copy]").addEventListener("click", () => copyText(c.payload?.text ?? ""));
    el.querySelector("[data-calc-del]").addEventListener("click", async () => {
      try {
        await cloud.removeCalculation(c.id);
        app.calcs = app.calcs.filter((x) => x !== c);
        renderSaved();
      } catch (e) { reportError(e); }
    });
  });
}

// ============================================================ more / settings

function renderMore() {
  const ts = tariffState();
  const user = app.session.user;
  const name = app.profile?.full_name || user.user_metadata?.full_name || "";
  root.innerHTML = `${pageHead(t("settings_title"), { large: true })}<div class="stack">
    <section class="card row"><span class="tool-icon">${icon("user", 24)}</span>
      <div class="grow"><b>${esc(name || t("account"))}</b><div class="muted small ltr">${esc(user.email)}</div></div>
      <button class="btn danger" data-signout>${icon("logout", 18)} ${esc(t("auth_sign_out"))}</button></section>

    <section class="card stack-s"><span class="muted small">${esc(t("service_current"))}</span>
      <div class="row"><span class="tool-icon">${icon(app.settings.service_area === "sea" ? "ship" : "plane", 22)}</span>
        <b class="grow">${esc(t(app.settings.service_area === "sea" ? "service_sea_title" : "service_air_title"))}</b></div>
      <button class="btn secondary" data-change-service>${icon("swap", 18)} ${esc(t("service_change"))}</button></section>

    <section class="card stack">
      <label class="field">${esc(t("language"))}${seg("lang", [["en", "English"], ["ar", "العربية"]], getLang())}</label>
      <label class="field">${esc(t("appearance"))}${seg("appearance", [["system", t("appearance_system")], ["light", t("appearance_light")], ["dark", t("appearance_dark")]], app.settings.appearance)}</label>
    </section>

    ${installCard()}

    <section class="card"><b>${esc(t("reference_data"))}</b>
      <div class="kv"><span>${esc(t("tariff_status"))}</span><b>${esc(ts.status === "ready" ? t("status_installed") : ts.status === "loading" ? "…" : t("not_installed"))}</b></div>
      ${ts.meta ? `<div class="kv"><span>${esc(t("records_count", ts.items.length))}</span><b>${esc(ts.meta.datasetVersion)}</b></div>` : ""}
      <div class="kv"><span>${esc(t("source_reference"))}</span><b style="font-family:inherit">${esc(t("official_tariff_source"))}</b></div>
    </section>

    <section class="card"><b>${esc(t("about"))}</b>
      <div class="kv"><span>${esc(t("version"))}</span><b>${esc(APP_VERSION)}</b></div>
      <p class="muted small" style="margin:8px 0 0">${esc(t("creator_credit"))}</p></section>
  </div>`;
  bindCommon(); bindInstall();
  $("[data-signout]").addEventListener("click", () => cloud.signOut());
  $("[data-change-service]").addEventListener("click", async () => { await updateSettings({ service_area: null }); render(); });
  bindSeg("lang", (v) => { setLang(v); updateSettings({}); render(); });
  bindSeg("appearance", (v) => updateSettings({ appearance: v }));
}

// ============================================================ boot

async function loadUserData() {
  const uid = userId();
  const [profile, settings, recent] = await Promise.all([
    cloud.getProfile(uid).catch(() => null),
    cloud.getSettings(uid).catch(() => null),
    cloud.listRecentSearches().catch(() => []),
  ]);
  app.profile = profile;
  app.recent = recent;
  app.shipments = null;
  app.calcs = null;
  if (settings) {
    if (settings.language) setLang(settings.language);
    app.settings = {
      appearance: settings.appearance ?? app.settings.appearance,
      service_area: settings.service_area ?? app.settings.service_area,
    };
    writeLocal(LOCAL_SETTINGS_KEY, app.settings);
    applyTheme();
  }
}

async function boot() {
  applyDocumentLang();
  applyTheme();
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applyTheme);
  window.addEventListener("hashchange", render);
  window.addEventListener("beforeinstallprompt", (e) => { e.preventDefault(); app.installEvent = e; });

  if (cloud.configured) {
    app.session = await cloud.getSession();
    if (app.session) await loadUserData();
    cloud.onAuthChange(async (event, session) => {
      if (event === "PASSWORD_RECOVERY") { app.session = session; app.recovering = true; render(); return; }
      if (event === "TOKEN_REFRESHED" || event === "USER_UPDATED") { app.session = session; return; }
      const changed = (session?.user?.id ?? null) !== (app.session?.user?.id ?? null);
      app.session = session;
      if (!changed) return;
      if (session) { await loadUserData(); go("/home"); }
      else { app.profile = null; app.recent = []; app.shipments = null; app.calcs = null; app.authMode = "signin"; }
      render();
    });
  }
  render();
  loadTariff().then(() => { if (["/home", "/more"].includes(currentRoute().path)) render(); }, () => {});

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch((e) => console.warn("SW", e));
  }
}

boot();
