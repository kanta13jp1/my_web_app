import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface CapacityMonthlyStatRow {
  report_month: string;
  user_access_count: number;
  batch_job_count: number;
  error_count: number;
  error_rate_percent: number;
  notified_at: string | null;
  summary_payload: Record<string, unknown>;
  updated_at: string;
}

export interface CapacityStoreResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface CapacityAdminProfileRow {
  is_admin?: boolean | null;
  role?: string | null;
}

export interface CapacityCallerContext {
  userId: string | null;
  isServiceRole: boolean;
}

export interface CapacityServiceResponse {
  status: number;
  body: Record<string, unknown>;
}

export type FetchLike = (
  input: string | URL,
  init?: RequestInit,
) => Promise<Response>;

export interface CapacityReportStore {
  getAdminProfile(
    userId: string,
  ): Promise<CapacityStoreResult<CapacityAdminProfileRow>>;
  listMonthlyStats(
    limit: number,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow[]>>;
  getMonthlyStat(
    reportMonth: string,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow>>;
  aggregateMonthlyStat(
    reportMonth: string,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow>>;
  markNotified(
    reportMonth: string,
    notifiedAtIso: string,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow>>;
  recordAdminNotification(
    actorId: string,
    metadata: Record<string, unknown>,
  ): Promise<CapacityStoreResult<unknown>>;
}

export interface CapacityNotifyOptions {
  fetchFn?: FetchLike;
  resendKey?: string;
  fromEmail?: string;
  slackWebhookUrl?: string;
  defaultRecipients?: string[];
  now?: Date;
}

const REPORT_MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const SELECT_COLUMNS =
  "report_month,user_access_count,batch_job_count,error_count,error_rate_percent,notified_at,summary_payload,updated_at";

function normalizeStatRow(
  raw: Record<string, unknown>,
): CapacityMonthlyStatRow {
  const payloadRaw = raw.summary_payload;
  const summaryPayload =
    payloadRaw !== null && typeof payloadRaw === "object" &&
      !Array.isArray(payloadRaw)
      ? (payloadRaw as Record<string, unknown>)
      : {};
  const errRateRaw = Number(raw.error_rate_percent ?? 0);
  return {
    report_month: String(raw.report_month ?? ""),
    user_access_count: Math.max(0, Math.trunc(Number(raw.user_access_count ?? 0))),
    batch_job_count: Math.max(0, Math.trunc(Number(raw.batch_job_count ?? 0))),
    error_count: Math.max(0, Math.trunc(Number(raw.error_count ?? 0))),
    error_rate_percent: Number.isFinite(errRateRaw)
      ? Math.round(errRateRaw * 100) / 100
      : 0,
    notified_at: typeof raw.notified_at === "string" && raw.notified_at !== ""
      ? raw.notified_at
      : null,
    summary_payload: summaryPayload,
    updated_at: String(raw.updated_at ?? ""),
  };
}

export function createSupabaseCapacityReportStore(
  admin: SupabaseClient,
): CapacityReportStore {
  return {
    async getAdminProfile(userId) {
      const { data, error } = await admin
        .from("user_profiles")
        .select("is_admin, role")
        .eq("user_id", userId)
        .maybeSingle();
      return {
        data: data ? (data as CapacityAdminProfileRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async listMonthlyStats(limit) {
      const { data, error } = await admin
        .from("system_capacity_monthly_stats")
        .select(SELECT_COLUMNS)
        .order("report_month", { ascending: false })
        .limit(limit);
      return {
        data: Array.isArray(data)
          ? data.map((row) =>
            normalizeStatRow(row as Record<string, unknown>)
          )
          : null,
        error: error ? { message: error.message } : null,
      };
    },
    async getMonthlyStat(reportMonth) {
      const { data, error } = await admin
        .from("system_capacity_monthly_stats")
        .select(SELECT_COLUMNS)
        .eq("report_month", reportMonth)
        .maybeSingle();
      return {
        data: data ? normalizeStatRow(data as Record<string, unknown>) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async aggregateMonthlyStat(reportMonth) {
      const { data, error } = await admin.rpc(
        "aggregate_monthly_system_capacity",
        { p_month: reportMonth },
      );
      if (error) {
        return { data: null, error: { message: error.message } };
      }
      const row = Array.isArray(data) ? data[0] : data;
      return {
        data: row ? normalizeStatRow(row as Record<string, unknown>) : null,
        error: null,
      };
    },
    async markNotified(reportMonth, notifiedAtIso) {
      const { data, error } = await admin
        .from("system_capacity_monthly_stats")
        .update({
          notified_at: notifiedAtIso,
          updated_at: notifiedAtIso,
        })
        .eq("report_month", reportMonth)
        .select(SELECT_COLUMNS)
        .maybeSingle();
      return {
        data: data ? normalizeStatRow(data as Record<string, unknown>) : null,
        error: error ? { message: error.message } : null,
      };
    },
    async recordAdminNotification(actorId, metadata) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: "admin_notification",
          metadata: { ...metadata, user_id: actorId },
        })
        .select("id, metadata, created_at")
        .single();
      return {
        data: data ?? null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

export function isValidReportMonth(value: string): boolean {
  return REPORT_MONTH_RE.test(value);
}

export function getJstYearMonth(now: Date = new Date()): string {
  const jstMs = now.getTime() + 9 * 3600_000;
  const jstDate = new Date(jstMs);
  const year = jstDate.getUTCFullYear();
  const month = String(jstDate.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

export function getPreviousJstYearMonth(now: Date = new Date()): string {
  const jstMs = now.getTime() + 9 * 3600_000;
  const jstDate = new Date(jstMs);
  let year = jstDate.getUTCFullYear();
  let month = jstDate.getUTCMonth(); // 0-indexed -> previous month in 1..12, 0 means Dec of prev year
  if (month === 0) {
    year -= 1;
    month = 12;
  }
  return `${year}-${String(month).padStart(2, "0")}`;
}

export function normalizeRecipients(
  rawRecipients: unknown,
  fallbackList: string[] = [],
): string[] {
  const collected: string[] = [];
  if (Array.isArray(rawRecipients)) {
    for (const item of rawRecipients) {
      if (typeof item === "string") collected.push(item);
    }
  } else if (typeof rawRecipients === "string") {
    collected.push(...rawRecipients.split(","));
  }
  collected.push(...fallbackList);

  const seen = new Set<string>();
  const unique: string[] = [];
  for (const raw of collected) {
    const candidate = raw.trim().toLowerCase();
    if (!candidate || !EMAIL_RE.test(candidate) || seen.has(candidate)) {
      continue;
    }
    seen.add(candidate);
    unique.push(candidate);
  }
  return unique;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function buildCapacityNotificationContent(
  stat: CapacityMonthlyStatRow,
): { subject: string; text: string; html: string } {
  const subject = `[自分株式会社] 月次キャパシティレポート (${stat.report_month})`;
  const lines = [
    `対象月: ${stat.report_month}`,
    `ユーザーアクセス数: ${stat.user_access_count}`,
    `バッチ処理件数: ${stat.batch_job_count}`,
    `エラー発生件数: ${stat.error_count}`,
    `エラー発生率: ${stat.error_rate_percent.toFixed(2)}%`,
    `最終集計日時: ${stat.updated_at || "-"}`,
  ];
  const text = lines.join("\n");
  const htmlRows = [
    ["対象月", stat.report_month],
    ["ユーザーアクセス数", String(stat.user_access_count)],
    ["バッチ処理件数", String(stat.batch_job_count)],
    ["エラー発生件数", String(stat.error_count)],
    ["エラー発生率", `${stat.error_rate_percent.toFixed(2)}%`],
    ["最終集計日時", stat.updated_at || "-"],
  ]
    .map(
      ([label, value]) =>
        `<tr><th align="left" style="padding:6px 12px;border:1px solid #cbd5e1;">${
          escapeHtml(label)
        }</th><td style="padding:6px 12px;border:1px solid #cbd5e1;">${
          escapeHtml(value)
        }</td></tr>`,
    )
    .join("");

  const html =
    `<h2>月次システム利用統計・キャパシティレポート (${
      escapeHtml(stat.report_month)
    })</h2>` +
    `<table style="border-collapse:collapse;font-family:sans-serif;">${htmlRows}</table>`;

  return { subject, text, html };
}

export async function authorizeCapacityReportAdmin(
  store: CapacityReportStore,
  caller: CapacityCallerContext,
): Promise<CapacityServiceResponse | null> {
  if (!caller.userId && !caller.isServiceRole) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  if (caller.isServiceRole) {
    return null;
  }
  const profileRes = await store.getAdminProfile(caller.userId!);
  if (profileRes.error) {
    return { status: 500, body: { error: profileRes.error.message } };
  }
  const profile = profileRes.data;
  if (profile?.is_admin !== true && profile?.role !== "admin") {
    return {
      status: 403,
      body: { error: "Forbidden: admin role required" },
    };
  }
  return null;
}

export async function handleCapacityReportList(
  store: CapacityReportStore,
  caller: CapacityCallerContext,
  input: Record<string, unknown>,
): Promise<CapacityServiceResponse> {
  const denied = await authorizeCapacityReportAdmin(store, caller);
  if (denied) return denied;

  const rawLimit = typeof input.limit === "number"
    ? input.limit
    : Number(input.limit);
  const limit = Number.isFinite(rawLimit) && rawLimit > 0
    ? Math.min(Math.max(Math.trunc(rawLimit), 1), 60)
    : 12;

  const { data, error } = await store.listMonthlyStats(limit);
  if (error) {
    return { status: 500, body: { error: error.message } };
  }
  const reports = (data ?? []).slice().sort((a, b) =>
    b.report_month.localeCompare(a.report_month)
  );
  return {
    status: 200,
    body: {
      success: true,
      reports,
    },
  };
}

export async function handleCapacityReportAggregate(
  store: CapacityReportStore,
  caller: CapacityCallerContext,
  input: Record<string, unknown>,
  now: Date = new Date(),
): Promise<CapacityServiceResponse> {
  const denied = await authorizeCapacityReportAdmin(store, caller);
  if (denied) return denied;

  const rawMonth = typeof input.report_month === "string"
    ? input.report_month.trim()
    : "";
  const reportMonth = rawMonth !== ""
    ? rawMonth
    : input.target === "previous"
    ? getPreviousJstYearMonth(now)
    : getJstYearMonth(now);

  if (!isValidReportMonth(reportMonth)) {
    return {
      status: 400,
      body: { error: "report_month must be in YYYY-MM format" },
    };
  }

  const { data, error } = await store.aggregateMonthlyStat(reportMonth);
  if (error) {
    return { status: 500, body: { error: error.message } };
  }
  if (!data) {
    return {
      status: 500,
      body: { error: "Failed to aggregate monthly capacity report" },
    };
  }

  return {
    status: 200,
    body: {
      success: true,
      report: data,
    },
  };
}

function safeEnvGet(key: string): string {
  try {
    return Deno.env.get(key) ?? "";
  } catch {
    return "";
  }
}

export async function handleCapacityReportNotify(
  store: CapacityReportStore,
  caller: CapacityCallerContext,
  input: Record<string, unknown>,
  options: CapacityNotifyOptions = {},
): Promise<CapacityServiceResponse> {
  const denied = await authorizeCapacityReportAdmin(store, caller);
  if (denied) return denied;

  const now = options.now ?? new Date();
  const rawMonth = typeof input.report_month === "string"
    ? input.report_month.trim()
    : "";
  const reportMonth = rawMonth !== ""
    ? rawMonth
    : getPreviousJstYearMonth(now);

  if (!isValidReportMonth(reportMonth)) {
    return {
      status: 400,
      body: { error: "report_month must be in YYYY-MM format" },
    };
  }

  const dryRun = input.dry_run === true;
  const shouldAggregateFirst = input.aggregate !== false;

  let report: CapacityMonthlyStatRow | null = null;
  if (shouldAggregateFirst) {
    const aggRes = await store.aggregateMonthlyStat(reportMonth);
    if (aggRes.error) {
      return { status: 500, body: { error: aggRes.error.message } };
    }
    report = aggRes.data;
  } else {
    const existingRes = await store.getMonthlyStat(reportMonth);
    if (existingRes.error) {
      return { status: 500, body: { error: existingRes.error.message } };
    }
    report = existingRes.data;
    if (!report) {
      const aggRes = await store.aggregateMonthlyStat(reportMonth);
      if (aggRes.error) {
        return { status: 500, body: { error: aggRes.error.message } };
      }
      report = aggRes.data;
    }
  }

  if (!report) {
    return { status: 404, body: { error: "Monthly capacity report not found" } };
  }

  const envFallbackRecipients = options.defaultRecipients !== undefined
    ? options.defaultRecipients
    : [
      safeEnvGet("CAPACITY_REPORT_RECIPIENTS"),
      safeEnvGet("ADMIN_EMAIL"),
      safeEnvGet("AUTOMATION_ADMIN_EMAILS"),
    ].flatMap((entry) => entry.split(","));

  const recipients = normalizeRecipients(input.recipients, envFallbackRecipients);
  const content = buildCapacityNotificationContent(report);

  if (dryRun) {
    return {
      status: 200,
      body: {
        success: true,
        dry_run: true,
        report,
        preview: {
          subject: content.subject,
          text: content.text,
          recipients_count: recipients.length,
        },
      },
    };
  }

  const fetchFn = options.fetchFn ?? fetch;
  const resendKey = (
    options.resendKey ?? safeEnvGet("RESEND_API_KEY")
  ).trim();
  const fromEmail = (
    options.fromEmail ??
      (safeEnvGet("CAPACITY_REPORT_FROM_EMAIL") || "noreply@jibun.app")
  ).trim();
  const slackWebhookUrl = (
    options.slackWebhookUrl ?? safeEnvGet("SLACK_WEBHOOK_URL")
  ).trim();

  let emailSent = false;
  let emailError: string | null = null;
  let emailSkippedReason: string | null = null;
  if (resendKey === "") {
    emailSkippedReason = "RESEND_API_KEY not configured";
  } else if (recipients.length === 0) {
    emailSkippedReason = "No recipients configured";
  } else {
    try {
      const resp = await fetchFn("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: fromEmail,
          to: recipients,
          subject: content.subject,
          text: content.text,
          html: content.html,
        }),
      });
      if (resp.ok) {
        emailSent = true;
      } else {
        emailError = `Resend HTTP ${resp.status}`;
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      emailError = `Resend request failed: ${msg.slice(0, 120)}`;
    }
  }

  let slackSent = false;
  let slackError: string | null = null;
  if (slackWebhookUrl !== "") {
    try {
      const resp = await fetchFn(slackWebhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: `${content.subject}\n${content.text}`,
        }),
      });
      if (resp.ok) {
        slackSent = true;
      } else {
        slackError = `Slack HTTP ${resp.status}`;
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      slackError = `Slack request failed: ${msg.slice(0, 120)}`;
    }
  }

  const actorId = caller.userId ?? "service-role";
  const adminNotifRes = await store.recordAdminNotification(actorId, {
    title: content.subject,
    message: content.text,
    severity: report.error_rate_percent >= 5 ? "warning" : "info",
    severityLabel: report.error_rate_percent >= 5 ? "警告" : "情報",
    severityColor: report.error_rate_percent >= 5 ? "#f59e0b" : "#3b82f6",
    priority: report.error_rate_percent >= 5 ? 2 : 3,
    category: "monthly_capacity_report",
    report_month: report.report_month,
    email_sent: emailSent,
    slack_sent: slackSent,
  });
  const inAppRecorded = adminNotifRes.error === null;

  let updatedReport = report;
  if (emailSent || slackSent || (emailError === null && inAppRecorded)) {
    const notifiedAtIso = now.toISOString();
    const markRes = await store.markNotified(report.report_month, notifiedAtIso);
    if (markRes.error) {
      return { status: 500, body: { error: markRes.error.message } };
    }
    if (markRes.data) {
      updatedReport = markRes.data;
    }
  }

  if (emailError !== null && !slackSent && input.require_email === true) {
    return {
      status: 502,
      body: {
        success: false,
        error: emailError,
        report: updatedReport,
        delivery: {
          email_sent: emailSent,
          email_error: emailError,
          slack_sent: slackSent,
          slack_error: slackError,
          in_app_recorded: inAppRecorded,
        },
      },
    };
  }

  return {
    status: 200,
    body: {
      success: true,
      dry_run: false,
      report: updatedReport,
      delivery: {
        email_sent: emailSent,
        email_error: emailError,
        email_skipped_reason: emailSkippedReason,
        recipients_count: recipients.length,
        slack_sent: slackSent,
        slack_error: slackError,
        in_app_recorded: inAppRecorded,
      },
    },
  };
}
