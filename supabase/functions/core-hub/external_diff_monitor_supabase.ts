import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  type AlertSeverity,
  type DiffAlertRecord,
  type DiffRuleOperator,
  type DiffTriggerRule,
  type EmailSendRequest,
  type EmailSendResult,
  type ExternalDiffStore,
  type ExternalSnapshotRecord,
} from "./external_diff_monitor.ts";

const SOURCE_SNAPSHOT = "external_diff_snapshot";
const SOURCE_RULE = "external_diff_rule";
const JOB_TYPE_SCAN = "external_diff_scan";
const JOB_TYPE_ALERT = "external_diff_alert";

function asMeta(raw: unknown): Record<string, unknown> {
  if (raw !== null && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}

function asStringList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((item) => String(item ?? "")).filter(Boolean);
}

function mapSnapshotRow(row: {
  id: string;
  metadata: unknown;
  created_at: string;
}): ExternalSnapshotRecord {
  const meta = asMeta(row.metadata);
  return {
    id: String(row.id),
    userId: String(meta.user_id ?? ""),
    sourceKey: String(meta.source_key ?? ""),
    sourceLabel: String(meta.source_label ?? meta.source_key ?? ""),
    payloadHash: String(meta.payload_hash ?? ""),
    payload: asMeta(meta.payload_snapshot),
    fetchedAt: String(meta.fetched_at ?? row.created_at ?? ""),
  };
}

function mapRuleRow(row: {
  id: string;
  metadata: unknown;
  created_at: string;
}): DiffTriggerRule {
  const meta = asMeta(row.metadata);
  return {
    id: String(row.id),
    userId: String(meta.user_id ?? ""),
    ruleName: String(meta.rule_name ?? ""),
    sourceKey: String(meta.source_key ?? ""),
    fieldPath: String(meta.field_path ?? ""),
    operator: (meta.operator as DiffRuleOperator) ?? "any_change",
    thresholdValue: String(meta.threshold_value ?? ""),
    severity: (meta.severity as AlertSeverity) ?? "warning",
    notifyEmail: meta.notify_email !== false,
    recipientEmail: String(meta.recipient_email ?? ""),
    enabled: meta.enabled !== false,
    updatedAt: String(meta.updated_at ?? row.created_at ?? ""),
  };
}

function mapAlertJobRow(row: {
  id: string;
  user_id: string;
  title: string;
  status: string;
  request_payload: unknown;
  result_payload: unknown;
  created_at: string;
}): DiffAlertRecord {
  const req = asMeta(row.request_payload);
  const res = asMeta(row.result_payload);
  return {
    id: String(row.id),
    userId: String(row.user_id),
    title: String(row.title),
    status: String(row.status),
    severity: (req.severity as AlertSeverity) ?? "warning",
    sourceKey: String(req.source_key ?? ""),
    ruleId: String(req.rule_id ?? ""),
    ruleName: String(req.rule_name ?? ""),
    diffSummary: String(req.diff_summary ?? ""),
    changedFields: asStringList(req.changed_fields),
    emailStatus: String(res.email_status ?? "none"),
    emailRecipientMasked: String(res.email_recipient_masked ?? ""),
    createdAt: String(row.created_at),
  };
}

export function createSupabaseExternalDiffStore(
  admin: SupabaseClient,
  fetcher: typeof fetch = fetch,
  getEnv: (name: string) => string | undefined = (name) =>
    Deno.env.get(name),
): ExternalDiffStore {
  return {
    async getLatestSnapshot(userId, sourceKey) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", SOURCE_SNAPSHOT)
        .filter("metadata->>user_id", "eq", userId)
        .filter("metadata->>source_key", "eq", sourceKey)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? mapSnapshotRow(data) : null;
    },

    async saveSnapshot(input) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: SOURCE_SNAPSHOT,
          metadata: {
            user_id: input.userId,
            source_key: input.sourceKey,
            source_label: input.sourceLabel,
            payload_hash: input.payloadHash,
            payload_snapshot: input.payload,
            fetched_at: input.fetchedAt,
          },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new Error(error?.message ?? "Failed to save diff snapshot");
      }
      return mapSnapshotRow(data);
    },

    async listSnapshots(userId, limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", SOURCE_SNAPSHOT)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []).map(mapSnapshotRow);
    },

    async listRules(userId) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", SOURCE_RULE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw new Error(error.message);
      return (data ?? []).map(mapRuleRow);
    },

    async listAllEnabledRules(limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", SOURCE_RULE)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []).map(mapRuleRow).filter((r) => r.enabled);
    },

    async upsertRule(input) {
      const meta = {
        user_id: input.userId,
        rule_name: input.ruleName,
        source_key: input.sourceKey,
        field_path: input.fieldPath,
        operator: input.operator,
        threshold_value: input.thresholdValue,
        severity: input.severity,
        notify_email: input.notifyEmail,
        recipient_email: input.recipientEmail,
        enabled: input.enabled,
        updated_at: new Date().toISOString(),
      };
      if (input.id) {
        const { data, error } = await admin
          .from("hub_data")
          .update({ metadata: meta })
          .eq("id", input.id)
          .eq("source", SOURCE_RULE)
          .filter("metadata->>user_id", "eq", input.userId)
          .select("id, metadata, created_at")
          .maybeSingle();
        if (error) throw new Error(error.message);
        if (data) return mapRuleRow(data);
      }
      const { data, error } = await admin
        .from("hub_data")
        .insert({ source: SOURCE_RULE, metadata: meta })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new Error(error?.message ?? "Failed to save diff trigger rule");
      }
      return mapRuleRow(data);
    },

    async createScanJob(input) {
      const nowIso = new Date().toISOString();
      const { data, error } = await admin
        .from("async_jobs")
        .insert({
          user_id: input.userId,
          job_type: JOB_TYPE_SCAN,
          title: input.title,
          status: "running",
          progress_percent: 25,
          request_payload: input.requestPayload,
          started_at: nowIso,
        })
        .select("id")
        .single();
      if (error || !data) {
        throw new Error(error?.message ?? "Failed to enqueue scan job");
      }
      return String(data.id);
    },

    async completeScanJob(input) {
      const nowIso = new Date().toISOString();
      const { error } = await admin
        .from("async_jobs")
        .update({
          status: input.status,
          progress_percent: 100,
          result_payload: input.resultPayload,
          error_message: input.errorMessage ?? null,
          completed_at: nowIso,
          updated_at: nowIso,
        })
        .eq("id", input.jobId)
        .eq("user_id", input.userId);
      if (error) throw new Error(error.message);
    },

    async insertRealtimeAlertJob(input) {
      const nowIso = new Date().toISOString();
      const { data, error } = await admin
        .from("async_jobs")
        .insert({
          user_id: input.userId,
          job_type: JOB_TYPE_ALERT,
          title: input.title,
          status: "completed",
          progress_percent: 100,
          request_payload: input.requestPayload,
          result_payload: input.resultPayload,
          completed_at: nowIso,
        })
        .select("*")
        .single();
      if (error || !data) {
        throw new Error(error?.message ?? "Failed to emit realtime alert");
      }
      return mapAlertJobRow(data);
    },

    async listAlertJobs(userId, limit) {
      const { data, error } = await admin
        .from("async_jobs")
        .select("*")
        .eq("user_id", userId)
        .eq("job_type", JOB_TYPE_ALERT)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new Error(error.message);
      return (data ?? []).map(mapAlertJobRow);
    },

    async acknowledgeAlertJob(jobId, userId) {
      const nowIso = new Date().toISOString();
      const { data, error } = await admin
        .from("async_jobs")
        .update({ status: "cancelled", updated_at: nowIso })
        .eq("id", jobId)
        .eq("user_id", userId)
        .eq("job_type", JOB_TYPE_ALERT)
        .select("id")
        .maybeSingle();
      if (error) throw new Error(error.message);
      return Boolean(data?.id);
    },

    async insertInAppNotification(input) {
      const { error } = await admin.from("hub_data").insert({
        source: "notification",
        metadata: {
          user_id: input.userId,
          title: input.title,
          message: input.message,
          type: "system",
          link: input.link,
          dedupe_key: input.dedupeKey,
          read: false,
        },
      });
      if (error) throw new Error(error.message);
    },

    async getUserEmail(userId) {
      const { data, error } = await admin.auth.admin.getUserById(userId);
      if (error) return "";
      return String(data.user?.email ?? "").trim();
    },

    async sendAlertEmail(input: EmailSendRequest): Promise<EmailSendResult> {
      const mailerKey = (getEnv("RESEND_API_KEY") ?? "").trim();
      if (!mailerKey) {
        return { status: "skipped_no_mailer_key" };
      }
      if (!input.to.trim()) {
        return { status: "skipped_no_recipient" };
      }
      const fromEmail = (getEnv("FEEDBACK_FROM_EMAIL") ?? "").trim() ||
        "noreply@jibun.app";
      try {
        const resp = await fetcher("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${mailerKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: fromEmail,
            to: input.to.trim(),
            subject: input.subject,
            html: input.html,
            text: input.text,
          }),
        });
        if (!resp.ok) {
          return {
            status: "failed",
            statusCode: resp.status,
            detail: `Upstream HTTP ${resp.status}`,
          };
        }
        return { status: "sent", statusCode: resp.status };
      } catch (err) {
        return {
          status: "failed",
          detail: err instanceof Error ? err.message.slice(0, 200) : "error",
        };
      }
    },
  };
}
