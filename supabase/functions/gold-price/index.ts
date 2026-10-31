// Supabase Edge Function: reads gold prices from the approved Oman source server-side
// (browsers can't fetch it directly because of CORS). Port of GoldPriceService.parseHTMLData.
//
// Deploy:  supabase functions deploy gold-price
// The app calls it with the signed-in user's token, so leave JWT verification on.

const SOURCE_URL = "https://www.gold-price-today.com/oman/";
const CACHE_MS = 10 * 60 * 1000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

let cached: { body: Record<string, unknown>; at: number } | null = null;

function toPlainText(html: string): string {
  return html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;|&#160;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function parse(text: string) {
  const price = (karat: number) => {
    const m = text.match(new RegExp(`عيار\\s*${karat}\\s*([0-9][0-9,]*(?:\\.[0-9]+)?)\\s*ريال`));
    if (!m) throw new Error(`Could not locate the ${karat}K gold price in the source page.`);
    return m[1].replace(/,/g, "");
  };
  const updated = text.match(/تم تحديث أسعار الذهب في عمان[،,]?\s*(.{1,90}?)(?=الأسعار بالأيام السابقة|$)/);
  return {
    price24: price(24),
    price22: price(22),
    price21: price(21),
    price18: price(18),
    sourceUpdatedText: updated ? updated[1].trim() : null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!cached || Date.now() - cached.at > CACHE_MS) {
      const res = await fetch(SOURCE_URL, {
        headers: {
          "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1",
          "Accept-Language": "ar,en;q=0.8",
        },
      });
      if (!res.ok) throw new Error(`Source returned HTTP ${res.status}`);
      cached = { body: { ...parse(toPlainText(await res.text())), source: SOURCE_URL }, at: Date.now() };
    }
    return new Response(JSON.stringify(cached.body), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ error: String((err as Error).message ?? err) }), {
      status: 502,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
