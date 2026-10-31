// Port of HSSearchService / HSNormalizer over the compact data/tariff.json built by tools/build_web_data.py.

let state = { status: "idle", meta: null, items: [], index: [] };
let loading = null;

export const tariffState = () => state;

export function normalizeHS(input) {
  return String(input ?? "")
    .replace(/[٠-٩]/g, (c) => String(c.charCodeAt(0) - 0x660))
    .replace(/[۰-۹]/g, (c) => String(c.charCodeAt(0) - 0x6f0))
    .replace(/\D/g, "");
}

/** "010121100001" -> "0101 21 10 00 01" */
export function formatHS(code) {
  const d = normalizeHS(code);
  if (d.length <= 4) return d;
  let out = d.slice(0, 4);
  for (let i = 4; i < d.length; i += 2) out += " " + d.slice(i, i + 2);
  return out;
}

export function normalizeArabicForSearch(text) {
  return String(text ?? "")
    .replace(/[ً-ْٰ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .trim()
    .toLowerCase();
}

export function loadTariff() {
  if (loading) return loading;
  state = { ...state, status: "loading" };
  loading = fetch("data/tariff.json")
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then((data) => {
      const items = data.rows.map((r, i) => {
        const [code, ar, en, duty, procedure, ind, prohibited, subIdx, page] = r;
        const ch = data.chapters[code.slice(0, 2)] ?? [];
        const hd = data.headings[code.slice(0, 4)] ?? [];
        const sh = subIdx != null ? data.subheadings[subIdx] : [];
        return {
          id: i,
          code,
          ar, en, duty, procedure,
          ind: ind[0], efta: ind[1], sg: ind[2], usa: ind[3],
          status: prohibited ? "prohibited" : "normal",
          chapter: code.slice(0, 2),
          heading: code.slice(0, 4),
          chapterAr: ch[0], chapterEn: ch[1],
          headingAr: hd[0], headingEn: hd[1],
          subAr: sh[0], subEn: sh[1],
          page,
        };
      });
      state = {
        status: "ready",
        meta: data.meta,
        items,
        index: items.map((it) => ({ it, en: (it.en ?? "").toLowerCase(), ar: normalizeArabicForSearch(it.ar) })),
      };
      return state;
    })
    .catch((err) => {
      loading = null;
      state = { ...state, status: "error", error: String(err) };
      throw err;
    });
  return loading;
}

/** Ranked search: exact code → code prefix (sorted) → English/Arabic description contains. */
export function searchTariff(query, limit = 160) {
  const q = String(query ?? "").trim();
  const nq = normalizeHS(q);
  const arQ = normalizeArabicForSearch(q);
  const enQ = q.toLowerCase();
  if (!q) return { items: [], total: 0, truncated: false };

  const exact = [], prefix = [], desc = [];
  for (const e of state.index) {
    const code = e.it.code;
    if (nq && code === nq) { exact.push(e.it); continue; }
    if (nq && code.startsWith(nq)) { prefix.push(e.it); continue; }
    if ((enQ && e.en.includes(enQ)) || (arQ && e.ar.includes(arQ))) desc.push(e.it);
  }
  prefix.sort((a, b) => (a.code < b.code ? -1 : a.code > b.code ? 1 : 0));
  const all = exact.concat(prefix, desc);
  const items = all.slice(0, Math.max(1, limit));
  return { items, total: all.length, truncated: all.length > items.length };
}

export const findByCode = (code) => state.items.find((it) => it.code === normalizeHS(code)) ?? null;
export const getItem = (id) => state.items[id] ?? null;
