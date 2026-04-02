// Feature Flags Edge Function
// フィーチャーフラグ管理 (GitHub/LaunchDarkly競合)
// - フラグ作成・管理
// - ユーザーセグメント
// - ロールアウト率
// - A/Bテスト連携
// - フラグ評価

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const FLAG_TYPES = ["boolean", "percentage", "user_list", "segment"];

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
      const flagKey = url.searchParams.get("flag");

      if (view === "types") return new Response(JSON.stringify({ success: true, flagTypes: FLAG_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "evaluate" && flagKey) {
        const { data: flag } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "feature_flag").eq("metadata->>key", flagKey).maybeSingle();
        if (!flag) return new Response(JSON.stringify({ success: true, enabled: false, reason: "flag_not_found" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = flag.metadata as Record<string, unknown>;
        if (!m.enabled) return new Response(JSON.stringify({ success: true, enabled: false, reason: "disabled" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        if (m.type === "boolean") return new Response(JSON.stringify({ success: true, enabled: true, reason: "boolean_on" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        if (m.type === "percentage") {
          const hash = user.id.split("").reduce((a, c) => a + c.charCodeAt(0), 0) % 100;
          const enabled = hash < ((m.percentage as number) ?? 0);
          return new Response(JSON.stringify({ success: true, enabled, reason: `percentage_${m.percentage}` }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (m.type === "user_list") {
          const enabled = ((m.user_ids as string[]) ?? []).includes(user.id);
          return new Response(JSON.stringify({ success: true, enabled, reason: "user_list" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({ success: true, enabled: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "evaluate_all") {
        const { data: flags } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "feature_flag");
        const result: Record<string, boolean> = {};
        for (const f of flags ?? []) {
          const m = f.metadata as Record<string, unknown>;
          const key = m.key as string;
          if (!m.enabled) { result[key] = false; continue; }
          if (m.type === "percentage") {
            const hash = user.id.split("").reduce((a, c) => a + c.charCodeAt(0), 0) % 100;
            result[key] = hash < ((m.percentage as number) ?? 0);
          } else if (m.type === "user_list") {
            result[key] = ((m.user_ids as string[]) ?? []).includes(user.id);
          } else { result[key] = true; }
        }
        return new Response(JSON.stringify({ success: true, flags: result }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: list all flags
      const { data: flags } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "feature_flag").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, flags: (flags ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        const { key, type, description, enabled, percentage, user_ids } = body;
        if (!key) return new Response(JSON.stringify({ success: false, error: "key required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete().eq("source", "feature_flag").eq("metadata->>key", key);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "feature_flag",
          metadata: { key, type: type ?? "boolean", description: description ?? "", enabled: enabled ?? false, percentage: percentage ?? 100, user_ids: user_ids ?? [] },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, key }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "toggle") {
        const { key } = body;
        if (!key) return new Response(JSON.stringify({ success: false, error: "key required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: flag } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "feature_flag").eq("metadata->>key", key).maybeSingle();
        if (!flag) return new Response(JSON.stringify({ success: false, error: "Flag not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = flag.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({ metadata: { ...m, enabled: !m.enabled } })
          .eq("source", "feature_flag").eq("metadata->>key", key);
        return new Response(JSON.stringify({ success: true, enabled: !m.enabled }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
