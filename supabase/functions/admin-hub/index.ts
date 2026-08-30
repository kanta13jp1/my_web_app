// admin-hub — 管理・サポート・監視・分析統合EF
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildAiRouterCostDashboard,
  normalizeAiRoutingTask,
} from "../_shared/ai_router_cost_optimization.ts";
import {
  normalizeTaskBudgetDocuments,
  normalizeTaskBudgetEffort,
  normalizeTaskBudgetTokens,
  runTaskBudgetAssistant,
} from "../_shared/task_budget_assistant.ts";
import { mapAutoErrorReports } from "./auto_error_reports.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
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
    // Service-role key bypass: schedule tasks (cs-check etc.) use the service key,
    // which cannot pass auth.getUser(). Allow access for admin actions.
    const authHeader = req.headers.get("Authorization") ?? "";
    const isServiceRole = SERVICE_ROLE_KEY !== "" &&
      authHeader === `Bearer ${SERVICE_ROLE_KEY}`;
    if (!userId && !isServiceRole) {
      return json({ error: "Unauthorized" }, 401);
    }
    const effectiveUserId = userId ?? "service-role";

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
        const item = await addItem(admin, "support_ticket", effectiveUserId, {
          title: body.title,
          message: body.message,
          status: "open",
        });
        return json({ success: true, item });
      }

      // ---- 自動エラー報告 (error_reporter) の可視化 ----
      // error_reporter が hub_data へ無言で送っている caught error を
      // 管理ダッシュボードで見えるようにする読み取り専用 action。
      // admin-hub に role ゲートが無いため、他ユーザーの stack を晒さないよう
      // 呼び出し元(=管理者)自身の報告のみ返す (metadata.user_id 一致)。
      // 全ユーザー横断は admin ロール導入後に広げること。
      case "errors.recent": {
        const limit = Math.min(
          Math.max(Number(body.limit) || 20, 1),
          50,
        );
        const { data, error } = await admin
          .from("hub_data")
          .select("id, metadata, created_at")
          .eq("source", "user_feedback")
          .filter("metadata->>source", "eq", "auto_error_report")
          .filter("metadata->>user_id", "eq", effectiveUserId)
          .order("created_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 400);
        const errors = mapAutoErrorReports(data ?? []);
        return json({ success: true, errors, count: errors.length });
      }

      case "support.reply": {
        if (!body.id) return json({ error: "id required" }, 400);
        await admin
          .from("hub_data")
          .update({
            metadata: {
              user_id: body.original_user_id ?? effectiveUserId,
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

      // ---- Competitor availability check (14社) ----
      case "competitor.check": {
        const competitors = [
          "notion.so",
          "evernote.com",
          "slack.com",
          "moneyforward.com",
          "x.com",
          "chatwork.com",
          "jobcan.ne.jp",
          "amazon.co.jp",
          "netkeiba.com",
          "openai.com",
          "claude.ai",
          "animaworks.com",
          "github.com",
          "discord.com",
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
            r.status === "fulfilled" ? r.value : { site: "unknown", ok: false }
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
        const t0 = Date.now();
        const [hubCheck, achieveCheck, efCheck] = await Promise.allSettled([
          admin.from("hub_data").select("id").limit(1),
          admin.from("development_achievements").select("id").limit(1),
          admin.from("ai_circuit_breaker").select("id").limit(1),
        ]);
        const t1 = Date.now();
        const dbOk = hubCheck.status === "fulfilled" && !hubCheck.value.error;
        const achieveOk = achieveCheck.status === "fulfilled" &&
          !achieveCheck.value.error;
        const efOk = efCheck.status === "fulfilled" && !efCheck.value.error;
        const allOk = dbOk && achieveOk;
        const status = allOk ? (efOk ? "healthy" : "degraded") : "unhealthy";
        return json({
          success: true,
          status,
          checks: {
            database: { ok: dbOk, latencyMs: t1 - t0 },
            achievements: { ok: achieveOk, latencyMs: t1 - t0 },
            circuit_breaker: { ok: efOk, latencyMs: t1 - t0 },
          },
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

      case "ai_router.cost_dashboard": {
        const rawDays = Number(body.days ?? 30);
        const days = Number.isFinite(rawDays)
          ? Math.max(1, Math.min(90, Math.round(rawDays)))
          : 30;
        const since = new Date(Date.now() - days * 86400_000).toISOString();
        const { data: telemetryRows, error: telemetryError } = await admin
          .from("ai_hub_chat_logs")
          .select(
            "provider, model, tier, action, routing_use_case, success, " +
              "estimated_cost_usd, latency_ms, input_chars, output_chars, created_at",
          )
          .gte("created_at", since)
          .order("created_at", { ascending: false })
          .limit(2000);
        if (telemetryError) return json({ error: telemetryError.message }, 500);

        const { data: quotaRows, error: quotaError } = await admin
          .from("ai_quota_usage")
          .select("tool, checked_at, usage_json, alert")
          .order("checked_at", { ascending: false })
          .limit(100);
        if (quotaError) return json({ error: quotaError.message }, 500);

        let preferenceRows: Record<string, unknown>[] = [];
        if (userId) {
          const { data: prefs, error: prefError } = await admin
            .from("ai_task_routing_preferences")
            .select("task, provider, model, is_enabled, updated_at")
            .eq("user_id", userId);
          if (prefError) return json({ error: prefError.message }, 500);
          preferenceRows = (prefs ?? []) as Record<string, unknown>[];
        }

        const dashboard = buildAiRouterCostDashboard(
          (telemetryRows ?? []) as unknown as Record<string, unknown>[],
          (quotaRows ?? []) as unknown as Record<string, unknown>[],
          preferenceRows,
        );
        return json({ success: true, days, ...dashboard });
      }

      case "ai_router.preference.list": {
        if (!userId) return json({ error: "User auth required" }, 401);
        const { data, error } = await admin
          .from("ai_task_routing_preferences")
          .select("task, provider, model, is_enabled, updated_at")
          .eq("user_id", userId)
          .order("task", { ascending: true });
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, data: data ?? [] });
      }

      case "ai_router.preference.set": {
        if (!userId) return json({ error: "User auth required" }, 401);
        const task = normalizeAiRoutingTask(
          body.task ?? body.routing_use_case ?? body.action_key,
        );
        const provider = String(body.provider ?? "").trim();
        if (!provider) return json({ error: "provider required" }, 400);
        const model = String(body.model ?? "").trim() || null;
        const isEnabled = body.is_enabled !== false;
        const { data, error } = await admin
          .from("ai_task_routing_preferences")
          .upsert({
            user_id: userId,
            task,
            provider,
            model,
            is_enabled: isEnabled,
            source: "manual",
            updated_at: new Date().toISOString(),
          }, { onConflict: "user_id,task" })
          .select("task, provider, model, is_enabled, updated_at")
          .single();
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, preference: data });
      }

      case "task_budget_assistant.job.create": {
        if (!userId) return json({ error: "User auth required" }, 401);
        const title = String(body.title ?? "Task budget job").trim();
        const objective = String(body.objective ?? body.prompt ?? "").trim();
        if (!objective) return json({ error: "objective required" }, 400);

        const documents = normalizeTaskBudgetDocuments(
          body.documents ?? body.files ?? body.inputs,
        );
        if (documents.length === 0) {
          return json({ error: "documents required" }, 400);
        }

        const budgetTokens = normalizeTaskBudgetTokens(
          body.budget_tokens ?? body.token_budget,
        );
        const effort = normalizeTaskBudgetEffort(body.effort);
        const run = runTaskBudgetAssistant({
          objective,
          documents,
          budget_tokens: budgetTokens,
          effort,
        });

        const { data: job, error: jobError } = await admin
          .from("ai_task_budget_jobs")
          .insert({
            user_id: userId,
            title: title || "Task budget job",
            objective,
            budget_tokens: budgetTokens,
            consumed_tokens: run.consumed_tokens,
            effort,
            status: run.status,
            progress_percent: run.progress_percent,
            document_count: documents.length,
            summary: run.summary,
            artifact: run.artifact,
            completed_at: new Date().toISOString(),
          })
          .select("*")
          .single();
        if (jobError) return json({ error: jobError.message }, 500);

        const stepRows = run.steps.map((step) => ({
          job_id: job.id,
          user_id: userId,
          step_index: step.step_index,
          title: step.title,
          status: step.status,
          input_tokens: step.input_tokens,
          output_tokens: step.output_tokens,
          notes: step.notes,
        }));
        let steps: unknown[] = [];
        if (stepRows.length > 0) {
          const { data: insertedSteps, error: stepError } = await admin
            .from("ai_task_budget_job_steps")
            .insert(stepRows)
            .select("*")
            .order("step_index", { ascending: true });
          if (stepError) return json({ error: stepError.message }, 500);
          steps = insertedSteps ?? [];
        }

        return json({ success: true, job, steps });
      }

      case "task_budget_assistant.job.list": {
        if (!userId) return json({ error: "User auth required" }, 401);
        const requestedLimit = Number(body.limit ?? 20);
        const limit = Number.isFinite(requestedLimit)
          ? Math.max(1, Math.min(50, Math.round(requestedLimit)))
          : 20;
        const { data, error } = await admin
          .from("ai_task_budget_jobs")
          .select(
            "id, title, objective, budget_tokens, consumed_tokens, effort, status, progress_percent, document_count, summary, artifact, created_at, updated_at, completed_at",
          )
          .eq("user_id", userId)
          .order("updated_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, jobs: data ?? [] });
      }

      case "task_budget_assistant.job.get": {
        if (!userId) return json({ error: "User auth required" }, 401);
        const id = String(body.id ?? body.job_id ?? "").trim();
        if (!id) return json({ error: "id required" }, 400);
        const { data: job, error: jobError } = await admin
          .from("ai_task_budget_jobs")
          .select("*")
          .eq("id", id)
          .eq("user_id", userId)
          .maybeSingle();
        if (jobError) return json({ error: jobError.message }, 500);
        if (!job) return json({ error: "job not found" }, 404);

        const { data: steps, error: stepsError } = await admin
          .from("ai_task_budget_job_steps")
          .select("*")
          .eq("job_id", id)
          .eq("user_id", userId)
          .order("step_index", { ascending: true });
        if (stepsError) return json({ error: stepsError.message }, 500);
        return json({ success: true, job, steps: steps ?? [] });
      }

      case "task_budget_assistant.job.cancel": {
        if (!userId) return json({ error: "User auth required" }, 401);
        const id = String(body.id ?? body.job_id ?? "").trim();
        if (!id) return json({ error: "id required" }, 400);
        const { data, error } = await admin
          .from("ai_task_budget_jobs")
          .update({
            status: "cancelled",
            summary: "Cancelled by user before further autonomous work.",
            completed_at: new Date().toISOString(),
          })
          .eq("id", id)
          .eq("user_id", userId)
          .in("status", ["queued", "running"])
          .select("*")
          .maybeSingle();
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, job: data });
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
        const SEVERITY: Record<
          string,
          { priority: number; label: string; color: string }
        > = {
          critical: { priority: 1, label: "緊急", color: "#dc2626" },
          warning: { priority: 2, label: "警告", color: "#f59e0b" },
          info: { priority: 3, label: "情報", color: "#3b82f6" },
          success: { priority: 4, label: "成功", color: "#10b981" },
        };
        const severity: string = body.severity ?? "info";
        const sev = SEVERITY[severity] ?? SEVERITY.info;
        const item = await addItem(admin, "admin_notification", userId, {
          title: body.title,
          message: body.message ?? "",
          severity,
          severityLabel: sev.label,
          severityColor: sev.color,
          priority: body.priority ?? sev.priority,
          category: body.category ?? "system_update",
          extra: body.metadata ?? {},
        });
        return json({ success: true, item });
      }

      case "admin.notifications.list": {
        const severityFilter: string | undefined = body.severity;
        const categoryFilter: string | undefined = body.category;
        const limit: number = typeof body.limit === "number" ? body.limit : 50;
        const items = await listItems(
          admin,
          "admin_notification",
          userId,
          limit,
        );
        const { data: reads } = await admin
          .from("hub_data")
          .select("metadata")
          .eq("source", "admin_notification_read")
          .filter("metadata->>user_id", "eq", userId)
          .limit(500);
        const readIds = new Set<string>(
          (reads ?? [])
            .map((r) =>
              (r.metadata as Record<string, unknown>)?.notificationId as
                | string
                | undefined
            )
            .filter((x): x is string => typeof x === "string"),
        );
        const notifications = items
          .map((n) => {
            const m = (n.metadata ?? {}) as Record<string, unknown>;
            return {
              id: n.id,
              title: m.title ?? "",
              message: m.message ?? "",
              severity: m.severity ?? "info",
              severityLabel: m.severityLabel ?? "情報",
              severityColor: m.severityColor ?? "#3b82f6",
              priority: m.priority ?? 3,
              category: m.category ?? "system_update",
              is_read: readIds.has(n.id),
              created_at: n.created_at,
            };
          })
          .filter((n) => {
            if (severityFilter && n.severity !== severityFilter) return false;
            if (categoryFilter && n.category !== categoryFilter) return false;
            return true;
          });
        const unreadCount = notifications.filter((n) => !n.is_read).length;
        const criticalCount = notifications.filter((n) =>
          n.severity === "critical"
        ).length;
        return json({
          success: true,
          totalCount: notifications.length,
          unreadCount,
          criticalCount,
          notifications,
        });
      }

      case "admin.notifications.mark_read": {
        const notificationId: string = body.id ?? body.notificationId ?? "";
        if (!notificationId) return json({ error: "id required" }, 400);
        await addItem(admin, "admin_notification_read", userId, {
          notificationId,
          readAt: new Date().toISOString(),
        });
        return json({ success: true, notificationId });
      }

      case "admin.notifications.summary": {
        const { data: recent } = await admin
          .from("hub_data")
          .select("metadata, created_at")
          .eq("source", "admin_notification")
          .filter("metadata->>user_id", "eq", userId)
          .gte("created_at", new Date(Date.now() - 24 * 3600000).toISOString())
          .order("created_at", { ascending: false })
          .limit(100);
        const bySeverity: Record<string, number> = {
          critical: 0,
          warning: 0,
          info: 0,
          success: 0,
        };
        for (const r of recent ?? []) {
          const sev = ((r.metadata ?? {}) as Record<string, unknown>)
            .severity as string;
          if (sev in bySeverity) bySeverity[sev]++;
        }
        return json({
          success: true,
          last24h: (recent ?? []).length,
          bySeverity,
          needsAttention: bySeverity.critical + bySeverity.warning,
        });
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

      // ---- Data export (GDPR portability) ----
      case "data.export_available": {
        const tables = [
          { key: "profile", table: "user_profiles", label: "プロフィール" },
          { key: "notes", table: "notes", label: "ノート" },
          {
            key: "feature_requests",
            table: "feature_requests",
            label: "機能リクエスト",
          },
          { key: "notifications", table: "app_notifications", label: "通知" },
        ];
        const counts: Array<{ key: string; label: string; count: number }> = [];
        for (const t of tables) {
          const { count } = await admin
            .from(t.table)
            .select("*", { count: "exact", head: true })
            .eq("user_id", userId);
          counts.push({ key: t.key, label: t.label, count: count ?? 0 });
        }
        return json({ success: true, available: counts });
      }

      case "data.export": {
        const exportTables = [
          { key: "profile", table: "user_profiles" },
          { key: "notes", table: "notes" },
          { key: "feature_requests", table: "feature_requests" },
          { key: "notifications", table: "app_notifications" },
        ];
        const requested: string[] | undefined = Array.isArray(body.tables)
          ? body.tables
          : undefined;
        const targets = requested
          ? exportTables.filter((t) => requested.includes(t.key))
          : exportTables;
        if (targets.length === 0) {
          return json({ error: "No valid tables specified" }, 400);
        }
        const exportData: Record<string, unknown[]> = {};
        let totalRecords = 0;
        for (const t of targets) {
          const { data } = await admin
            .from(t.table)
            .select("*")
            .eq("user_id", userId)
            .order("created_at", { ascending: false });
          exportData[t.key] = data ?? [];
          totalRecords += (data ?? []).length;
        }
        const exportedAt = new Date().toISOString();
        await addItem(admin, "data_export", userId, {
          tables: targets.map((t) => t.key),
          totalRecords,
          exportedAt,
        });
        return json({
          success: true,
          export: {
            format: "json",
            exportedAt,
            userId,
            totalRecords,
            data: exportData,
          },
        });
      }

      // ---- Users list (admin) ----
      case "users.list": {
        const { data } = await admin.auth.admin.listUsers({
          page: 1,
          perPage: 100,
        });
        return json({
          success: true,
          users: data?.users?.map((u) => ({
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
