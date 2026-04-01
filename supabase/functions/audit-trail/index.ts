// Audit Trail Edge Function
// 監査ログ管理 (Google Workspace/Microsoft 365/GitHub競合)
// - アクション記録
// - ユーザーアクティビティ
// - コンプライアンスレポート
// - 保持ポリシー
// - 検索・フィルタ

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const ACTION_CATEGORIES = ["auth", "data", "admin", "security", "billing", "integration", "system"];
const SEVERITY_LEVELS = ["info", "warning", "critical"];

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
      const category = url.searchParams.get("category");
      const severity = url.searchParams.get("severity");
      const userId = url.searchParams.get("user_id");
      const days = parseInt(url.searchParams.get("days") ?? "30", 10);

      if (view === "categories") return new Response(JSON.stringify({ success: true, categories: ACTION_CATEGORIES, severities: SEVERITY_LEVELS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "compliance_report") {
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: logs } = await adminClient.from("app_analytics").select("metadata").eq("source", "audit_log").gte("created_at", since);
        const catCount: Record<string, number> = {};
        const sevCount: Record<string, number> = {};
        for (const l of logs ?? []) {
          const m = l.metadata as Record<string, unknown>;
          catCount[(m.category as string) ?? "system"] = (catCount[(m.category as string) ?? "system"] ?? 0) + 1;
          sevCount[(m.severity as string) ?? "info"] = (sevCount[(m.severity as string) ?? "info"] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true, report: { period: `${days} days`, totalEvents: (logs ?? []).length, categoryBreakdown: catCount, severityBreakdown: sevCount, criticalEvents: sevCount["critical"] ?? 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "user_activity" && userId) {
        const { data: logs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "audit_log").eq("metadata->>actor_id", userId)
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: recent logs with filters
      const since = new Date(Date.now() - days * 86400000).toISOString();
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "audit_log").gte("created_at", since)
        .order("created_at", { ascending: false }).limit(100);
      if (category) query = query.eq("metadata->>category", category);
      if (severity) query = query.eq("metadata->>severity", severity);
      const { data: logs } = await query;
      return new Response(JSON.stringify({ success: true, logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "log") {
        const { event, category: cat, severity: sev, target_type, target_id, details } = body;
        if (!event) return new Response(JSON.stringify({ success: false, error: "event required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const logId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "audit_log",
          metadata: {
            log_id: logId, event, category: cat ?? "system", severity: sev ?? "info",
            actor_id: user.id, actor_email: user.email,
            target_type: target_type ?? null, target_id: target_id ?? null,
            details: details ?? {}, ip: req.headers.get("x-forwarded-for") ?? "unknown",
            user_agent: req.headers.get("user-agent") ?? "unknown",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, logId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
