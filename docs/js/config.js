// Supabase project settings.
// Get both values from: Supabase Dashboard → Project Settings → API.
// The anon (public) key is designed to be shipped to browsers; data is protected by the
// Row Level Security policies in supabase/schema.sql. Never put the service_role key here.
export const SUPABASE_URL = "https://jfhsqgabmspesnlzvymv.supabase.co";
export const SUPABASE_ANON_KEY = "sb_publishable_KZ_5jFMMtkizg4nPVy1D6w_AselcNLL";

export const APP_VERSION = "4.3.8-pwa.1";

export const isSupabaseConfigured = () =>
  SUPABASE_URL.startsWith("https://") && !SUPABASE_ANON_KEY.startsWith("YOUR_");
