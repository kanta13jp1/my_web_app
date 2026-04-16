// admin-hub — 管理・サポート・監視・分析統合EF
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin
    .from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at")
    .single();
  if (error) throw new Error(error.message);
  return data;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    // deno-lint-ignore no-explicit-any
    let body: Record<string, any> = {};
    if (req.method !== "GET") {
      try {
        body = await req.json();
      } catch {
        body = {};
      }
    }

    const action: string = body.action ?? "";
    const userId = await getUserId(req);
    if (!userId) {
      return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ---- Support tickets ----
      case "support.list": {
        const { data, error } = await admin
          .from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "support_ticket")
          .filter("metadata->>status", "neq", "closed")
          .order("created_at", { ascending: false })
          .limit(50);
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, tickets: data ?? [] });
      }

      case "support.create": {
        const item = await addItem(admin, "support_ticket", userId, {
          title: body.title,
          message: body.message,
          status: "open",
        });
        return json({ success: true, item });
      }

      case "support.reply": {
        if (!body.id) return json({ error: "id required" }, 400);
        await admin
          .from("hub_data")
          .update({
            metadata: {
              user_id: body.original_user_id ?? userId,
              status: body.new_status ?? "resolved",
              reply: body.reply,
              replied_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id))
          .eq("source", "support_ticket");
        return json({ success: true });
      }

      // ---- Competitor features ----
      case "competitor.list": {
        const { data } = await admin
          .from("competitor_features")
          .select("*")
          .order("updated_at", { ascending: false })
          .limit(50);
        return json({ success: true, features: data ?? [] });
      }

      // ---- Competitor availability check ----
      case "competitor.check": {
        const competitors = [
          "notion.so",
          "evernote.com",
          "slack.com",
          "moneyforward.com",
        ];
        const results = await Promise.allSettled(
          competitors.map(async (c) => {
            const r = await fetch(`https://${c}`, {
              signal: AbortSignal.timeout(5000),
            });
            return { site: c, ok: r.ok, status: r.status };
          }),
        );
        return json({
          success: true,
          results: results.map((r) =>
            r.status === "fulfilled"
              ? r.value
              : { site: "unknown", ok: false }
          ),
        });
      }

      // ---- Import preview / commit ----
      case "import.preview": {
        const items = await listItems(admin, "import_preview", userId);
        return json({ success: true, items });
      }

      case "import.commit": {
        const item = await addItem(admin, "import_commit", userId, {
          source: body.source,
          count: body.count,
          data: body.data,
        });
        return json({ success: true, item });
      }

      // ---- Health check ----
      case "health.check": {
        const checks = await Promise.allSettled([
          admin.from("hub_data").select("id").limit(1),
          admin.from("development_achievements").select("id").limit(1),
        ]);
        return json({
          success: true,
          db: checks.every((c) => c.status === "fulfilled"),
          timestamp: new Date().toISOString(),
        });
      }

      // ---- Competitor monitoring ----
      case "monitoring.get": {
        const items = await listItems(admin, "competitor_monitor", userId, 20);
        return json({ success: true, items });
      }

      case "monitoring.record": {
        const item = await addItem(admin, "competitor_monitor", userId, {
          competitor: body.competitor,
          change: body.change,
          url: body.url,
        });
        return json({ success: true, item });
      }

      // ---- AI quota monitoring ----
      case "quota.latest": {
        const { data, error } = await admin
          .from("ai_quota_usage")
          .select("tool, checked_at, usage_json, alert")
          .order("checked_at", { ascending: false })
          .limit(20);
        if (error) return json({ error: error.message }, 500);
        const latest = new Map<string, unknown>();
        for (const row of (data ?? [])) {
          if (!latest.has(row.tool)) latest.set(row.tool, row);
        }
        return json({ success: true, data: Array.from(latest.values()) });
      }

      case "quota.list": {
        const days = Number(body.days ?? 30);
        const since = new Date(Date.now() - days * 86400_000)
          .toISOString()
          .slice(0, 10);
        const { data, error } = await admin
          .from("ai_quota_usage")
          .select("*")
          .gte("checked_at", since)
          .order("checked_at", { ascending: false });
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, data });
      }

      case "quota.alert": {
        const today = new Date().toISOString().slice(0, 10);
        const { data, error } = await admin
          .from("ai_quota_usage")
          .select("tool, usage_json, alert")
          .eq("alert", true)
          .eq("checked_at", today);
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, data });
      }

      // ---- Edge function coverage ----
      case "ef.coverage": {
        const { data } = await admin
          .from("hub_data")
          .select("source")
          .eq("source", "ef_coverage")
          .order("created_at", { ascending: false })
          .limit(1);
        return json({ success: true, coverage: data?.[0] ?? null });
      }

      // ---- Content moderation ----
      case "moderation.check": {
        const item = await addItem(admin, "moderation_log", userId, {
          content: body.content,
          result: "pending",
          flagged: false,
        });
        return json({ success: true, item });
      }

      // ---- User activity ----
      case "activity.list": {
        const items = await listItems(admin, "user_activity", userId);
        return json({ success: true, items });
      }

      case "activity.track": {
        const item = await addItem(admin, "user_activity", userId, {
          event: body.event,
          page: body.page,
          metadata: body.metadata ?? {},
        });
        return json({ success: true, item });
      }

      // ---- Department reporting ----
      case "reporting.get": {
        const items = await listItems(admin, "dept_report", userId);
        return json({ success: true, items });
      }

      // ---- Admin notifications ----
      case "admin.notify": {
        const item = await addItem(admin, "admin_notification", userId, {
          title: body.title,
          message: body.message,
          priority: body.priority ?? "normal",
        });
        return json({ success: true, item });
      }

      // ---- Issue auto-resolver ----
      case "issue.list": {
        const items = await listItems(admin, "auto_issue", userId);
        return json({ success: true, items });
      }

      case "issue.resolve": {
        const item = await addItem(admin, "auto_issue_resolved", userId, {
          issue_id: body.issue_id,
          resolution: body.resolution,
        });
        return json({ success: true, item });
      }

      // ---- Users list (admin) ----
      case "users.list": {
        const { data } = await admin.auth.admin.listUsers({
          page: 1,
          perPage: 100,
        });
        return json({
          success: true,
          users:
            data?.users?.map((u) => ({
              id: u.id,
              email: u.email,
              created_at: u.created_at,
            })) ?? [],
          total: data?.total ?? 0,
        });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
