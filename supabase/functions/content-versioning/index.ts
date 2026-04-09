// Content Versioning Edge Function
// コンテンツバージョン管理 (Google Docs/Notion/GitHub競合)
// - バージョン履歴
// - 差分表示
// - バージョン復元
// - 自動保存
// - 共同編集ロック

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

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
      const contentId = url.searchParams.get("content_id");
      const versionId = url.searchParams.get("version_id");

      if (view === "history" && contentId) {
        const { data: versions } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "content_version").eq("metadata->>content_id", contentId)
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, versions: (versions ?? []).map((v) => ({ ...(v.metadata as Record<string, unknown>), createdAt: v.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "version" && versionId) {
        const { data: version } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "content_version").eq("metadata->>version_id", versionId).maybeSingle();
        if (!version) return new Response(JSON.stringify({ success: false, error: "Version not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, version: { ...(version.metadata as Record<string, unknown>), createdAt: version.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "diff" && contentId) {
        const v1 = url.searchParams.get("v1");
        const v2 = url.searchParams.get("v2");
        if (!v1 || !v2) return new Response(JSON.stringify({ success: false, error: "v1 and v2 required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // 2バージョンを並列取得
        const [{ data: ver1 }, { data: ver2 }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata").eq("source", "content_version").eq("metadata->>version_id", v1).maybeSingle(),
          adminClient.from("app_analytics").select("metadata").eq("source", "content_version").eq("metadata->>version_id", v2).maybeSingle(),
        ]);
        if (!ver1 || !ver2) return new Response(JSON.stringify({ success: false, error: "Version not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const content1 = ((ver1.metadata as Record<string, unknown>).content as string) ?? "";
        const content2 = ((ver2.metadata as Record<string, unknown>).content as string) ?? "";
        return new Response(JSON.stringify({ success: true, v1: { id: v1, content: content1, length: content1.length }, v2: { id: v2, content: content2, length: content2.length }, lengthDiff: content2.length - content1.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "lock" && contentId) {
        const { data: lock } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "content_lock").eq("metadata->>content_id", contentId).maybeSingle();
        if (!lock) return new Response(JSON.stringify({ success: true, locked: false }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = lock.metadata as Record<string, unknown>;
        const lockTime = new Date(m.locked_at as string).getTime();
        const expired = Date.now() - lockTime > 300000; // 5 minutes
        return new Response(JSON.stringify({ success: true, locked: !expired, lockedBy: m.user_id, lockedAt: m.locked_at, expired }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, message: "Use view=history&content_id=<id> to get version history" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "save_version") {
        const { content_id, content, title, auto_save } = body;
        if (!content_id || !content) return new Response(JSON.stringify({ success: false, error: "content_id and content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Get current version number
        const { count } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "content_version").eq("metadata->>content_id", content_id);
        const versionNumber = (count ?? 0) + 1;
        const versionId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "content_version",
          metadata: { version_id: versionId, content_id, version: versionNumber, content, title: title ?? "", auto_save: auto_save ?? false, content_length: content.length },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, versionId, version: versionNumber }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "restore") {
        const { version_id } = body;
        if (!version_id) return new Response(JSON.stringify({ success: false, error: "version_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: version } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "content_version").eq("metadata->>version_id", version_id).maybeSingle();
        if (!version) return new Response(JSON.stringify({ success: false, error: "Version not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = version.metadata as Record<string, unknown>;
        // Save as new version
        const newVersionId = crypto.randomUUID();
        const { count } = await adminClient.from("app_analytics").select("*", { count: "exact", head: true })
          .eq("user_id", user.id).eq("source", "content_version").eq("metadata->>content_id", m.content_id as string);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "content_version",
          metadata: { ...m, version_id: newVersionId, version: (count ?? 0) + 1, restored_from: version_id, auto_save: false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, versionId: newVersionId, content: m.content }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "acquire_lock") {
        const { content_id } = body;
        if (!content_id) return new Response(JSON.stringify({ success: false, error: "content_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete().eq("source", "content_lock").eq("metadata->>content_id", content_id);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "content_lock",
          metadata: { content_id, user_id: user.id, user_email: user.email, locked_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, locked: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "release_lock") {
        const { content_id } = body;
        if (!content_id) return new Response(JSON.stringify({ success: false, error: "content_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete().eq("source", "content_lock").eq("metadata->>content_id", content_id).eq("metadata->>user_id", user.id);
        return new Response(JSON.stringify({ success: true, released: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
