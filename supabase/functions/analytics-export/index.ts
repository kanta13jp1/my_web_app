// Analytics Export Edge Function
// 分析データエクスポート (Google Analytics/Microsoft競合)
// - レポート生成
// - CSV/JSON/PDF形式
// - スケジュールレポート
// - カスタムダッシュボード
// - メール配信

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const REPORT_TYPES = ["user_activity", "feature_usage", "growth_metrics", "revenue", "engagement", "custom"];
const EXPORT_FORMATS = ["json", "csv", "markdown"];
const TIME_RANGES = ["today", "yesterday", "last_7_days", "last_30_days", "last_90_days", "this_month", "this_year", "custom"];

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

      if (view === "options") return new Response(JSON.stringify({ success: true, reportTypes: REPORT_TYPES, exportFormats: EXPORT_FORMATS, timeRanges: TIME_RANGES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "scheduled") {
        const { data: scheduled } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "scheduled_report").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, reports: (scheduled ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "history") {
        const { data: exports } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "export_record").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, exports: (exports ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, reportTypes: REPORT_TYPES, formats: EXPORT_FORMATS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "generate_report") {
        const { type, time_range, format, date_from } = body;
        if (!type) return new Response(JSON.stringify({ success: false, error: "type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const now = new Date();
        let since: string;
        const range = time_range ?? "last_30_days";
        if (range === "today") since = new Date(now.setHours(0, 0, 0, 0)).toISOString();
        else if (range === "last_7_days") since = new Date(Date.now() - 7 * 86400000).toISOString();
        else if (range === "last_90_days") since = new Date(Date.now() - 90 * 86400000).toISOString();
        else if (range === "custom" && date_from) since = date_from;
        else since = new Date(Date.now() - 30 * 86400000).toISOString();

        const { data, count } = await adminClient.from("app_analytics").select("source, metadata, created_at", { count: "exact" })
          .gte("created_at", since).order("created_at", { ascending: false }).limit(5000);

        // Source distribution
        const sourceCount: Record<string, number> = {};
        for (const row of data ?? []) {
          sourceCount[row.source] = (sourceCount[row.source] ?? 0) + 1;
        }

        const reportId = crypto.randomUUID();
        const report = {
          reportId, type, timeRange: range, since,
          totalRecords: count ?? 0, sourceDistribution: sourceCount,
          generatedAt: new Date().toISOString(),
        };

        // Save export record
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "export_record",
          metadata: { ...report, format: format ?? "json" },
          created_at: new Date().toISOString(),
        });

        if (format === "csv") {
          const header = "source,created_at,metadata\n";
          const rows = (data ?? []).slice(0, 1000).map((r) => `"${r.source}","${r.created_at}","${JSON.stringify(r.metadata).replace(/"/g, '""')}"`).join("\n");
          return new Response(header + rows, { headers: { ...corsHeaders, "Content-Type": "text/csv", "Content-Disposition": `attachment; filename="report-${reportId}.csv"` } });
        }

        if (format === "markdown") {
          let md = `# Analytics Report\n\n- Type: ${type}\n- Period: ${range}\n- Total Records: ${count}\n- Generated: ${new Date().toISOString()}\n\n## Source Distribution\n\n| Source | Count |\n|--------|-------|\n`;
          for (const [src, cnt] of Object.entries(sourceCount).sort(([, a], [, b]) => (b as number) - (a as number))) md += `| ${src} | ${cnt} |\n`;
          return new Response(md, { headers: { ...corsHeaders, "Content-Type": "text/markdown" } });
        }

        return new Response(JSON.stringify({ success: true, report }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "schedule_report") {
        const { type, time_range, format, frequency, email } = body;
        if (!type || !frequency) return new Response(JSON.stringify({ success: false, error: "type and frequency required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const schedId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "scheduled_report",
          metadata: { schedule_id: schedId, type, time_range: time_range ?? "last_7_days", format: format ?? "json", frequency, email: email ?? user.email, enabled: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, scheduleId: schedId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
