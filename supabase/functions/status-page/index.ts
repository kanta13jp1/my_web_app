// Status Page Edge Function
// ステータスページ (GitHub Status/Atlassian Statuspage競合)
// - サービス状態管理
// - インシデント記録
// - メンテナンス予定
// - 稼働率計算
// - 通知配信

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SERVICE_STATUSES = ["operational", "degraded", "partial_outage", "major_outage", "maintenance"];
const INCIDENT_SEVERITIES = ["minor", "major", "critical"];
const COMPONENTS = [
  { id: "web_app", name: "Web Application", description: "Flutter Web フロントエンド" },
  { id: "api", name: "API (Edge Functions)", description: "Supabase Edge Functions" },
  { id: "database", name: "Database", description: "PostgreSQL (Supabase)" },
  { id: "auth", name: "Authentication", description: "認証サービス" },
  { id: "storage", name: "Storage", description: "ファイルストレージ" },
  { id: "cdn", name: "CDN", description: "Firebase Hosting" },
  { id: "ai", name: "AI Services", description: "AI アシスタント・分析" },
  { id: "email", name: "Email", description: "メール配信 (Resend)" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "current") {
        const statuses: Record<string, string> = {};
        for (const comp of COMPONENTS) {
          const { data: status } = await adminClient.from("app_analytics").select("metadata")
            .eq("source", "component_status").eq("metadata->>component_id", comp.id)
            .order("created_at", { ascending: false }).limit(1).maybeSingle();
          statuses[comp.id] = status ? ((status.metadata as Record<string, unknown>).status as string) : "operational";
        }
        const overallStatus = Object.values(statuses).includes("major_outage") ? "major_outage"
          : Object.values(statuses).includes("partial_outage") ? "partial_outage"
          : Object.values(statuses).includes("degraded") ? "degraded"
          : Object.values(statuses).includes("maintenance") ? "maintenance" : "operational";
        return new Response(JSON.stringify({
          success: true, overall: overallStatus,
          components: COMPONENTS.map((c) => ({ ...c, status: statuses[c.id] })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "incidents") {
        const { data: incidents } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "status_incident").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, incidents: (incidents ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "maintenance") {
        const { data: maint } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "status_maintenance").gte("metadata->>scheduled_end", new Date().toISOString())
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({ success: true, maintenance: (maint ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "uptime") {
        const days = parseInt(url.searchParams.get("days") ?? "30", 10);
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: incidents } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "status_incident").gte("created_at", since);
        let totalDowntimeMinutes = 0;
        for (const i of incidents ?? []) {
          totalDowntimeMinutes += (((i.metadata as Record<string, unknown>).duration_minutes as number) ?? 0);
        }
        const totalMinutes = days * 24 * 60;
        const uptime = Math.round(((totalMinutes - totalDowntimeMinutes) / totalMinutes) * 10000) / 100;
        return new Response(JSON.stringify({
          success: true, uptime: { percentage: uptime, days, totalIncidents: (incidents ?? []).length, totalDowntimeMinutes },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default
      return new Response(JSON.stringify({ success: true, components: COMPONENTS, statuses: SERVICE_STATUSES, severities: INCIDENT_SEVERITIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "update_status") {
        const { component_id, status } = body;
        if (!component_id || !status) return new Response(JSON.stringify({ success: false, error: "component_id and status required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: null, source: "component_status",
          metadata: { component_id, status, updated_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, updated: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_incident") {
        const { title, severity, components: affected, description } = body;
        if (!title || !severity) return new Response(JSON.stringify({ success: false, error: "title and severity required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const incidentId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: null, source: "status_incident",
          metadata: {
            incident_id: incidentId, title, severity, description: description ?? "",
            affected_components: affected ?? [], status: "investigating",
            started_at: new Date().toISOString(), resolved_at: null, duration_minutes: 0,
            updates: [{ status: "investigating", message: description ?? title, at: new Date().toISOString() }],
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, incidentId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "schedule_maintenance") {
        const { title, components: affected, scheduled_start, scheduled_end, description } = body;
        if (!title || !scheduled_start || !scheduled_end) return new Response(JSON.stringify({ success: false, error: "title, scheduled_start, scheduled_end required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const maintId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: null, source: "status_maintenance",
          metadata: { maintenance_id: maintId, title, description: description ?? "", affected_components: affected ?? [], scheduled_start, scheduled_end, status: "scheduled" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, maintenanceId: maintId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
