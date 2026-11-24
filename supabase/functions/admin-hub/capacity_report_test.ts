import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCapacityNotificationContent,
  type CapacityAdminProfileRow,
  type CapacityCallerContext,
  type CapacityMonthlyStatRow,
  type CapacityReportStore,
  type CapacityStoreResult,
  getJstYearMonth,
  getPreviousJstYearMonth,
  handleCapacityReportAggregate,
  handleCapacityReportList,
  handleCapacityReportNotify,
  normalizeRecipients,
} from "./capacity_report.ts";

class InMemoryCapacityReportStore implements CapacityReportStore {
  rows: CapacityMonthlyStatRow[] = [];
  profiles = new Map<string, CapacityAdminProfileRow>();
  notifications: Array<{ actorId: string; metadata: Record<string, unknown> }> =
    [];
  aggregatedSeed = new Map<
    string,
    Pick<
      CapacityMonthlyStatRow,
      "user_access_count" | "batch_job_count" | "error_count" | "error_rate_percent"
    >
  >();

  getAdminProfile(
    userId: string,
  ): Promise<CapacityStoreResult<CapacityAdminProfileRow>> {
    return Promise.resolve({
      data: this.profiles.get(userId) ?? null,
      error: null,
    });
  }

  listMonthlyStats(
    limit: number,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow[]>> {
    const sorted = this.rows
      .slice()
      .sort((a, b) => b.report_month.localeCompare(a.report_month))
      .slice(0, limit)
      .map((row) => ({ ...row }));
    return Promise.resolve({ data: sorted, error: null });
  }

  getMonthlyStat(
    reportMonth: string,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow>> {
    const found = this.rows.find((row) => row.report_month === reportMonth) ??
      null;
    return Promise.resolve({ data: found ? { ...found } : null, error: null });
  }

  aggregateMonthlyStat(
    reportMonth: string,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow>> {
    const existing = this.rows.find((row) => row.report_month === reportMonth);
    const seed = this.aggregatedSeed.get(reportMonth) ?? {
      user_access_count: existing?.user_access_count ?? 1200,
      batch_job_count: existing?.batch_job_count ?? 45,
      error_count: existing?.error_count ?? 3,
      error_rate_percent: existing?.error_rate_percent ?? 0.24,
    };
    const nextRow: CapacityMonthlyStatRow = {
      report_month: reportMonth,
      user_access_count: seed.user_access_count,
      batch_job_count: seed.batch_job_count,
      error_count: seed.error_count,
      error_rate_percent: seed.error_rate_percent,
      notified_at: existing?.notified_at ?? null,
      summary_payload: {
        report_month: reportMonth,
        timezone: "Asia/Tokyo",
      },
      updated_at: "2026-11-24T00:00:00Z",
    };
    const idx = this.rows.findIndex((row) => row.report_month === reportMonth);
    if (idx >= 0) {
      this.rows[idx] = nextRow;
    } else {
      this.rows.push(nextRow);
    }
    return Promise.resolve({ data: { ...nextRow }, error: null });
  }

  markNotified(
    reportMonth: string,
    notifiedAtIso: string,
  ): Promise<CapacityStoreResult<CapacityMonthlyStatRow>> {
    const idx = this.rows.findIndex((row) => row.report_month === reportMonth);
    if (idx < 0) {
      return Promise.resolve({ data: null, error: null });
    }
    const updated: CapacityMonthlyStatRow = {
      ...this.rows[idx],
      notified_at: notifiedAtIso,
      updated_at: notifiedAtIso,
    };
    this.rows[idx] = updated;
    return Promise.resolve({ data: { ...updated }, error: null });
  }

  recordAdminNotification(
    actorId: string,
    metadata: Record<string, unknown>,
  ): Promise<CapacityStoreResult<unknown>> {
    this.notifications.push({ actorId, metadata });
    return Promise.resolve({ data: { id: "notif-1" }, error: null });
  }
}

const ADMIN_FLAG_CALLER: CapacityCallerContext = {
  userId: "admin-flag",
  isServiceRole: false,
};

const ADMIN_ROLE_CALLER: CapacityCallerContext = {
  userId: "admin-role",
  isServiceRole: false,
};

const SERVICE_CALLER: CapacityCallerContext = {
  userId: null,
  isServiceRole: true,
};

Deno.test("capacity_report actions reject unauthenticated (401) and non-admin (403) callers", async () => {
  const store = new InMemoryCapacityReportStore();
  store.profiles.set("regular-user", { is_admin: false, role: "user" });

  const unauthList = await handleCapacityReportList(
    store,
    { userId: null, isServiceRole: false },
    {},
  );
  assertEquals(unauthList.status, 401);

  const unauthAgg = await handleCapacityReportAggregate(
    store,
    { userId: null, isServiceRole: false },
    { report_month: "2026-11" },
  );
  assertEquals(unauthAgg.status, 401);

  const unauthNotify = await handleCapacityReportNotify(
    store,
    { userId: null, isServiceRole: false },
    { report_month: "2026-11" },
  );
  assertEquals(unauthNotify.status, 401);

  const forbiddenList = await handleCapacityReportList(
    store,
    { userId: "regular-user", isServiceRole: false },
    {},
  );
  assertEquals(forbiddenList.status, 403);

  const forbiddenAgg = await handleCapacityReportAggregate(
    store,
    { userId: "regular-user", isServiceRole: false },
    { report_month: "2026-11" },
  );
  assertEquals(forbiddenAgg.status, 403);

  const forbiddenNotify = await handleCapacityReportNotify(
    store,
    { userId: "regular-user", isServiceRole: false },
    { report_month: "2026-11" },
  );
  assertEquals(forbiddenNotify.status, 403);
});

Deno.test("capacity_report actions allow is_admin=true, role='admin', and service_role", async () => {
  const store = new InMemoryCapacityReportStore();
  store.profiles.set("admin-flag", { is_admin: true, role: "user" });
  store.profiles.set("admin-role", { is_admin: false, role: "admin" });

  const aggRes = await handleCapacityReportAggregate(
    store,
    ADMIN_FLAG_CALLER,
    { report_month: "2026-10" },
  );
  assertEquals(aggRes.status, 200);
  const aggReport = aggRes.body.report as CapacityMonthlyStatRow;
  assertEquals(aggReport.report_month, "2026-10");

  const listRes = await handleCapacityReportList(
    store,
    ADMIN_ROLE_CALLER,
    { limit: 6 },
  );
  assertEquals(listRes.status, 200);
  const reports = listRes.body.reports as CapacityMonthlyStatRow[];
  assertEquals(reports.length, 1);
  assertEquals(reports[0].report_month, "2026-10");

  const badMonth = await handleCapacityReportAggregate(
    store,
    SERVICE_CALLER,
    { report_month: "2026-13" },
  );
  assertEquals(badMonth.status, 400);
});

Deno.test("capacity_report.notify supports dry_run, Resend email delivery, and in-app fallback", async () => {
  const store = new InMemoryCapacityReportStore();
  store.profiles.set("admin-flag", { is_admin: true, role: "admin" });
  store.aggregatedSeed.set("2026-10", {
    user_access_count: 5400,
    batch_job_count: 180,
    error_count: 6,
    error_rate_percent: 0.11,
  });

  // dry_run does not invoke fetch or set notified_at
  const dryRes = await handleCapacityReportNotify(
    store,
    ADMIN_FLAG_CALLER,
    {
      report_month: "2026-10",
      dry_run: true,
      recipients: ["ops@example.com"],
    },
    {
      fetchFn: () => {
        throw new Error("dry_run must not invoke external HTTP fetch");
      },
      now: new Date("2026-11-01T00:15:00Z"),
    },
  );
  assertEquals(dryRes.status, 200);
  assertEquals(dryRes.body.dry_run, true);
  assertEquals(
    (dryRes.body.report as CapacityMonthlyStatRow).notified_at,
    null,
  );

  // Real notify with Resend mock
  let capturedUrl = "";
  let capturedBody = "";
  const sentRes = await handleCapacityReportNotify(
    store,
    SERVICE_CALLER,
    {
      report_month: "2026-10",
      recipients: ["ops@example.com", "OPS@example.com", "invalid-email"],
    },
    {
      resendKey: "dummy",
      fromEmail: "noreply@jibun.app",
      slackWebhookUrl: "",
      now: new Date("2026-11-01T00:20:00Z"),
      fetchFn: (input, init) => {
        capturedUrl = String(input);
        capturedBody = String(init?.body ?? "");
        return Promise.resolve(
          new Response(JSON.stringify({ id: "email-123" }), { status: 200 }),
        );
      },
    },
  );
  assertEquals(sentRes.status, 200);
  assertEquals(capturedUrl, "https://api.resend.com/emails");
  assertStringIncludes(capturedBody, "ops@example.com");
  assertStringIncludes(capturedBody, "5400");
  assertEquals(
    (sentRes.body.delivery as Record<string, unknown>).email_sent,
    true,
  );
  assertEquals(
    (sentRes.body.delivery as Record<string, unknown>).recipients_count,
    1,
  );
  assertEquals(
    (sentRes.body.report as CapacityMonthlyStatRow).notified_at,
    "2026-11-01T00:20:00.000Z",
  );
  assertEquals(store.notifications.length, 1);

  // Fallback without RESEND_API_KEY still records in-app admin notification cleanly
  const fallbackRes = await handleCapacityReportNotify(
    store,
    ADMIN_FLAG_CALLER,
    { report_month: "2026-11" },
    {
      resendKey: "",
      slackWebhookUrl: "",
      defaultRecipients: [],
      now: new Date("2026-11-24T01:00:00Z"),
    },
  );
  assertEquals(fallbackRes.status, 200);
  assertEquals(
    (fallbackRes.body.delivery as Record<string, unknown>).in_app_recorded,
    true,
  );
  assertEquals(
    (fallbackRes.body.delivery as Record<string, unknown>).email_sent,
    false,
  );
});

Deno.test("capacity_report date and formatting helpers handle JST boundaries and HTML escaping", () => {
  const janStartUtc = new Date("2026-01-01T00:15:00Z"); // 2026-01-01 09:15 JST
  assertEquals(getJstYearMonth(janStartUtc), "2026-01");
  assertEquals(getPreviousJstYearMonth(janStartUtc), "2025-12");

  const recipients = normalizeRecipients(
    ["Admin@Example.com", "invalid", "admin@example.com"],
    ["ops@example.com"],
  );
  assertEquals(recipients, ["admin@example.com", "ops@example.com"]);

  const content = buildCapacityNotificationContent({
    report_month: "2026-11",
    user_access_count: 100,
    batch_job_count: 10,
    error_count: 1,
    error_rate_percent: 0.91,
    notified_at: null,
    summary_payload: {},
    updated_at: "2026-11-24T00:00:00Z",
  });
  assertStringIncludes(content.subject, "2026-11");
  assertStringIncludes(content.text, "0.91%");
  assertStringIncludes(content.html, "<table");
});
