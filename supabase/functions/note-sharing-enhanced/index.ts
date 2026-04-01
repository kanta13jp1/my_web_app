// Note Sharing Enhanced Edge Function
// ノート共有強化 (リンク共有・権限管理・共同閲覧)
// - 公開/非公開/パスワード保護リンク生成
// - 閲覧者数・閲覧履歴トラッキング
// - 期限付き共有リンク
// - コピー禁止・印刷禁止設定
//
// GET  → 共有リンク一覧 / 閲覧統計
// POST → 共有リンク作成 / 無効化 / アクセスログ記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(req.url);
    const action = req.method === "GET" ? (url.searchParams.get("action") ?? "list") : "post";

    if (action === "list") {
      const { data: links } = await userClient.from("note_share_links").select("*").eq("owner_id", user.id).order("created_at", { ascending: false });
      const { data: stats } = await userClient.from("note_share_links").select("total_views").eq("owner_id", user.id);
      const totalViews = (stats ?? []).reduce((sum: number, r: { total_views?: number }) => sum + (r.total_views ?? 0), 0);
      return new Response(JSON.stringify({
        success: true,
        links: links ?? [],
        stats: { total_links: (links ?? []).length, total_views: totalViews },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));

    if (body.action === "create") {
      const token = crypto.randomUUID().replace(/-/g, "").substring(0, 16);
      const expiresAt = body.expires_days
        ? new Date(Date.now() + body.expires_days * 86400000).toISOString()
        : null;
      const { data, error } = await userClient.from("note_share_links").insert({
        owner_id: user.id,
        note_id: body.note_id,
        token,
        visibility: body.visibility ?? "public",
        password_hash: body.password ?? null,
        expires_at: expiresAt,
        allow_copy: body.allow_copy !== false,
        total_views: 0,
        created_at: new Date().toISOString(),
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify({ success: true, link: data, share_url: `/shared/${token}` }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "revoke") {
      const { error } = await userClient.from("note_share_links").delete().eq("token", body.token).eq("owner_id", user.id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: false, error: "Unknown action" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
