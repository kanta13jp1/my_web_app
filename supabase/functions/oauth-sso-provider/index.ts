// OAuth SSO Provider Edge Function
// SSO/OAuth管理 (GitHub/Google/Microsoft/Slack/ジョブカン競合)
// - OAuthプロバイダー設定
// - SSO接続管理
// - プロバイダー別ログイン履歴
// - エンタープライズSSOサポート
//
// GET  → プロバイダー一覧 / 接続状態 / ログイン履歴
// POST → プロバイダー接続 / 切断 / テスト

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SSO_PROVIDERS = [
  { key: "google", name: "Google", icon: "🔵", protocol: "oauth2", description: "Googleアカウントでログイン" },
  { key: "github", name: "GitHub", icon: "🐙", protocol: "oauth2", description: "GitHubアカウントでログイン" },
  { key: "microsoft", name: "Microsoft", icon: "🟦", protocol: "oauth2", description: "Microsoftアカウントでログイン" },
  { key: "slack", name: "Slack", icon: "💬", protocol: "oauth2", description: "Slackワークスペースでログイン" },
  { key: "line", name: "LINE", icon: "💚", protocol: "oauth2", description: "LINEアカウントでログイン" },
  { key: "discord", name: "Discord", icon: "🎮", protocol: "oauth2", description: "Discordアカウントでログイン" },
  { key: "facebook", name: "Facebook", icon: "📘", protocol: "oauth2", description: "Facebookアカウントでログイン" },
  { key: "saml", name: "SAML SSO", icon: "🔐", protocol: "saml", description: "エンタープライズSAML SSO" },
];

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

      if (view === "providers") {
        return new Response(JSON.stringify({ success: true, providers: SSO_PROVIDERS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "login_history") {
        const { data: history } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "sso_login").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          history: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), loginAt: h.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: connected providers
      const { data: connections } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "sso_connection").order("created_at", { ascending: false });
      const connectedMap = new Map<string, Record<string, unknown>>();
      for (const c of connections ?? []) {
        const meta = c.metadata as Record<string, unknown>;
        const provider = meta.provider as string;
        if (!connectedMap.has(provider)) {
          connectedMap.set(provider, { ...meta, connectedAt: c.created_at });
        }
      }

      return new Response(JSON.stringify({
        success: true,
        providers: SSO_PROVIDERS.map((p) => ({
          ...p,
          connected: connectedMap.has(p.key) && (connectedMap.get(p.key)!.active as boolean) === true,
          connection: connectedMap.get(p.key) ?? null,
        })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "connect") {
        const { provider, external_id, external_email, config } = body;
        if (!provider) {
          return new Response(JSON.stringify({ success: false, error: "provider required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const valid = SSO_PROVIDERS.find((p) => p.key === provider);
        if (!valid) {
          return new Response(JSON.stringify({ success: false, error: "Unknown provider" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const connectionId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "sso_connection",
          metadata: {
            connection_id: connectionId,
            provider,
            provider_name: valid.name,
            external_id: external_id ?? null,
            external_email: external_email ?? null,
            config: config ?? {},
            active: true,
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;

        // Log login event
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "sso_login",
          metadata: { provider, provider_name: valid.name, connection_id: connectionId },
          created_at: new Date().toISOString(),
        });

        return new Response(JSON.stringify({ success: true, connectionId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "disconnect") {
        const { provider } = body;
        if (!provider) {
          return new Response(JSON.stringify({ success: false, error: "provider required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "sso_connection").eq("metadata->>provider", provider).eq("metadata->>active", "true").order("created_at", { ascending: false }).limit(1);
        if (!existing?.[0]) {
          return new Response(JSON.stringify({ success: false, error: "Connection not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const meta = existing[0].metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, active: false, disconnected_at: new Date().toISOString() },
        }).eq("user_id", user.id).eq("source", "sso_connection").eq("metadata->>connection_id", meta.connection_id as string);

        return new Response(JSON.stringify({ success: true, disconnected: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "test") {
        const { provider } = body;
        if (!provider) {
          return new Response(JSON.stringify({ success: false, error: "provider required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const valid = SSO_PROVIDERS.find((p) => p.key === provider);
        if (!valid) {
          return new Response(JSON.stringify({ success: false, error: "Unknown provider" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        // Check if connected
        const { data: connection } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "sso_connection").eq("metadata->>provider", provider).eq("metadata->>active", "true").maybeSingle();

        return new Response(JSON.stringify({
          success: true,
          provider: valid.name,
          connected: !!connection,
          test_result: connection ? "OK" : "NOT_CONNECTED",
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
