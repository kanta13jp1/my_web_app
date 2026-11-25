import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildDiffAlertEmailTemplate,
  computeStructuredDiff,
  type DiffAlertRecord,
  type DiffTriggerRule,
  type EmailSendRequest,
  evaluateDiffRules,
  type ExternalDiffStore,
  type ExternalSnapshotRecord,
  handleExternalDiffAction,
} from "./external_diff_monitor.ts";

function createFakeStore(options?: {
  emailResultStatus?: "sent" | "skipped_no_mailer_key";
}) {
  const snapshots: ExternalSnapshotRecord[] = [];
  const rules: DiffTriggerRule[] = [];
  const alerts: DiffAlertRecord[] = [];
  const notifications: Array<Record<string, unknown>> = [];
  const scanJobs: Array<Record<string, unknown>> = [];
  const sentEmails: EmailSendRequest[] = [];
  let seq = 0;

  const store: ExternalDiffStore = {
    getLatestSnapshot(userId, sourceKey) {
      const found = snapshots
        .filter((s) => s.userId === userId && s.sourceKey === sourceKey)
        .at(-1);
      return Promise.resolve(found ?? null);
    },
    saveSnapshot(input) {
      seq += 1;
      const rec: ExternalSnapshotRecord = {
        id: `snap-${seq}`,
        userId: input.userId,
        sourceKey: input.sourceKey,
        sourceLabel: input.sourceLabel,
        payloadHash: input.payloadHash,
        payload: input.payload,
        fetchedAt: input.fetchedAt,
      };
      snapshots.push(rec);
      return Promise.resolve(rec);
    },
    listSnapshots(userId, limit) {
      return Promise.resolve(
        snapshots.filter((s) => s.userId === userId).slice(-limit).reverse(),
      );
    },
    listRules(userId) {
      return Promise.resolve(rules.filter((r) => r.userId === userId));
    },
    listAllEnabledRules(limit) {
      return Promise.resolve(rules.filter((r) => r.enabled).slice(0, limit));
    },
    upsertRule(input) {
      seq += 1;
      const rec: DiffTriggerRule = {
        id: input.id ?? `rule-${seq}`,
        userId: input.userId,
        ruleName: input.ruleName,
        sourceKey: input.sourceKey,
        fieldPath: input.fieldPath,
        operator: input.operator,
        thresholdValue: input.thresholdValue,
        severity: input.severity,
        notifyEmail: input.notifyEmail,
        recipientEmail: input.recipientEmail,
        enabled: input.enabled,
        updatedAt: "2026-11-25T11:00:00Z",
      };
      const idx = rules.findIndex((r) => r.id === rec.id);
      if (idx >= 0) rules[idx] = rec;
      else rules.push(rec);
      return Promise.resolve(rec);
    },
    createScanJob(input) {
      seq += 1;
      const id = `scan-${seq}`;
      scanJobs.push({ id, ...input, status: "running" });
      return Promise.resolve(id);
    },
    completeScanJob(input) {
      const found = scanJobs.find((j) => j.id === input.jobId);
      if (found) found.status = input.status;
      return Promise.resolve();
    },
    insertRealtimeAlertJob(input) {
      seq += 1;
      const alert: DiffAlertRecord = {
        id: `alert-${seq}`,
        userId: input.userId,
        title: input.title,
        status: "completed",
        severity: String(input.requestPayload.severity ?? "warning") as
          | "info"
          | "warning"
          | "critical",
        sourceKey: String(input.requestPayload.source_key ?? ""),
        ruleId: String(input.requestPayload.rule_id ?? ""),
        ruleName: String(input.requestPayload.rule_name ?? ""),
        diffSummary: String(input.requestPayload.diff_summary ?? ""),
        changedFields: (input.requestPayload.changed_fields as string[]) ?? [],
        emailStatus: String(input.resultPayload.email_status ?? "none"),
        emailRecipientMasked: String(
          input.resultPayload.email_recipient_masked ?? "",
        ),
        createdAt: "2026-11-25T11:00:00Z",
      };
      alerts.push(alert);
      return Promise.resolve(alert);
    },
    listAlertJobs(userId, limit) {
      return Promise.resolve(
        alerts.filter((a) => a.userId === userId).slice(-limit).reverse(),
      );
    },
    acknowledgeAlertJob(jobId, userId) {
      const found = alerts.find((a) => a.id === jobId && a.userId === userId);
      if (!found) return Promise.resolve(false);
      found.status = "cancelled";
      return Promise.resolve(true);
    },
    insertInAppNotification(input) {
      notifications.push(input);
      return Promise.resolve();
    },
    getUserEmail() {
      return Promise.resolve("owner@example.test");
    },
    sendAlertEmail(input) {
      sentEmails.push(input);
      const st = options?.emailResultStatus ?? "sent";
      return Promise.resolve({
        status: st,
        statusCode: st === "sent" ? 200 : undefined,
      });
    },
  };

  return {
    store,
    snapshots,
    rules,
    alerts,
    notifications,
    scanJobs,
    sentEmails,
  };
}

Deno.test(
  "computes structured diffs and evaluates numeric/percent rules",
  () => {
    const diffs = computeStructuredDiff(
      { metrics: { bounce_rate: 12, active_users: 100 }, old_flag: true },
      { metrics: { bounce_rate: 24, active_users: 100 }, new_tag: "spike" },
    );

    assertEquals(diffs.length, 3);
    const changed = diffs.find((d) => d.fieldPath === "metrics.bounce_rate");
    assertEquals(changed?.changeType, "changed");
    assertEquals(changed?.numericDelta, 12);
    assertEquals(changed?.percentDelta, 100);

    const rules: DiffTriggerRule[] = [
      {
        id: "r1",
        userId: "u1",
        ruleName: "Bounce spike",
        sourceKey: "ga4_daily",
        fieldPath: "metrics.bounce_rate",
        operator: "pct_change_gte",
        thresholdValue: "50",
        severity: "critical",
        notifyEmail: true,
        recipientEmail: "ops@example.test",
        enabled: true,
        updatedAt: "2026-11-25T00:00:00Z",
      },
    ];
    const matches = evaluateDiffRules(rules, "ga4_daily", diffs, {
      metrics: { bounce_rate: 24, active_users: 100 },
    });
    assertEquals(matches.length, 1);
    assertEquals(matches[0].rule.severity, "critical");
  },
);

Deno.test("escapes HTML in diff alert email templates", () => {
  const rendered = buildDiffAlertEmailTemplate({
    sourceKey: "external<rss>",
    ruleName: "XSS & Check",
    severity: "warning",
    reason: 'Field updated <script>alert("x")</script>',
    diffs: [
      {
        fieldPath: "headline",
        changeType: "changed",
        previousValue: "old",
        currentValue: "<img onerror=1>",
        numericDelta: null,
        percentDelta: null,
      },
    ],
    detectedAt: "2026-11-25T11:00:00Z",
  });

  assertStringIncludes(rendered.html, "&lt;script&gt;alert(&quot;x&quot;)");
  assertStringIncludes(rendered.html, "&lt;img onerror=1&gt;");
});

Deno.test(
  "stores baseline, emits alert + email on rule match, enforces auth",
  async () => {
    const fake = createFakeStore();

    const unauth = await handleExternalDiffAction({
      action: "external_diff.alert.list",
      body: {},
      userId: "",
      isServiceRole: false,
      store: fake.store,
    });
    assertEquals(unauth.status, 401);

    const forbidden = await handleExternalDiffAction({
      action: "external_diff.alert.list",
      body: { user_id: "other-user" },
      userId: "user-1",
      isServiceRole: false,
      store: fake.store,
    });
    assertEquals(forbidden.status, 403);

    await handleExternalDiffAction({
      action: "external_diff.rule.upsert",
      body: {
        rule_name: "Error Rate > 5",
        source_key: "status_feed",
        field_path: "errors",
        operator: "gt",
        threshold_value: "5",
        severity: "critical",
        notify_email: true,
        recipient_email: "alerts@example.test",
      },
      userId: "user-1",
      isServiceRole: false,
      store: fake.store,
    });

    const baselineRes = await handleExternalDiffAction({
      action: "external_diff.snapshot_and_detect",
      body: { source_key: "status_feed", payload: { errors: 2, ok: true } },
      userId: "user-1",
      isServiceRole: false,
      store: fake.store,
    });
    assertEquals(baselineRes.status, 200);
    assertEquals(baselineRes.body.baseline_initialized, true);
    assertEquals(baselineRes.body.alerts_triggered, 0);

    const spikeRes = await handleExternalDiffAction({
      action: "external_diff.snapshot_and_detect",
      body: { source_key: "status_feed", payload: { errors: 9, ok: false } },
      userId: "user-1",
      isServiceRole: false,
      store: fake.store,
    });
    assertEquals(spikeRes.status, 200);
    assertEquals(spikeRes.body.diff_count, 2);
    assertEquals(spikeRes.body.alerts_triggered, 1);
    assertEquals(fake.alerts.length, 1);
    assertEquals(fake.notifications.length, 1);
    assertEquals(fake.sentEmails.length, 1);
    assertEquals(fake.sentEmails[0].to, "alerts@example.test");

    const batchDeny = await handleExternalDiffAction({
      action: "external_diff.batch_scan",
      body: {},
      userId: "user-1",
      isServiceRole: false,
      store: fake.store,
    });
    assertEquals(batchDeny.status, 403);

    const batchOk = await handleExternalDiffAction({
      action: "external_diff.batch_scan",
      body: {
        items: [
          {
            user_id: "user-1",
            source_key: "status_feed",
            payload: { errors: 11, ok: false },
          },
        ],
      },
      userId: "",
      isServiceRole: true,
      store: fake.store,
    });
    assertEquals(batchOk.status, 200);
    assertEquals(batchOk.body.processed, 1);
    assertEquals(batchOk.body.alerts_triggered, 1);
  },
);
