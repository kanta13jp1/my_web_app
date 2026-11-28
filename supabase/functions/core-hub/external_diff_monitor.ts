export type DiffRuleOperator =
  | "any_change"
  | "field_changed"
  | "gt"
  | "lt"
  | "pct_change_gte"
  | "contains";

export type AlertSeverity = "info" | "warning" | "critical";

export interface DiffChangeEntry {
  fieldPath: string;
  changeType: "added" | "removed" | "changed";
  previousValue: unknown;
  currentValue: unknown;
  numericDelta: number | null;
  percentDelta: number | null;
}

export interface DiffTriggerRule {
  id: string;
  userId: string;
  ruleName: string;
  sourceKey: string;
  fieldPath: string;
  operator: DiffRuleOperator;
  thresholdValue: string;
  severity: AlertSeverity;
  notifyEmail: boolean;
  recipientEmail: string;
  enabled: boolean;
  updatedAt: string;
}

export interface ExternalSnapshotRecord {
  id: string;
  userId: string;
  sourceKey: string;
  sourceLabel: string;
  payloadHash: string;
  payload: Record<string, unknown>;
  fetchedAt: string;
}

export interface DiffAlertRecord {
  id: string;
  userId: string;
  title: string;
  status: string;
  severity: AlertSeverity;
  sourceKey: string;
  ruleId: string;
  ruleName: string;
  diffSummary: string;
  changedFields: string[];
  emailStatus: string;
  emailRecipientMasked: string;
  createdAt: string;
}

export interface EmailSendRequest {
  to: string;
  subject: string;
  html: string;
  text: string;
}

export interface EmailSendResult {
  status:
    | "sent"
    | "dry_run"
    | "skipped_no_mailer_key"
    | "skipped_no_recipient"
    | "failed";
  statusCode?: number;
  detail?: string;
}

export interface ExternalDiffStore {
  getLatestSnapshot(
    userId: string,
    sourceKey: string,
  ): Promise<ExternalSnapshotRecord | null>;
  saveSnapshot(input: {
    userId: string;
    sourceKey: string;
    sourceLabel: string;
    payloadHash: string;
    payload: Record<string, unknown>;
    fetchedAt: string;
  }): Promise<ExternalSnapshotRecord>;
  listSnapshots(
    userId: string,
    limit: number,
  ): Promise<ExternalSnapshotRecord[]>;
  listRules(userId: string): Promise<DiffTriggerRule[]>;
  listAllEnabledRules(limit: number): Promise<DiffTriggerRule[]>;
  upsertRule(input: {
    id?: string;
    userId: string;
    ruleName: string;
    sourceKey: string;
    fieldPath: string;
    operator: DiffRuleOperator;
    thresholdValue: string;
    severity: AlertSeverity;
    notifyEmail: boolean;
    recipientEmail: string;
    enabled: boolean;
  }): Promise<DiffTriggerRule>;
  createScanJob(input: {
    userId: string;
    title: string;
    requestPayload: Record<string, unknown>;
  }): Promise<string>;
  completeScanJob(input: {
    jobId: string;
    userId: string;
    status: "completed" | "failed";
    resultPayload: Record<string, unknown>;
    errorMessage?: string;
  }): Promise<void>;
  insertRealtimeAlertJob(input: {
    userId: string;
    title: string;
    requestPayload: Record<string, unknown>;
    resultPayload: Record<string, unknown>;
  }): Promise<DiffAlertRecord>;
  listAlertJobs(userId: string, limit: number): Promise<DiffAlertRecord[]>;
  acknowledgeAlertJob(jobId: string, userId: string): Promise<boolean>;
  insertInAppNotification(input: {
    userId: string;
    title: string;
    message: string;
    link: string;
    dedupeKey: string;
  }): Promise<void>;
  getUserEmail(userId: string): Promise<string>;
  sendAlertEmail(input: EmailSendRequest): Promise<EmailSendResult>;
}

const VALID_OPERATORS = new Set<string>([
  "any_change",
  "field_changed",
  "gt",
  "lt",
  "pct_change_gte",
  "contains",
]);

const VALID_SEVERITIES = new Set<string>(["info", "warning", "critical"]);

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asText(value: unknown, maxLen = 400): string {
  return String(value ?? "").trim().slice(0, maxLen);
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function maskEmail(email: string): string {
  const trimmed = email.trim();
  const atIndex = trimmed.indexOf("@");
  if (atIndex <= 1) {
    return trimmed === "" ? "" : "***";
  }
  const local = trimmed.slice(0, atIndex);
  const domain = trimmed.slice(atIndex + 1);
  return `${local[0]}***@${domain}`;
}

export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(",")}]`;
  }
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  const parts = keys.map(
    (key) => `${JSON.stringify(key)}:${stableStringify(obj[key])}`,
  );
  return `{${parts.join(",")}}`;
}

export async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function flattenPayload(
  value: unknown,
  prefix: string,
  depth: number,
  out: Map<string, unknown>,
): void {
  if (depth > 4) {
    out.set(prefix, value);
    return;
  }
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0 && prefix !== "") {
      out.set(prefix, {});
      return;
    }
    for (const [k, v] of entries) {
      const nextKey = prefix === "" ? k : `${prefix}.${k}`;
      flattenPayload(v, nextKey, depth + 1, out);
    }
    return;
  }
  out.set(prefix, value);
}

export function computeStructuredDiff(
  previous: Record<string, unknown>,
  current: Record<string, unknown>,
): DiffChangeEntry[] {
  const prevMap = new Map<string, unknown>();
  const currMap = new Map<string, unknown>();
  flattenPayload(previous, "", 0, prevMap);
  flattenPayload(current, "", 0, currMap);

  const allKeys = new Set<string>([...prevMap.keys(), ...currMap.keys()]);
  const diffs: DiffChangeEntry[] = [];

  for (const key of Array.from(allKeys).sort()) {
    const hasPrev = prevMap.has(key);
    const hasCurr = currMap.has(key);
    const prevVal = prevMap.get(key);
    const currVal = currMap.get(key);

    if (!hasPrev && hasCurr) {
      diffs.push({
        fieldPath: key,
        changeType: "added",
        previousValue: null,
        currentValue: currVal,
        numericDelta: null,
        percentDelta: null,
      });
      continue;
    }
    if (hasPrev && !hasCurr) {
      diffs.push({
        fieldPath: key,
        changeType: "removed",
        previousValue: prevVal,
        currentValue: null,
        numericDelta: null,
        percentDelta: null,
      });
      continue;
    }

    if (stableStringify(prevVal) !== stableStringify(currVal)) {
      let numericDelta: number | null = null;
      let percentDelta: number | null = null;
      if (typeof prevVal === "number" && typeof currVal === "number") {
        numericDelta = Number((currVal - prevVal).toFixed(4));
        if (prevVal !== 0) {
          percentDelta = Number(
            ((Math.abs(currVal - prevVal) / Math.abs(prevVal)) * 100)
              .toFixed(2),
          );
        }
      }
      diffs.push({
        fieldPath: key,
        changeType: "changed",
        previousValue: prevVal,
        currentValue: currVal,
        numericDelta,
        percentDelta,
      });
    }
  }
  return diffs;
}

export interface EvaluatedRuleMatch {
  rule: DiffTriggerRule;
  matchedFields: string[];
  reason: string;
}

function readPathValue(
  payload: Record<string, unknown>,
  path: string,
): unknown {
  if (!path.trim()) return payload;
  let current: unknown = payload;
  for (const part of path.split(".")) {
    if (current === null || typeof current !== "object") {
      return undefined;
    }
    current = (current as Record<string, unknown>)[part];
  }
  return current;
}

export function evaluateDiffRules(
  rules: DiffTriggerRule[],
  sourceKey: string,
  diffs: DiffChangeEntry[],
  currentPayload: Record<string, unknown>,
): EvaluatedRuleMatch[] {
  if (diffs.length === 0) return [];
  const matches: EvaluatedRuleMatch[] = [];
  const diffMap = new Map<string, DiffChangeEntry>();
  for (const item of diffs) {
    diffMap.set(item.fieldPath, item);
  }

  for (const rule of rules) {
    if (!rule.enabled || rule.sourceKey !== sourceKey) continue;
    const targetPath = rule.fieldPath.trim();

    if (rule.operator === "any_change") {
      matches.push({
        rule,
        matchedFields: diffs.slice(0, 8).map((d) => d.fieldPath),
        reason: `${diffs.length} field(s) changed in ${sourceKey}`,
      });
      continue;
    }

    const diffItem = diffMap.get(targetPath);
    if (!diffItem) continue;
    const currVal = readPathValue(currentPayload, targetPath);

    if (rule.operator === "field_changed") {
      matches.push({
        rule,
        matchedFields: [targetPath],
        reason: `Field ${targetPath} updated (${
          String(diffItem.previousValue ?? "null")
        } -> ${String(diffItem.currentValue ?? "null")})`,
      });
      continue;
    }

    if (rule.operator === "contains") {
      const needle = rule.thresholdValue.toLowerCase();
      const hay = String(currVal ?? "").toLowerCase();
      if (needle !== "" && hay.includes(needle)) {
        matches.push({
          rule,
          matchedFields: [targetPath],
          reason:
            `Field ${targetPath} matched pattern "${rule.thresholdValue}"`,
        });
      }
      continue;
    }

    const numVal = Number(currVal);
    const thresholdNum = Number(rule.thresholdValue);
    if (!Number.isFinite(thresholdNum)) continue;

    if (
      rule.operator === "gt" &&
      Number.isFinite(numVal) &&
      numVal > thresholdNum
    ) {
      matches.push({
        rule,
        matchedFields: [targetPath],
        reason: `${targetPath}=${numVal} exceeded threshold > ${thresholdNum}`,
      });
    } else if (
      rule.operator === "lt" &&
      Number.isFinite(numVal) &&
      numVal < thresholdNum
    ) {
      matches.push({
        rule,
        matchedFields: [targetPath],
        reason:
          `${targetPath}=${numVal} dropped below threshold < ${thresholdNum}`,
      });
    } else if (
      rule.operator === "pct_change_gte" &&
      diffItem.percentDelta !== null &&
      diffItem.percentDelta >= thresholdNum
    ) {
      matches.push({
        rule,
        matchedFields: [targetPath],
        reason:
          `${targetPath} changed by ${diffItem.percentDelta}% ` +
            `(>= ${thresholdNum}%)`,
      });
    }
  }
  return matches;
}

export function buildDiffAlertEmailTemplate(input: {
  sourceKey: string;
  ruleName: string;
  severity: AlertSeverity;
  reason: string;
  diffs: DiffChangeEntry[];
  detectedAt: string;
}): { subject: string; html: string; text: string } {
  const sevTag = input.severity.toUpperCase();
  const subject =
    `[${sevTag}] 外部データ差分アラート: ${input.sourceKey} ` +
      `(${input.ruleName})`;
  const previewRows = input.diffs.slice(0, 6);
  const cellStyle = 'style="padding:6px;border:1px solid #cbd5e1;"';
  const thStyle =
    'style="padding:6px;border:1px solid #cbd5e1;text-align:left;"';
  const rowsHtml = previewRows
    .map(
      (d) =>
        `<tr><td ${cellStyle}>${escapeHtml(d.fieldPath)}</td>` +
          `<td ${cellStyle}>${escapeHtml(d.changeType)}</td>` +
          `<td ${cellStyle}>${
            escapeHtml(String(d.previousValue ?? "-"))
          }</td>` +
          `<td ${cellStyle}>${
            escapeHtml(String(d.currentValue ?? "-"))
          }</td></tr>`,
    )
    .join("");

  const html = [
    "<!DOCTYPE html>",
    '<html lang="ja"><head><meta charset="UTF-8"></head>',
    '<body style="font-family:sans-serif;max-width:640px;margin:0 auto;',
    'padding:24px;color:#0f172a;">',
    `  <h2 style="margin:0 0 12px;">[${escapeHtml(sevTag)}] `,
    "外部連携データ差分検知</h2>",
    `  <p style="margin:0 0 8px;">ソース: <strong>`,
    `${escapeHtml(input.sourceKey)}</strong></p>`,
    `  <p style="margin:0 0 8px;">トリガールール: <strong>`,
    `${escapeHtml(input.ruleName)}</strong></p>`,
    `  <p style="margin:0 0 16px;">検知理由: `,
    `${escapeHtml(input.reason)}</p>`,
    '  <table style="border-collapse:collapse;width:100%;font-size:13px;">',
    "    <thead>",
    '      <tr style="background:#f1f5f9;">',
    `        <th ${thStyle}>フィールド</th>`,
    `        <th ${thStyle}>種別</th>`,
    `        <th ${thStyle}>前回値</th>`,
    `        <th ${thStyle}>最新値</th>`,
    "      </tr>",
    "    </thead>",
    `    <tbody>${rowsHtml}</tbody>`,
    "  </table>",
    '  <p style="margin-top:16px;font-size:12px;color:#475569;">',
    `検知日時: ${escapeHtml(input.detectedAt)}</p>`,
    "</body></html>",
  ].join("\n");

  const lines = [
    `[${sevTag}] External Diff Alert: ${input.sourceKey}`,
    `Rule: ${input.ruleName}`,
    `Reason: ${input.reason}`,
    `Detected At: ${input.detectedAt}`,
    ...previewRows.map(
      (d) =>
        `- ${d.fieldPath} (${d.changeType}): ` +
          `${String(d.previousValue ?? "-")} -> ` +
          `${String(d.currentValue ?? "-")}`,
    ),
  ];

  return { subject, html, text: lines.join("\n") };
}

export async function handleExternalDiffAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  isServiceRole: boolean;
  store: ExternalDiffStore;
}): Promise<{ status: number; body: Record<string, unknown> }> {
  const { action, body, userId, isServiceRole, store } = params;
  const requestedUserId = asText(body.user_id, 80);

  if (action === "external_diff.batch_scan") {
    if (!isServiceRole) {
      return {
        status: 403,
        body: { error: "Service role authorization required for batch scan." },
      };
    }
    const sourcesRaw = Array.isArray(body.items) ? body.items : [];
    if (sourcesRaw.length === 0) {
      const enabledRules = await store.listAllEnabledRules(50);
      return {
        status: 200,
        body: {
          success: true,
          processed: 0,
          alerts_triggered: 0,
          active_rules: enabledRules.length,
        },
      };
    }

    let processed = 0;
    let alertsTriggered = 0;
    const results: Array<Record<string, unknown>> = [];
    for (const rawItem of sourcesRaw.slice(0, 25)) {
      const item = asRecord(rawItem);
      const itemUserId = asText(item.user_id, 80);
      const sourceKey = asText(item.source_key, 120);
      const payload = asRecord(item.payload);
      if (!itemUserId || !sourceKey) continue;
      const single = await runSingleDetection({
        userId: itemUserId,
        sourceKey,
        sourceLabel: asText(item.source_label, 120) || sourceKey,
        payload,
        dryRun: body.dry_run === true,
        store,
      });
      processed += 1;
      alertsTriggered += Number(single.alerts_triggered ?? 0);
      results.push(single);
    }
    return {
      status: 200,
      body: {
        success: true,
        processed,
        alerts_triggered: alertsTriggered,
        results,
      },
    };
  }

  if (!userId && !isServiceRole) {
    return { status: 401, body: { error: "Unauthorized" } };
  }
  const effectiveUserId = userId || requestedUserId;
  if (!effectiveUserId) {
    return { status: 400, body: { error: "Missing user_id" } };
  }
  if (
    !isServiceRole &&
    requestedUserId &&
    requestedUserId !== effectiveUserId
  ) {
    return {
      status: 403,
      body: { error: "Cross-user access is forbidden." },
    };
  }

  if (action === "external_diff.rule.list") {
    const rules = await store.listRules(effectiveUserId);
    return { status: 200, body: { success: true, rules } };
  }

  if (action === "external_diff.rule.upsert") {
    const ruleName = asText(body.rule_name, 120);
    const sourceKey = asText(body.source_key, 120);
    const fieldPath = asText(body.field_path, 160);
    const operatorRaw = asText(body.operator, 40) || "any_change";
    const severityRaw = asText(body.severity, 20) || "warning";
    const thresholdValue = asText(body.threshold_value, 160);
    const recipientEmail = asText(body.recipient_email, 200);
    const notifyEmail = body.notify_email !== false;
    const enabled = body.enabled !== false;

    if (!ruleName || !sourceKey) {
      return {
        status: 400,
        body: { error: "rule_name and source_key are required." },
      };
    }
    if (!VALID_OPERATORS.has(operatorRaw)) {
      return {
        status: 400,
        body: { error: `Unsupported operator: ${operatorRaw}` },
      };
    }
    if (!VALID_SEVERITIES.has(severityRaw)) {
      return {
        status: 400,
        body: { error: `Unsupported severity: ${severityRaw}` },
      };
    }

    const saved = await store.upsertRule({
      id: asText(body.id, 80) || undefined,
      userId: effectiveUserId,
      ruleName,
      sourceKey,
      fieldPath,
      operator: operatorRaw as DiffRuleOperator,
      thresholdValue,
      severity: severityRaw as AlertSeverity,
      notifyEmail,
      recipientEmail,
      enabled,
    });
    return { status: 200, body: { success: true, rule: saved } };
  }

  if (action === "external_diff.alert.list") {
    const rawLimit = Number(body.limit ?? 30);
    const limit = Number.isFinite(rawLimit)
      ? Math.max(1, Math.min(100, Math.trunc(rawLimit)))
      : 30;
    const [alerts, rules, snapshots] = await Promise.all([
      store.listAlertJobs(effectiveUserId, limit),
      store.listRules(effectiveUserId),
      store.listSnapshots(effectiveUserId, 20),
    ]);
    return {
      status: 200,
      body: { success: true, alerts, rules, snapshots },
    };
  }

  if (action === "external_diff.alert.acknowledge") {
    const alertId = asText(body.alert_id, 80);
    if (!alertId) {
      return { status: 400, body: { error: "alert_id is required." } };
    }
    const updated = await store.acknowledgeAlertJob(alertId, effectiveUserId);
    if (!updated) {
      return { status: 404, body: { error: "Alert not found." } };
    }
    return { status: 200, body: { success: true, alert_id: alertId } };
  }

  if (action === "external_diff.snapshot_and_detect") {
    const sourceKey = asText(body.source_key, 120);
    if (!sourceKey) {
      return { status: 400, body: { error: "source_key is required." } };
    }
    const payload = asRecord(body.payload);
    if (Object.keys(payload).length === 0) {
      return {
        status: 400,
        body: { error: "payload must be a non-empty JSON object." },
      };
    }
    const sourceLabel = asText(body.source_label, 120) || sourceKey;
    const dryRun = body.dry_run === true;
    const outcome = await runSingleDetection({
      userId: effectiveUserId,
      sourceKey,
      sourceLabel,
      payload,
      dryRun,
      store,
    });
    return { status: 200, body: { success: true, ...outcome } };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}

async function runSingleDetection(input: {
  userId: string;
  sourceKey: string;
  sourceLabel: string;
  payload: Record<string, unknown>;
  dryRun: boolean;
  store: ExternalDiffStore;
}): Promise<Record<string, unknown>> {
  const { userId, sourceKey, sourceLabel, payload, dryRun, store } = input;
  const nowIso = new Date().toISOString();
  const payloadHash = await sha256Hex(stableStringify(payload));

  const scanJobId = await store.createScanJob({
    userId,
    title: `Diff scan: ${sourceKey}`,
    requestPayload: {
      source_key: sourceKey,
      payload_hash: payloadHash,
      dry_run: dryRun,
    },
  });

  try {
    const previous = await store.getLatestSnapshot(userId, sourceKey);
    const diffs = previous
      ? computeStructuredDiff(previous.payload, payload)
      : [];

    if (!dryRun) {
      await store.saveSnapshot({
        userId,
        sourceKey,
        sourceLabel,
        payloadHash,
        payload,
        fetchedAt: nowIso,
      });
    }

    const rules = await store.listRules(userId);
    const matches = evaluateDiffRules(rules, sourceKey, diffs, payload);
    const emittedAlerts: DiffAlertRecord[] = [];

    for (const match of matches) {
      const template = buildDiffAlertEmailTemplate({
        sourceKey,
        ruleName: match.rule.ruleName,
        severity: match.rule.severity,
        reason: match.reason,
        diffs,
        detectedAt: nowIso,
      });

      let emailResult: EmailSendResult = { status: "skipped_no_recipient" };
      let recipient = "";
      if (match.rule.notifyEmail) {
        recipient = match.rule.recipientEmail ||
          (await store.getUserEmail(userId));
        if (dryRun) {
          emailResult = { status: "dry_run" };
        } else if (!recipient) {
          emailResult = { status: "skipped_no_recipient" };
        } else {
          emailResult = await store.sendAlertEmail({
            to: recipient,
            subject: template.subject,
            html: template.html,
            text: template.text,
          });
        }
      }

      if (!dryRun) {
        const alertTitle =
          `[${match.rule.severity.toUpperCase()}] ${sourceKey}: ` +
            `${match.rule.ruleName}`;
        const masked = maskEmail(recipient);
        const alertRecord = await store.insertRealtimeAlertJob({
          userId,
          title: alertTitle,
          requestPayload: {
            source_key: sourceKey,
            rule_id: match.rule.id,
            rule_name: match.rule.ruleName,
            severity: match.rule.severity,
            diff_summary: match.reason,
            changed_fields: match.matchedFields,
          },
          resultPayload: {
            email_status: emailResult.status,
            email_recipient_masked: masked,
            template_subject: template.subject,
          },
        });
        emittedAlerts.push(alertRecord);
        await store.insertInAppNotification({
          userId,
          title: alertTitle,
          message: match.reason,
          link: "/admin-notifications?view=external-diff-alert",
          dedupeKey: `diff:${sourceKey}:${match.rule.id}:${payloadHash}`,
        });
      }
    }

    await store.completeScanJob({
      jobId: scanJobId,
      userId,
      status: "completed",
      resultPayload: {
        baseline_initialized: previous === null,
        diff_count: diffs.length,
        alerts_triggered: matches.length,
        dry_run: dryRun,
      },
    });

    return {
      source_key: sourceKey,
      baseline_initialized: previous === null,
      diff_count: diffs.length,
      diffs: diffs.slice(0, 20),
      alerts_triggered: matches.length,
      alerts: emittedAlerts,
      dry_run: dryRun,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await store.completeScanJob({
      jobId: scanJobId,
      userId,
      status: "failed",
      resultPayload: { source_key: sourceKey },
      errorMessage: message.slice(0, 400),
    });
    throw err;
  }
}
