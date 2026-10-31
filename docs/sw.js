// Service worker: precaches the app shell + tariff data so the tools work offline.
// Bump VERSION whenever files in docs/ change so clients pick up the new build.
const VERSION = "ct-pwa-v3";
const SHELL = [
  "./",
  "index.html",
  "manifest.webmanifest",
  "css/app.css",
  "js/app.js",
  "js/calc.js",
  "js/cloud.js",
  "js/config.js",
  "js/decimal.js",
  "js/i18n.js",
  "js/icons.js",
  "js/strings.js",
  "js/tariff.js",
  "data/tariff.json",
  "icons/brandmark.png",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "icons/apple-touch-icon.png",
  "vendor/supabase-2.45.4.js",
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  // Never cache Supabase API / auth traffic.
  if (url.hostname.endsWith(".supabase.co") || url.hostname.endsWith(".supabase.in")) return;

  // Page, JS and CSS: network-first so new deployments show up immediately; cache is the offline fallback.
  const sameOrigin = url.origin === location.origin;
  const isCode = req.mode === "navigate" || (sameOrigin && /\.(js|css|html|webmanifest)$/.test(url.pathname));
  if (isCode) {
    const key = req.mode === "navigate" ? "index.html" : req;
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(VERSION).then((c) => c.put(key, copy));
          }
          return res;
        })
        .catch(() => caches.match(key, { ignoreSearch: true }))
    );
    return;
  }

  // Tariff data, icons and the pinned CDN library: cache-first.
  event.respondWith(
    caches.match(req, { ignoreSearch: url.origin === location.origin }).then(
      (hit) =>
        hit ||
        fetch(req).then((res) => {
          if (res.ok && (url.origin === location.origin || url.hostname === "cdn.jsdelivr.net")) {
            const copy = res.clone();
            caches.open(VERSION).then((c) => c.put(req, copy));
          }
          return res;
        })
    )
  );
});
