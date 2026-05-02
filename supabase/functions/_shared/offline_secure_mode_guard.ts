export type OfflineSecureModePolicy = {
  enabled: boolean;
  externalApiBlocked: boolean;
  localRuntimeConfigured: boolean;
  inferenceEngine: string;
  localModelPath: string;
  localVectorDbPath: string;
  localRuntimeUrl: string;
};

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

  return {
    enabled,
    externalApiBlocked: enabled &&
      (explicitBlocked ?? blockWhenEnabled),
    localRuntimeConfigured,
    inferenceEngine: asString(body.offline_inference_engine) || "pleias-rag",
    localModelPath,
    localVectorDbPath,
    localRuntimeUrl,
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
    action: context.action,
    provider: context.provider ?? null,
    settings_route: "/settings",
    message: policy.localRuntimeConfigured
      ? "Offline secure mode is enabled. Local runtime execution is not wired to ai-hub yet, so external provider calls were blocked."
      : "Offline secure mode is enabled. Configure local model/vector DB paths or disable external API blocking before calling online providers.",
  };
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
