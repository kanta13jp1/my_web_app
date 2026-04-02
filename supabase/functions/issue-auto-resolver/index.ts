// Issue Auto Resolver Edge Function
// GitHub Issue自動修正管理 (Schedule自動化用)
// - Issue一覧取得・優先度判定
// - 修正計画生成
// - 修正結果記録
// - Issue↔コミットの紐付け
//
// GET  → Issue一覧 / 修正履歴 / 統計
// POST → 修正記録 / ステータス更新

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "fix_history") {
        const { data: fixes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "issue_fix")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({
          success: true,
          fixes: (fixes ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: fixes } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "issue_fix");
        let resolved = 0, failed = 0, pending = 0;
        for (const f of fixes ?? []) {
          const meta = f.metadata as Record<string, unknown>;
          if (meta.status === "resolved") resolved++;
          else if (meta.status === "failed") failed++;
          else pending++;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { total: (fixes ?? []).length, resolved, failed, pending, resolveRate: (fixes ?? []).length > 0 ? Math.round(resolved / (fixes ?? []).length * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: open issues tracked
      const { data: issues } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "tracked_issue")
        .order("created_at", { ascending: false }).limit(50);
      return new Response(JSON.stringify({
        success: true,
        issues: (issues ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "track_issue") {
        const { issue_number, title, labels, body: issueBody, priority } = body;
        if (!issue_number || !title) {
          return new Response(JSON.stringify({ success: false, error: "issue_number and title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: "00000000-0000-0000-0000-000000000000", source: "tracked_issue",
          metadata: {
            issue_number, title, labels: labels ?? [],
            body: issueBody ?? null, priority: priority ?? "medium",
            status: "open", tracked_at: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, tracked: true }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_fix") {
        const { issue_number, commit_sha, fix_description, status, files_changed } = body;
        if (!issue_number || !status) {
          return new Response(JSON.stringify({ success: false, error: "issue_number and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const fixId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: "00000000-0000-0000-0000-000000000000", source: "issue_fix",
          metadata: {
            fix_id: fixId, issue_number, commit_sha: commit_sha ?? null,
            fix_description: fix_description ?? null, status,
            files_changed: files_changed ?? [],
            fixed_at: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });

        // Update tracked issue status
        if (status === "resolved") {
          const { data: existing } = await adminClient.from("app_analytics").select("metadata")
            .eq("source", "tracked_issue").eq("metadata->>issue_number", String(issue_number))
            .order("created_at", { ascending: false }).limit(1);
          if (existing?.[0]) {
            await adminClient.from("app_analytics").update({
              metadata: { ...(existing[0].metadata as Record<string, unknown>), status: "resolved", resolved_at: new Date().toISOString() },
            }).eq("source", "tracked_issue").eq("metadata->>issue_number", String(issue_number));
          }
        }

        return new Response(JSON.stringify({ success: true, fixId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
