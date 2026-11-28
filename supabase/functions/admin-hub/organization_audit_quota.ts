import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { maskLogString, MASK_PLACEHOLDER } from "../_shared/sensitive_log_masker.ts";

export type OrgAuditEventType =
  | "login"
  | "permission_change"
  | "resource_create"
  | "resource_delete"
  | "quota_warning_80"
  | "quota_limit_exceeded"
  | "quota_policy_update";

export type OrgQuotaResourceType = "api_calls" | "compute_units" | "storage_mb";

export const ALLOWED_AUDIT_EVENT_TYPES: ReadonlySet<string> = new Set([
  "login",
  "permission_change",
  "resource_create",
  "resource_delete",
  "quota_warning_80",
  "quota_limit_exceeded",
  "quota_policy_update",
]);

export const ALLOWED_QUOTA_RESOURCE_TYPES: ReadonlySet<string> = new Set([
  "api_calls",
  "compute_units",
  "storage_mb",
]);

export interface OrgAuditCallerContext {
  userId: string | null;
  isServiceRole: boolean;
}

export interface OrgAuditServiceResponse {
  status: number;
  body: Record<string, unknown>;
}

export interface OrgAuditStoreResult<T> {
  data: T | null;
  error: { message: string } | null;
}

export interface OrganizationAuditLogRow {
  id: string;
  organization_id: string | null;
  actor_user_id: string | null;
  actor_role: string;
  event_type: OrgAuditEventType;
  resource_type: string;
  resource_id: string;
  summary: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface OrganizationQuotaRow {
  id: string;
  organization_id: string;
  resource_type: OrgQuotaResourceType;
  period_key: string;
  limit_amount: number;
  used_amount: number;
  warning_threshold_pct: number;
  warning_80_triggered_at: string | null;
  last_exceeded_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface OrganizationQuotaAlertRow {
  id: string;
  organization_id: string;
  resource_type: OrgQuotaResourceType;
  period_key: string;
  alert_level: "warning_80" | "limit_100";
  usage_pct: number;
  used_amount: number;
  limit_amount: number;
  message: string;
  admin_notified: boolean;
  notified_at: string | null;
  acknowledged_by: string | null;
  acknowledged_at: string | null;
  created_at: string;
}

export interface ConsumeQuotaRpcResult {
  allowed: boolean;
  http_status: number;
  code: string | null;
  error_message: string | null;
  organization_id: string;
  resource_type: OrgQuotaResourceType;
  period_key: string;
  used_amount: number;
  limit_amount: number;
  remaining: number;
  usage_pct: number;
  warning_threshold_pct: number;
  warning_80_triggered: boolean;
  warning_80_newly_triggered: boolean;
}

export interface OrganizationAuditQuotaStore {
  isGlobalAdmin(userId: string): Promise<OrgAuditStoreResult<boolean>>;
  isOrgMemberOrAdmin(
    organizationId: string,
    userId: string,
    requireAdmin: boolean,
  ): Promise<OrgAuditStoreResult<boolean>>;
  recordAuditEvent(input: {
    organizationId: string | null;
    actorUserId: string | null;
    actorRole: string;
    eventType: OrgAuditEventType;
    resourceType: string;
    resourceId: string;
    summary: string;
    metadata: Record<string, unknown>;
  }): Promise<OrgAuditStoreResult<OrganizationAuditLogRow>>;
  listAuditLogs(filters: {
    organizationId?: string;
    eventType?: OrgAuditEventType;
    actorUserId?: string;
    limit: number;
  }): Promise<OrgAuditStoreResult<OrganizationAuditLogRow[]>>;
  consumeQuota(input: {
    organizationId: string;
    resourceType: OrgQuotaResourceType;
    units: number;
    actorUserId: string | null;
    periodKey?: string;
  }): Promise<OrgAuditStoreResult<ConsumeQuotaRpcResult>>;
  listQuotas(filters: {
    organizationId: string;
    periodKey?: string;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaRow[]>>;
  listQuotaAlerts(filters: {
    organizationId: string;
    periodKey?: string;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaAlertRow[]>>;
  updateQuotaLimit(input: {
    organizationId: string;
    resourceType: OrgQuotaResourceType;
    limitAmount: number;
    warningThresholdPct: number;
    periodKey?: string;
    actorUserId: string | null;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaRow>>;
  acknowledgeQuotaAlert(input: {
    alertId: string;
    organizationId: string;
    acknowledgedBy: string | null;
  }): Promise<OrgAuditStoreResult<OrganizationQuotaAlertRow>>;
}

export type FetchLike = (
  input: string | URL,
  init?: RequestInit,
) => Promise<Response>;

export interface OrgQuotaNotifyOptions {
  fetchFn?: FetchLike;
  slackWebhookUrl?: string;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PERIOD_KEY_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

export function currentJstPeriodKey(now: Date = new Date()): string {
  const jstMs = now.getTime() + 9 * 60 * 60 * 1000;
  return new Date(jstMs).toISOString().slice(0, 7);
}

const REDACTED_PREFIX_REGEXES: readonly RegExp[] = [
  new RegExp("\\bgh[pousr]_[A-Za-z0-9_]{8,}\\b", "g"),
  new RegExp("\\bgithub_" + "pat_[A-Za-z0-9_]{12,}\\b", "g"),
  new RegExp("\\bsk[-_](?:live_|test_|proj_)?[A-Za-z0-9_-]{8,}\\b", "g"),
  new RegExp("\\bxox[baprs]-[A-Za-z0-9-]{8,}\\b", "g"),
  new RegExp("\\bAIza[0-9A-Za-z_-]{8,}\\b", "g"),
  new RegExp("\\b(?:sb_" + "secret_|sbp_)[A-Za-z0-9_-]{8,}\\b", "g"),
];

export function sanitizeAuditText(raw: unknown, maxLen = 500): string {
  let text = typeof raw === "string" ? raw.trim() : "";
  if (text === "") return "";
  for (const pattern of REDACTED_PREFIX_REGEXES) {
    text = text.replace(pattern, MASK_PLACEHOLDER);
  }
  return maskLogString(text).slice(0, maxLen);
}

export function sanitizeErrorMessage(
  raw: unknown,
  fallback = "Internal error",
): string {
  const clean = sanitizeAuditText(raw, 240);
  return clean === "" ? fallback : clean;
}

const REDACTED_META_KEYS = new Set([
  "password",
  "secret",
  "access_token",
  "refresh_token",
  "id_token",
  "api_key",
  "apikey",
  "authorization",
  "cookie",
  "service_role",
  "client_secret",
]);

export function sanitizeAuditMetadata(
  raw: unknown,
  depth = 0,
): Record<string, unknown> {
  if (depth > 3 || raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    return {};
  }
  const source = raw as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(source).slice(0, 30)) {
    const cleanKey = key.trim().slice(0, 64);
    if (cleanKey === "") continue;
    const lowered = cleanKey.toLowerCase();
    if (
      REDACTED_META_KEYS.has(lowered) ||
      lowered.endsWith("_secret") ||
      lowered.endsWith("_key") && lowered !== "period_key"
    ) {
      out[cleanKey] = MASK_PLACEHOLDER;
      continue;
    }
    if (typeof val === "string") {
      out[cleanKey] = sanitizeAuditText(val, 240);
    } else if (
      typeof val === "number" && Number.isFinite(val) ||
      typeof val === "boolean" ||
      val === null
    ) {
      out[cleanKey] = val;
    } else if (Array.isArray(val)) {
      out[cleanKey] = val.slice(0, 20).map((item) =>
        typeof item === "string"
          ? sanitizeAuditText(item, 120)
          : (typeof item === "number" || typeof item === "boolean" ? item : null)
      );
    } else if (typeof val === "object") {
      out[cleanKey] = sanitizeAuditMetadata(val, depth + 1);
    }
  }
  return out;
}

function isAllowedWebhookUrl(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    if (parsed.protocol !== "https:") return false;
    const host = parsed.hostname.toLowerCase();
    if (
      host === "" ||
      host === "localhost" ||
      host.endsWith(".local") ||
      host.endsWith(".internal") ||
      /^\d{1,3}(?:\.\d{1,3}){3}$/.test(host) ||
      host.includes(":")
    ) {
      return false;
    }
    return host.includes(".");
  } catch {
    return false;
  }
}

async function notifyAdminThresholdWebhook(
  decision: ConsumeQuotaRpcResult,
  options: OrgQuotaNotifyOptions,
): Promise<boolean> {
  const webhookUrl = (options.slackWebhookUrl ?? "").trim();
  if (webhookUrl === "" || !isAllowedWebhookUrl(webhookUrl)) {
    return false;
  }
  const fetchFn = options.fetchFn ?? fetch;
  try {
    const res = await fetchFn(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text:
          `[Org Quota Warning 80%] org=${decision.organization_id} resource=${decision.resource_type} ` +
          `usage=${decision.used_amount}/${decision.limit_amount} (${decision.usage_pct}%)`,
      }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

export function createSupabaseOrgAuditQuotaStore(
  admin: SupabaseClient,
): OrganizationAuditQuotaStore {
  return {
    async isGlobalAdmin(userId) {
      const { data, error } = await admin
        .from("user_profiles")
        .select("is_admin, role")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) return { data: false, error: { message: error.message } };
      const isAdm = data?.is_admin === true || data?.role === "admin";
      return { data: isAdm, error: null };
    },

    async isOrgMemberOrAdmin(organizationId, userId, requireAdmin) {
      const { data: team, error: teamError } = await admin
        .from("teams")
        .select("owner_id")
        .eq("id", organizationId)
        .maybeSingle();
      if (teamError) return { data: false, error: { message: teamError.message } };
      if (team && team.owner_id === userId) {
        return { data: true, error: null };
      }

      let query = admin
        .from("team_memberships")
        .select("role")
        .eq("team_id", organizationId)
        .eq("user_id", userId);
      if (requireAdmin) {
        query = query.eq("role", "admin");
      }
      const { data: membership, error: memberError } = await query.maybeSingle();
      if (memberError) {
        return { data: false, error: { message: memberError.message } };
      }
      return { data: membership !== null, error: null };
    },

    async recordAuditEvent(input) {
      const { data, error } = await admin.rpc("record_organization_audit_event", {
        p_organization_id: input.organizationId,
        p_actor_user_id: input.actorUserId,
        p_actor_role: input.actorRole,
        p_event_type: input.eventType,
        p_resource_type: input.resourceType,
        p_resource_id: input.resourceId,
        p_summary: input.summary,
        p_metadata: input.metadata,
      });
      return {
        data: data ? (data as OrganizationAuditLogRow) : null,
        error: error ? { message: error.message } : null,
      };
    },

    async listAuditLogs(filters) {
      let query = admin
        .from("organization_audit_logs")
        .select(
          "id, organization_id, actor_user_id, actor_role, event_type, resource_type, resource_id, summary, metadata, created_at",
        );
      if (filters.organizationId) {
        query = query.eq("organization_id", filters.organizationId);
      }
      if (filters.eventType) {
        query = query.eq("event_type", filters.eventType);
      }
      if (filters.actorUserId) {
        query = query.eq("actor_user_id", filters.actorUserId);
      }
      const { data, error } = await query
        .order("created_at", { ascending: false })
        .limit(filters.limit);
      return {
        data: data ? (data as OrganizationAuditLogRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },

    async consumeQuota(input) {
      const { data, error } = await admin.rpc("consume_organization_quota", {
        p_organization_id: input.organizationId,
        p_resource_type: input.resourceType,
        p_units: input.units,
        p_actor_user_id: input.actorUserId,
        p_period_key: input.periodKey ?? null,
      });
      return {
        data: data ? (data as ConsumeQuotaRpcResult) : null,
        error: error ? { message: error.message } : null,
      };
    },

    async listQuotas(filters) {
      let query = admin
        .from("organization_quotas")
        .select(
          "id, organization_id, resource_type, period_key, limit_amount, used_amount, warning_threshold_pct, warning_80_triggered_at, last_exceeded_at, created_at, updated_at",
        )
        .eq("organization_id", filters.organizationId);
      if (filters.periodKey) {
        query = query.eq("period_key", filters.periodKey);
      }
      const { data, error } = await query.order("resource_type", {
        ascending: true,
      });
      return {
        data: data ? (data as OrganizationQuotaRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },

    async listQuotaAlerts(filters) {
      let query = admin
        .from("organization_quota_alerts")
        .select(
          "id, organization_id, resource_type, period_key, alert_level, usage_pct, used_amount, limit_amount, message, admin_notified, notified_at, acknowledged_by, acknowledged_at, created_at",
        )
        .eq("organization_id", filters.organizationId);
      if (filters.periodKey) {
        query = query.eq("period_key", filters.periodKey);
      }
      const { data, error } = await query
        .order("created_at", { ascending: false })
        .limit(20);
      return {
        data: data ? (data as OrganizationQuotaAlertRow[]) : null,
        error: error ? { message: error.message } : null,
      };
    },

    async updateQuotaLimit(input) {
      const { data, error } = await admin.rpc("update_organization_quota_limit", {
        p_organization_id: input.organizationId,
        p_resource_type: input.resourceType,
        p_limit_amount: input.limitAmount,
        p_warning_threshold_pct: input.warningThresholdPct,
        p_period_key: input.periodKey ?? null,
        p_actor_user_id: input.actorUserId,
      });
      return {
        data: data ? (data as OrganizationQuotaRow) : null,
        error: error ? { message: error.message } : null,
      };
    },

    async acknowledgeQuotaAlert(input) {
      const nowIso = new Date().toISOString();
      const { data, error } = await admin
        .from("organization_quota_alerts")
        .update({
          acknowledged_by: input.acknowledgedBy,
          acknowledged_at: nowIso,
        })
        .eq("id", input.alertId)
        .eq("organization_id", input.organizationId)
        .select(
          "id, organization_id, resource_type, period_key, alert_level, usage_pct, used_amount, limit_amount, message, admin_notified, notified_at, acknowledged_by, acknowledged_at, created_at",
        )
        .maybeSingle();
      return {
        data: data ? (data as OrganizationQuotaAlertRow) : null,
        error: error ? { message: error.message } : null,
      };
    },
  };
}

async function authorizeOrgCaller(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  organizationId: string | null,
  requireAdmin: boolean,
): Promise<{ ok: true } | { ok: false; response: OrgAuditServiceResponse }> {
  if (caller.isServiceRole) return { ok: true };
  if (!caller.userId) {
    return { ok: false, response: { status: 401, body: { error: "Unauthorized" } } };
  }

  const globalAdmin = await store.isGlobalAdmin(caller.userId);
  if (globalAdmin.error) {
    return {
      ok: false,
      response: {
        status: 500,
        body: { error: sanitizeErrorMessage(globalAdmin.error.message) },
      },
    };
  }
  if (globalAdmin.data === true) return { ok: true };

  if (!organizationId) {
    return {
      ok: false,
      response: {
        status: 403,
        body: { error: "Forbidden: admin role or organization scope required" },
      },
    };
  }

  const orgAccess = await store.isOrgMemberOrAdmin(
    organizationId,
    caller.userId,
    requireAdmin,
  );
  if (orgAccess.error) {
    return {
      ok: false,
      response: {
        status: 500,
        body: { error: sanitizeErrorMessage(orgAccess.error.message) },
      },
    };
  }
  if (orgAccess.data !== true) {
    return {
      ok: false,
      response: {
        status: 403,
        body: {
          error: requireAdmin
            ? "Forbidden: organization admin or owner permission required"
            : "Forbidden: organization membership required",
        },
      },
    };
  }
  return { ok: true };
}

export async function handleOrgAuditRecord(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  body: Record<string, unknown>,
): Promise<OrgAuditServiceResponse> {
  if (!caller.isServiceRole && !caller.userId) {
    return { status: 401, body: { error: "Unauthorized" } };
  }

  const orgIdRaw = typeof body.organization_id === "string"
    ? body.organization_id.trim()
    : "";
  const organizationId = orgIdRaw === "" ? null : orgIdRaw;
  if (organizationId !== null && !UUID_RE.test(organizationId)) {
    return { status: 400, body: { error: "Invalid organization_id" } };
  }

  const eventType = typeof body.event_type === "string"
    ? body.event_type.trim()
    : "";
  if (!ALLOWED_AUDIT_EVENT_TYPES.has(eventType)) {
    return { status: 400, body: { error: "Unsupported audit event_type" } };
  }

  const resourceType = sanitizeAuditText(body.resource_type, 80);
  if (resourceType === "") {
    return { status: 400, body: { error: "resource_type is required" } };
  }

  if (organizationId !== null) {
    const auth = await authorizeOrgCaller(store, caller, organizationId, false);
    if (!auth.ok) return auth.response;
  }

  const resolvedActorRole = caller.isServiceRole
    ? "service_role"
    : "authenticated";
  const result = await store.recordAuditEvent({
    organizationId,
    actorUserId: caller.userId,
    actorRole: resolvedActorRole,
    eventType: eventType as OrgAuditEventType,
    resourceType,
    resourceId: sanitizeAuditText(body.resource_id, 160),
    summary: sanitizeAuditText(body.summary, 500),
    metadata: sanitizeAuditMetadata(body.metadata),
  });
  if (result.error) {
    return {
      status: 500,
      body: { error: sanitizeErrorMessage(result.error.message) },
    };
  }
  return { status: 201, body: { success: true, entry: result.data } };
}

export async function handleOrgAuditList(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  body: Record<string, unknown>,
): Promise<OrgAuditServiceResponse> {
  const orgIdRaw = typeof body.organization_id === "string"
    ? body.organization_id.trim()
    : "";
  const organizationId = orgIdRaw === "" ? null : orgIdRaw;
  if (organizationId !== null && !UUID_RE.test(organizationId)) {
    return { status: 400, body: { error: "Invalid organization_id" } };
  }

  const auth = await authorizeOrgCaller(store, caller, organizationId, true);
  if (!auth.ok) return auth.response;

  const eventTypeRaw = typeof body.event_type === "string"
    ? body.event_type.trim()
    : "";
  if (eventTypeRaw !== "" && !ALLOWED_AUDIT_EVENT_TYPES.has(eventTypeRaw)) {
    return { status: 400, body: { error: "Unsupported audit event_type filter" } };
  }

  const rawLimit = Number(body.limit ?? 50);
  const limit = Number.isFinite(rawLimit)
    ? Math.max(1, Math.min(200, Math.trunc(rawLimit)))
    : 50;

  const res = await store.listAuditLogs({
    organizationId: organizationId ?? undefined,
    eventType: eventTypeRaw !== "" ? (eventTypeRaw as OrgAuditEventType) : undefined,
    limit,
  });
  if (res.error) {
    return {
      status: 500,
      body: { error: sanitizeErrorMessage(res.error.message) },
    };
  }
  const entries = res.data ?? [];
  return { status: 200, body: { success: true, entries, count: entries.length } };
}

export async function handleOrgQuotaConsume(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  body: Record<string, unknown>,
  notifyOptions: OrgQuotaNotifyOptions = {},
): Promise<OrgAuditServiceResponse> {
  const orgId = typeof body.organization_id === "string"
    ? body.organization_id.trim()
    : "";
  if (!UUID_RE.test(orgId)) {
    return { status: 400, body: { error: "Valid organization_id is required" } };
  }

  const auth = await authorizeOrgCaller(store, caller, orgId, false);
  if (!auth.ok) return auth.response;

  const resourceRaw = typeof body.resource_type === "string"
    ? body.resource_type.trim().toLowerCase()
    : "api_calls";
  if (!ALLOWED_QUOTA_RESOURCE_TYPES.has(resourceRaw)) {
    return { status: 400, body: { error: "Unsupported resource_type" } };
  }

  const rawUnits = Number(body.units ?? 1);
  if (!Number.isFinite(rawUnits) || Math.trunc(rawUnits) < 1 || Math.trunc(rawUnits) > 100000) {
    return { status: 400, body: { error: "units must be between 1 and 100000" } };
  }
  const units = Math.trunc(rawUnits);

  const periodRaw = typeof body.period_key === "string" ? body.period_key.trim() : "";
  if (periodRaw !== "" && !PERIOD_KEY_RE.test(periodRaw)) {
    return { status: 400, body: { error: "period_key must match YYYY-MM" } };
  }

  const res = await store.consumeQuota({
    organizationId: orgId,
    resourceType: resourceRaw as OrgQuotaResourceType,
    units,
    actorUserId: caller.userId,
    periodKey: periodRaw !== "" ? periodRaw : undefined,
  });
  if (res.error || !res.data) {
    return {
      status: 500,
      body: {
        error: sanitizeErrorMessage(
          res.error?.message,
          "Quota enforcement error",
        ),
      },
    };
  }

  const decision = res.data;
  if (!decision.allowed) {
    return {
      status: 429,
      body: {
        success: false,
        allowed: false,
        code: decision.code ?? "QUOTA_EXCEEDED",
        error: decision.error_message ??
          "組織のリソース利用上限に達したため処理をブロックしました。管理者にクォータ引き上げを依頼してください。",
        quota: decision,
      },
    };
  }

  let webhookNotified = false;
  if (decision.warning_80_newly_triggered) {
    webhookNotified = await notifyAdminThresholdWebhook(decision, notifyOptions);
  }

  return {
    status: 200,
    body: {
      success: true,
      allowed: true,
      alert_triggered: decision.warning_80_newly_triggered,
      warning_80_triggered: decision.warning_80_triggered,
      webhook_notified: webhookNotified,
      quota: decision,
    },
  };
}

export async function handleOrgQuotaStatus(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  body: Record<string, unknown>,
): Promise<OrgAuditServiceResponse> {
  const orgId = typeof body.organization_id === "string"
    ? body.organization_id.trim()
    : "";
  if (!UUID_RE.test(orgId)) {
    return { status: 400, body: { error: "Valid organization_id is required" } };
  }

  const auth = await authorizeOrgCaller(store, caller, orgId, false);
  if (!auth.ok) return auth.response;

  const periodRaw = typeof body.period_key === "string" ? body.period_key.trim() : "";
  if (periodRaw !== "" && !PERIOD_KEY_RE.test(periodRaw)) {
    return { status: 400, body: { error: "period_key must match YYYY-MM" } };
  }
  const periodKey = periodRaw !== "" ? periodRaw : currentJstPeriodKey();

  const quotasRes = await store.listQuotas({ organizationId: orgId, periodKey });
  if (quotasRes.error) {
    return {
      status: 500,
      body: { error: sanitizeErrorMessage(quotasRes.error.message) },
    };
  }

  const alertsRes = await store.listQuotaAlerts({ organizationId: orgId, periodKey });
  if (alertsRes.error) {
    return {
      status: 500,
      body: { error: sanitizeErrorMessage(alertsRes.error.message) },
    };
  }

  const quotas = (quotasRes.data ?? []).map((row) => {
    const pct = row.limit_amount > 0
      ? Math.round((row.used_amount / row.limit_amount) * 10000) / 100
      : 0;
    return {
      ...row,
      usage_pct: pct,
      remaining: Math.max(row.limit_amount - row.used_amount, 0),
      is_warning_80: pct >= row.warning_threshold_pct,
      is_exceeded: row.used_amount >= row.limit_amount,
    };
  });
  const alerts = alertsRes.data ?? [];

  return {
    status: 200,
    body: {
      success: true,
      organization_id: orgId,
      period_key: periodKey,
      quotas,
      alerts,
      warning_80_active: quotas.some((q) => q.is_warning_80),
      limit_exceeded_active: quotas.some((q) => q.is_exceeded),
    },
  };
}

export async function handleOrgQuotaUpdateLimit(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  body: Record<string, unknown>,
): Promise<OrgAuditServiceResponse> {
  const orgId = typeof body.organization_id === "string"
    ? body.organization_id.trim()
    : "";
  if (!UUID_RE.test(orgId)) {
    return { status: 400, body: { error: "Valid organization_id is required" } };
  }

  const auth = await authorizeOrgCaller(store, caller, orgId, true);
  if (!auth.ok) return auth.response;

  const resourceRaw = typeof body.resource_type === "string"
    ? body.resource_type.trim().toLowerCase()
    : "";
  if (!ALLOWED_QUOTA_RESOURCE_TYPES.has(resourceRaw)) {
    return { status: 400, body: { error: "Unsupported resource_type" } };
  }

  const limitRaw = Number(body.limit_amount);
  if (!Number.isFinite(limitRaw) || Math.trunc(limitRaw) <= 0) {
    return { status: 400, body: { error: "limit_amount must be positive" } };
  }
  const thresholdRaw = Number(body.warning_threshold_pct ?? 80);
  if (!Number.isFinite(thresholdRaw) || thresholdRaw < 1 || thresholdRaw > 100) {
    return {
      status: 400,
      body: { error: "warning_threshold_pct must be between 1 and 100" },
    };
  }

  const periodRaw = typeof body.period_key === "string" ? body.period_key.trim() : "";
  if (periodRaw !== "" && !PERIOD_KEY_RE.test(periodRaw)) {
    return { status: 400, body: { error: "period_key must match YYYY-MM" } };
  }

  const res = await store.updateQuotaLimit({
    organizationId: orgId,
    resourceType: resourceRaw as OrgQuotaResourceType,
    limitAmount: Math.trunc(limitRaw),
    warningThresholdPct: Math.round(thresholdRaw * 100) / 100,
    periodKey: periodRaw !== "" ? periodRaw : undefined,
    actorUserId: caller.userId,
  });
  if (res.error || !res.data) {
    return {
      status: 500,
      body: {
        error: sanitizeErrorMessage(
          res.error?.message,
          "Failed to update quota limit",
        ),
      },
    };
  }
  return { status: 200, body: { success: true, quota: res.data } };
}

export async function handleOrgQuotaAcknowledgeAlert(
  store: OrganizationAuditQuotaStore,
  caller: OrgAuditCallerContext,
  body: Record<string, unknown>,
): Promise<OrgAuditServiceResponse> {
  const orgId = typeof body.organization_id === "string"
    ? body.organization_id.trim()
    : "";
  const alertId = typeof body.alert_id === "string" ? body.alert_id.trim() : "";
  if (!UUID_RE.test(orgId) || !UUID_RE.test(alertId)) {
    return {
      status: 400,
      body: { error: "Valid organization_id and alert_id are required" },
    };
  }

  const auth = await authorizeOrgCaller(store, caller, orgId, true);
  if (!auth.ok) return auth.response;

  const res = await store.acknowledgeQuotaAlert({
    alertId,
    organizationId: orgId,
    acknowledgedBy: caller.userId,
  });
  if (res.error) {
    return {
      status: 500,
      body: { error: sanitizeErrorMessage(res.error.message) },
    };
  }
  if (!res.data) {
    return { status: 404, body: { error: "Quota alert not found" } };
  }
  return { status: 200, body: { success: true, alert: res.data } };
}
