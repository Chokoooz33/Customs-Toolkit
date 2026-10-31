// Minimal exact decimal arithmetic on BigInt, standing in for Foundation.Decimal / DecimalMath.
// Avoids binary floating-point error in customs & tax workflows.

const TEN = 10n;
const pow10 = (k) => TEN ** BigInt(k);

export class Dec {
  constructor(n, s) { this.n = n; this.s = s; } // value = n / 10^s

  /** Parses user input; accepts Arabic/Persian digits and `,` / `٫` decimal separators. Returns null when invalid. */
  static parse(text) {
    if (text == null) return null;
    let str = String(text).trim()
      .replace(/[٠-٩]/g, (c) => String(c.charCodeAt(0) - 0x660))
      .replace(/[۰-۹]/g, (c) => String(c.charCodeAt(0) - 0x6f0))
      .replace(/٬/g, "")
      .replace(/[٫,]/g, ".");
    if (!/^-?\d*\.?\d+$|^-?\d+\.$/.test(str)) return null;
    const neg = str.startsWith("-");
    if (neg) str = str.slice(1);
    const [i, f = ""] = str.split(".");
    const n = BigInt((i || "0") + f);
    return new Dec(neg ? -n : n, f.length);
  }

  static of(v) { return v instanceof Dec ? v : Dec.parse(String(v)); }

  #align(o) {
    const s = Math.max(this.s, o.s);
    return [this.n * pow10(s - this.s), o.n * pow10(s - o.s), s];
  }

  add(o) { o = Dec.of(o); const [a, b, s] = this.#align(o); return new Dec(a + b, s); }
  sub(o) { o = Dec.of(o); const [a, b, s] = this.#align(o); return new Dec(a - b, s); }
  mul(o) { o = Dec.of(o); return new Dec(this.n * o.n, this.s + o.s).trim(); }

  /** Division to `scale` fractional digits (round half-up). Returns null for division by zero. */
  div(o, scale = 20) {
    o = Dec.of(o);
    if (o.n === 0n) return null;
    // (a/10^sa) / (b/10^sb) = a*10^(sb) / (b*10^(sa))
    const num = this.n * pow10(o.s + scale + 1);
    const den = o.n * pow10(this.s);
    const q = num / den; // one extra digit for rounding
    return new Dec(roundLastDigit(q), scale).trim();
  }

  /** NSDecimalRound with .plain (half away from zero). */
  round(scale) {
    if (this.s <= scale) return this;
    const drop = this.s - scale;
    const q = this.n / pow10(drop - 1);
    return new Dec(roundLastDigit(q), scale);
  }

  trim() {
    let { n, s } = this;
    while (s > 0 && n % TEN === 0n) { n /= TEN; s--; }
    return new Dec(n, s);
  }

  cmp(o) { o = Dec.of(o); const [a, b] = this.#align(o); return a < b ? -1 : a > b ? 1 : 0; }
  gt(o) { return this.cmp(o) > 0; }
  gte(o) { return this.cmp(o) >= 0; }
  isZero() { return this.n === 0n; }
  isNeg() { return this.n < 0n; }

  /** Fixed-point string, e.g. "1,234.500" when `group` is set. */
  toFixed(digits, { group = true } = {}) {
    const r = this.round(digits);
    const n = r.n * pow10(digits - r.s);
    const neg = n < 0n;
    let str = (neg ? -n : n).toString().padStart(digits + 1, "0");
    let i = digits ? str.slice(0, -digits) : str;
    const f = digits ? str.slice(-digits) : "";
    if (group) i = i.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return (neg ? "-" : "") + i + (f ? "." + f : "");
  }

  /** Shortest exact representation up to `max` fraction digits. */
  toPlain(max = 6, opts) {
    const r = this.round(max).trim();
    return r.toFixed(r.s, opts);
  }
}

function roundLastDigit(q) {
  const neg = q < 0n;
  const a = neg ? -q : q;
  const out = a / TEN + (a % TEN >= 5n ? 1n : 0n);
  return neg ? -out : out;
}

export const D = (v) => Dec.of(v);
