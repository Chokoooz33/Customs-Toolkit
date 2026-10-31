// Supabase auth + per-user data (profiles, settings, recent searches, cargo board, saved calculations).
// Tables and Row Level Security policies live in supabase/schema.sql.
import { SUPABASE_URL, SUPABASE_ANON_KEY, isSupabaseConfigured } from "./config.js";

export const configured = isSupabaseConfigured();
export const sb = configured && window.supabase
  ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  : null;

const must = ({ data, error }) => {
  if (error) throw error;
  return data;
};

// ---------------- auth ----------------

export async function getSession() {
  if (!sb) return null;
  const { data } = await sb.auth.getSession();
  return data.session;
}

export const onAuthChange = (cb) => sb?.auth.onAuthStateChange((event, session) => cb(event, session));

export const signIn = (email, password) => sb.auth.signInWithPassword({ email, password }).then(must);

export const signUp = (email, password, fullName) =>
  sb.auth
    .signUp({
      email,
      password,
      options: { data: { full_name: fullName }, emailRedirectTo: location.origin + location.pathname },
    })
    .then(must);

export const signOut = () => sb.auth.signOut();

export const sendPasswordReset = (email) =>
  sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname }).then(must);

export const updatePassword = (password) => sb.auth.updateUser({ password }).then(must);

// ---------------- profile & settings ----------------

export async function getProfile(userId) {
  const data = must(await sb.from("profiles").select("*").eq("id", userId).maybeSingle());
  // Fire-and-forget activity stamp; RLS restricts it to the caller's own row.
  sb.from("profiles").update({ last_seen_at: new Date().toISOString() }).eq("id", userId).then(() => {});
  return data;
}

export async function getSettings(userId) {
  return must(await sb.from("user_settings").select("*").eq("user_id", userId).maybeSingle());
}

export async function saveSettings(userId, patch) {
  return must(
    await sb.from("user_settings").upsert({ user_id: userId, ...patch, updated_at: new Date().toISOString() })
  );
}

// ---------------- recent HS searches (max 10, newest first) ----------------

export async function listRecentSearches() {
  return must(
    await sb.from("recent_searches").select("query, normalized_query, created_at").order("created_at", { ascending: false }).limit(10)
  );
}

export async function addRecentSearch(userId, query, normalized) {
  must(
    await sb.from("recent_searches").upsert(
      { user_id: userId, query, normalized_query: normalized, created_at: new Date().toISOString() },
      { onConflict: "user_id,normalized_query" }
    )
  );
}

export const clearRecentSearches = async (userId) =>
  must(await sb.from("recent_searches").delete().eq("user_id", userId));

// ---------------- cargo board ----------------

export const listShipments = async () =>
  must(await sb.from("cargo_shipments").select("*").order("added_at", { ascending: false }));

export const addShipment = async (userId, awb, airline) =>
  must(await sb.from("cargo_shipments").insert({ user_id: userId, awb, airline }).select().single());

export const updateShipment = async (id, patch) =>
  must(await sb.from("cargo_shipments").update({ ...patch, updated_at: new Date().toISOString() }).eq("id", id));

export const removeShipment = async (id) => must(await sb.from("cargo_shipments").delete().eq("id", id));

// ---------------- saved duty calculations ----------------

export const listCalculations = async () =>
  must(await sb.from("saved_calculations").select("*").order("created_at", { ascending: false }).limit(100));

export const saveCalculation = async (userId, kind, title, payload) =>
  must(await sb.from("saved_calculations").insert({ user_id: userId, kind, title, payload }));

export const removeCalculation = async (id) => must(await sb.from("saved_calculations").delete().eq("id", id));

// ---------------- gold price (Edge Function proxy, see supabase/functions/gold-price) ----------------

export async function fetchGoldPrice() {
  const { data, error } = await sb.functions.invoke("gold-price");
  if (error) throw error;
  return data;
}
