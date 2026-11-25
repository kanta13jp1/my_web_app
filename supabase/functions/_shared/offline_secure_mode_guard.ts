import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const OFFLINE_SECURE_MODE_AUDIT_SOURCE = "offline_secure_mode_audit";
export const DEFAULT_MEMORY_LIMIT_MB = 8192;
export const MIN_MEMORY_LIMIT_MB = 512;

export type OfflineSecureModePolicy = {
  enabled: boolean;
  externalApiBlocked: boolean;
  localRuntimeConfigured: boolean;
  inferenceEngine: string;
  localModelPath: string;
  localVectorDbPath: string;
  localRuntimeUrl: string;
  memoryLimitMb: number;
};

export interface OfflineSecureAuditEntry {
  id: string | null;
  user_id: string;
  action: string;
  provider: string;
  secure_mode_enabled: boolean;
  external_api_blocked: boolean;
  status: string;
  memory_limit_mb: number;
  local_runtime_configured: boolean;
  recorded_at: string;
}

export interface OfflineSecureAuditStore {
  insertAuditRow(row: {
    source: string;
    metadata: Record<string, unknown>;
  }): Promise<void>;
  listAuditRows(
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
}

export interface OfflineAuditAuthContext {
  client_id?: string | null;
  subject?: string | null;
}

export type OfflineAuditIdentityResult =
  | { ok: true; userId: string }
  | { ok: false; status: 400 | 403; error: string };

export function resolveOfflineAuditUserId(
  ctx: OfflineAuditAuthContext | null | undefined,
  requestedUserId: unknown,
  options?: {
    allowFallbackClientId?: boolean;
    ignoreCrossUserMismatch?: boolean;
  },
): OfflineAuditIdentityResult {
  const trustedRole = ctx?.client_id === "service-role";
  if (
    !trustedRole &&
    !options?.ignoreCrossUserMismatch &&
    requestedUserId != null &&
    typeof requestedUserId !== "string"
  ) {
    return { ok: false, status: 400, error: "valid user_id required" };
  }
  const subject = asString(ctx?.subject);
  const requested = asString(requestedUserId);

  if (trustedRole) {
    const resolved = requested || subject;
    if (resolved) {
      return { ok: true, userId: resolved };
    }
    if (options?.allowFallbackClientId) {
      return { ok: true, userId: "service-role" };
    }
    return { ok: false, status: 400, error: "valid user_id required" };
  }

  if (
    !options?.ignoreCrossUserMismatch &&
    requested.length > 0 &&
    requested !== subject
  ) {
    return { ok: false, status: 403, error: "Forbidden" };
  }

  if (subject.length > 0) {
    return { ok: true, userId: subject };
  }
  if (options?.allowFallbackClientId) {
    return { ok: true, userId: asString(ctx?.client_id) || "anonymous" };
  }
  return { ok: false, status: 400, error: "valid user_id required" };
}

export function normalizeMemoryLimitMb(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_MEMORY_LIMIT_MB;
  }
  return Math.max(
    MIN_MEMORY_LIMIT_MB,
    Math.min(DEFAULT_MEMORY_LIMIT_MB, Math.round(parsed)),
  );
}

export function parseOfflineSecureModePolicy(
  body: Record<string, unknown>,
): OfflineSecureModePolicy {
  const enabled = parseBooleanish(body.offline_secure_mode, false);
  const blockWhenEnabled = parseBooleanish(
    body.offline_block_external_api_when_enabled,
    true,
  );
  const explicitBlocked = body.offline_external_api_blocked === undefined
    ? null
    : parseBooleanish(body.offline_external_api_blocked, false);
  const localModelPath = asString(body.offline_local_model_path);
  const localVectorDbPath = asString(body.offline_local_vector_db_path);
  const localRuntimeUrl = asString(body.offline_local_runtime_url) ||
    "http://127.0.0.1:8765/rag";
  const inferredRuntimeConfigured = localModelPath.length > 0 &&
    localVectorDbPath.length > 0;
  const localRuntimeConfigured = body.offline_runtime_configured === undefined
    ? inferredRuntimeConfigured
    : parseBooleanish(body.offline_runtime_configured, false);
  const memoryLimitMb = normalizeMemoryLimitMb(
    body.offline_memory_limit_mb ?? body.memory_limit_mb,
  );

  return {
    enabled,
    externalApiBlocked: enabled &&
      (explicitBlocked ?? blockWhenEnabled),
    localRuntimeConfigured,
    inferenceEngine: asString(body.offline_inference_engine) || "pleias-rag",
    localModelPath,
    localVectorDbPath,
    localRuntimeUrl,
    memoryLimitMb,
  };
}

export function shouldBlockExternalProviderCall(
  policy: OfflineSecureModePolicy,
): boolean {
  return policy.enabled && policy.externalApiBlocked;
}

export function buildOfflineBlockedResponseBody(
  policy: OfflineSecureModePolicy,
  context: { action: string; provider?: string | null },
): Record<string, unknown> {
  return {
    success: false,
    status: policy.localRuntimeConfigured
      ? "localRuntimePending"
      : "offlineBlocked",
    offline_blocked: true,
    offline_secure_mode: policy.enabled,
    offline_runtime_configured: policy.localRuntimeConfigured,
    local_runtime_configured: policy.localRuntimeConfigured,
    local_runtime_url: policy.localRuntimeUrl,
    offline_inference_engine: policy.inferenceEngine,
    memory_limit_mb: policy.memoryLimitMb,
    action: context.action,
    provider: context.provider ?? null,
    settings_route: "/settings",
    message: policy.localRuntimeConfigured
      ? "Offline secure mode is enabled. Local runtime execution is not wired to ai-hub yet, so external provider calls were blocked."
      : "Offline secure mode is enabled. Configure local model/vector DB paths or disable external API blocking before calling online providers.",
  };
}

export function createSupabaseOfflineAuditStore(
  admin: SupabaseClient,
): OfflineSecureAuditStore {
  return {
    async insertAuditRow(row) {
      const { error } = await admin.from("hub_data").insert(row);
      if (error) {
        throw new Error(error.message);
      }
    },
    async listAuditRows(userId, limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", OFFLINE_SECURE_MODE_AUDIT_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) {
        throw new Error(error.message);
      }
      return ((data ?? []) as unknown[]).filter(
        (item): item is Record<string, unknown> =>
          item != null && typeof item === "object",
      );
    },
  };
}

export function buildOfflineSecureAuditEntry(input: {
  userId: string;
  action: string;
  provider?: string | null;
  policy: OfflineSecureModePolicy;
  status: string;
  recordedAt?: string;
}): OfflineSecureAuditEntry {
  return {
    id: null,
    user_id: input.userId.trim(),
    action: asString(input.action) || "unknown",
    provider: asString(input.provider) || input.policy.inferenceEngine,
    secure_mode_enabled: input.policy.enabled,
    external_api_blocked: input.policy.externalApiBlocked,
    status: asString(input.status) || "recorded",
    memory_limit_mb: input.policy.memoryLimitMb,
    local_runtime_configured: input.policy.localRuntimeConfigured,
    recorded_at: input.recordedAt ?? new Date().toISOString(),
  };
}

export async function recordOfflineSecureModeAudit(
  store: OfflineSecureAuditStore,
  input: {
    userId: string;
    action: string;
    provider?: string | null;
    policy: OfflineSecureModePolicy;
    status: string;
    recordedAt?: string;
  },
): Promise<{ recorded: boolean; entry: OfflineSecureAuditEntry }> {
  const entry = buildOfflineSecureAuditEntry(input);
  try {
    await store.insertAuditRow({
      source: OFFLINE_SECURE_MODE_AUDIT_SOURCE,
      metadata: {
        user_id: entry.user_id,
        action: entry.action,
        provider: entry.provider,
        secure_mode_enabled: entry.secure_mode_enabled,
        external_api_blocked: entry.external_api_blocked,
        status: entry.status,
        memory_limit_mb: entry.memory_limit_mb,
        local_runtime_configured: entry.local_runtime_configured,
        recorded_at: entry.recorded_at,
      },
    });
    return { recorded: true, entry };
  } catch (error) {
    console.warn("offline secure audit log skipped", error);
    return { recorded: false, entry };
  }
}

export async function recordAuthorizedOfflineAudit(
  store: OfflineSecureAuditStore,
  ctx: OfflineAuditAuthContext | null | undefined,
  requestedUserId: unknown,
  input: {
    action: string;
    provider?: string | null;
    policy: OfflineSecureModePolicy;
    status: string;
  },
): Promise<void> {
  if (!input.policy.enabled) return;
  const identity = resolveOfflineAuditUserId(ctx, requestedUserId, {
    allowFallbackClientId: true,
    ignoreCrossUserMismatch: true,
  });
  if (!identity.ok) return;
  await recordOfflineSecureModeAudit(store, {
    userId: identity.userId,
    action: input.action,
    provider: input.provider,
    policy: input.policy,
    status: input.status,
  });
}

export async function listOfflineSecureModeAuditLogs(
  store: OfflineSecureAuditStore,
  userId: string,
  limit = 20,
): Promise<OfflineSecureAuditEntry[]> {
  const cleanUserId = userId.trim();
  if (!cleanUserId) return [];
  const safeLimit = Math.max(1, Math.min(100, Math.floor(limit || 20)));
  const rows = await store.listAuditRows(cleanUserId, safeLimit);
  return rows.map((row) => {
    const meta = row.metadata && typeof row.metadata === "object"
      ? row.metadata as Record<string, unknown>
      : {};
    return {
      id: row.id == null ? null : String(row.id),
      user_id: asString(meta.user_id) || cleanUserId,
      action: asString(meta.action) || "unknown",
      provider: asString(meta.provider) || "pleias-rag",
      secure_mode_enabled: parseBooleanish(meta.secure_mode_enabled, false),
      external_api_blocked: parseBooleanish(meta.external_api_blocked, false),
      status: asString(meta.status) || "recorded",
      memory_limit_mb: normalizeMemoryLimitMb(meta.memory_limit_mb),
      local_runtime_configured: parseBooleanish(
        meta.local_runtime_configured,
        false,
      ),
      recorded_at: asString(meta.recorded_at) ||
        (row.created_at == null ? "" : String(row.created_at)),
    };
  });
}

function parseBooleanish(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value !== "string") return fallback;
  const normalized = value.trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "off"].includes(normalized)) return false;
  return fallback;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
