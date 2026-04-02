// API Key Manager Edge Function
// API キー管理 (GitHub/Slack競合)
// - APIキー生成・管理
// - キー権限設定
// - 使用量追跡
// - キー無効化
//
// GET  → キー一覧 / 使用量
// POST → キー生成 / 無効化

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function generateApiKey(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return "jk_" + Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 40);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "usage") {
        const { data: usage } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "api_key_usage").order("created_at", { ascending: false }).limit(100);
        return new Response(JSON.stringify({
          success: true,
          usage: (usage ?? []).map((u) => ({ ...(u.metadata as Record<string, unknown>), usedAt: u.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      const { data: keys } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "api_key").order("created_at", { ascending: false });

      return new Response(JSON.stringify({
        success: true,
        keys: (keys ?? []).map((k) => {
          const meta = k.metadata as Record<string, unknown>;
          return {
            key_id: meta.key_id,
            name: meta.name,
            prefix: ((meta.key as string) ?? "").slice(0, 10) + "...",
            permissions: meta.permissions,
            active: meta.active,
            createdAt: k.created_at,
            lastUsed: meta.last_used,
          };
        }),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "generate") {
        const { name, permissions } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const key = generateApiKey();
        const keyId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "api_key",
          metadata: { key_id: keyId, name, key, permissions: permissions ?? ["read"], active: true, last_used: null },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        // Return full key only once
        return new Response(JSON.stringify({ success: true, keyId, key, name, warning: "このキーは一度だけ表示されます。安全に保管してください。" }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "revoke") {
        const { key_id } = body;
        if (!key_id) {
          return new Response(JSON.stringify({ success: false, error: "key_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "api_key").eq("metadata->>key_id", key_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Key not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { error } = await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), active: false } }).eq("user_id", user.id).eq("source", "api_key").eq("metadata->>key_id", key_id);
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, revoked: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
