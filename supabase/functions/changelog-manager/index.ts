// Changelog & Release Notes Manager Edge Function
// チェンジログ・リリースノート管理 (GitHub Releases競合)
// - リリースノート作成
// - バージョン管理
// - カテゴリ別変更点
// - 公開/下書き管理
// - ユーザー通知

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CHANGE_TYPES = ["feature", "improvement", "bugfix", "security", "performance", "deprecation", "breaking"];
const RELEASE_STATUSES = ["draft", "published", "archived"];

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
      const version = url.searchParams.get("version");

      if (view === "types") return new Response(JSON.stringify({ success: true, changeTypes: CHANGE_TYPES, statuses: RELEASE_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "release" && version) {
        const { data: release } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "changelog_release").eq("metadata->>version", version).maybeSingle();
        if (!release) return new Response(JSON.stringify({ success: false, error: "Release not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: changes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "changelog_entry").eq("metadata->>version", version).order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          release: { ...(release.metadata as Record<string, unknown>), createdAt: release.created_at },
          changes: (changes ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: releases } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "changelog_release");
        const { data: entries } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "changelog_entry");
        const typeCount: Record<string, number> = {};
        for (const e of entries ?? []) {
          const t = ((e.metadata as Record<string, unknown>).type as string) ?? "feature";
          typeCount[t] = (typeCount[t] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true, stats: {
            totalReleases: (releases ?? []).length, totalChanges: (entries ?? []).length,
            typeBreakdown: typeCount,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: published releases
      const { data: releases } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "changelog_release").eq("metadata->>status", "published")
        .order("created_at", { ascending: false }).limit(20);
      return new Response(JSON.stringify({ success: true, releases: (releases ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_release") {
        const { version: ver, title, summary, status } = body;
        if (!ver || !title) return new Response(JSON.stringify({ success: false, error: "version and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const releaseId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "changelog_release",
          metadata: {
            release_id: releaseId, version: ver, title, summary: summary ?? "",
            status: status ?? "draft", author_id: user.id, author_email: user.email,
            published_at: status === "published" ? new Date().toISOString() : null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, releaseId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_change") {
        const { version: ver, type, description, breaking } = body;
        if (!ver || !type || !description) return new Response(JSON.stringify({ success: false, error: "version, type, and description required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const entryId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "changelog_entry",
          metadata: { entry_id: entryId, version: ver, type, description, breaking: breaking ?? false },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, entryId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "publish") {
        const { version: ver } = body;
        if (!ver) return new Response(JSON.stringify({ success: false, error: "version required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: release } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "changelog_release").eq("metadata->>version", ver).maybeSingle();
        if (!release) return new Response(JSON.stringify({ success: false, error: "Release not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({
          metadata: { ...(release.metadata as Record<string, unknown>), status: "published", published_at: new Date().toISOString() },
        }).eq("source", "changelog_release").eq("metadata->>version", ver);
        return new Response(JSON.stringify({ success: true, published: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "generate_markdown") {
        const { version: ver } = body;
        if (!ver) return new Response(JSON.stringify({ success: false, error: "version required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: release } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "changelog_release").eq("metadata->>version", ver).maybeSingle();
        const { data: changes } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "changelog_entry").eq("metadata->>version", ver);
        if (!release) return new Response(JSON.stringify({ success: false, error: "Release not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = release.metadata as Record<string, unknown>;
        const grouped: Record<string, string[]> = {};
        for (const c of changes ?? []) {
          const cm = c.metadata as Record<string, unknown>;
          const t = (cm.type as string) ?? "feature";
          if (!grouped[t]) grouped[t] = [];
          grouped[t].push(`- ${cm.description}${cm.breaking ? " ⚠️ **BREAKING**" : ""}`);
        }
        const typeLabels: Record<string, string> = { feature: "✨ New Features", improvement: "🔧 Improvements", bugfix: "🐛 Bug Fixes", security: "🔒 Security", performance: "⚡ Performance", deprecation: "⚠️ Deprecations", breaking: "💥 Breaking Changes" };
        let md = `# ${meta.version} - ${meta.title}\n\n${meta.summary}\n\n`;
        for (const [type, items] of Object.entries(grouped)) md += `## ${typeLabels[type] ?? type}\n${items.join("\n")}\n\n`;
        return new Response(JSON.stringify({ success: true, markdown: md }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
