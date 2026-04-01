// Multi-Language (i18n) Edge Function
// 多言語対応管理 (Google/Microsoft/Notion競合)
// - 翻訳キー管理
// - 言語切替
// - 自動翻訳候補
// - 翻訳進捗

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SUPPORTED_LANGUAGES = [
  { code: "ja", name: "日本語", native: "日本語" }, { code: "en", name: "English", native: "English" },
  { code: "zh", name: "中文", native: "中文" }, { code: "ko", name: "한국어", native: "한국어" },
  { code: "es", name: "Español", native: "Español" }, { code: "fr", name: "Français", native: "Français" },
  { code: "de", name: "Deutsch", native: "Deutsch" }, { code: "pt", name: "Português", native: "Português" },
  { code: "vi", name: "Tiếng Việt", native: "Tiếng Việt" }, { code: "th", name: "ไทย", native: "ไทย" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const lang = url.searchParams.get("lang");

      if (view === "languages") return new Response(JSON.stringify({ success: true, languages: SUPPORTED_LANGUAGES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "translations" && lang) {
        const { data: translations } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "i18n_translation").eq("metadata->>lang", lang);
        const map: Record<string, string> = {};
        for (const t of translations ?? []) { const m = t.metadata as Record<string, unknown>; map[m.key as string] = (m.value as string) ?? ""; }
        return new Response(JSON.stringify({ success: true, lang, translations: map, count: Object.keys(map).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "progress") {
        const { data: allKeys } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "i18n_translation").eq("metadata->>lang", "ja");
        const totalKeys = (allKeys ?? []).length;
        const progress: Array<{ lang: string; translated: number; total: number; percent: number }> = [];
        for (const l of SUPPORTED_LANGUAGES) {
          const { count } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("source", "i18n_translation").eq("metadata->>lang", l.code);
          progress.push({ lang: l.code, translated: count ?? 0, total: totalKeys, percent: totalKeys > 0 ? Math.round(((count ?? 0) / totalKeys) * 100) : 0 });
        }
        return new Response(JSON.stringify({ success: true, progress }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "preference") {
        const { data: pref } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "i18n_preference").maybeSingle();
        return new Response(JSON.stringify({ success: true, language: pref ? (pref.metadata as Record<string, unknown>).lang : "ja" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, languages: SUPPORTED_LANGUAGES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "set_translation") {
        const { lang: tLang, key, value } = body;
        if (!tLang || !key || !value) return new Response(JSON.stringify({ success: false, error: "lang, key, value required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete().eq("source", "i18n_translation").eq("metadata->>lang", tLang).eq("metadata->>key", key);
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "i18n_translation", metadata: { lang: tLang, key, value }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "set_preference") {
        const { lang: prefLang } = body;
        if (!prefLang) return new Response(JSON.stringify({ success: false, error: "lang required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete().eq("user_id", user.id).eq("source", "i18n_preference");
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "i18n_preference", metadata: { lang: prefLang }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, language: prefLang }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
