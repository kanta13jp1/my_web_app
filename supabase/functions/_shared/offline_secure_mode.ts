export type EnvReader = (key: string) => string | undefined;

export type OfflineSecureModeConfig = {
  enabled: boolean;
  source: string | null;
  localRuntimeConfigured: boolean;
  localRuntimeEndpointConfigured: boolean;
  localModelPathConfigured: boolean;
  localVectorDbPathConfigured: boolean;
};

export type OfflineBlockedPayload = {
  success: false;
  status: "offlineSecureModeBlocked";
  error: "offline_secure_mode_enabled";
  offline_blocked: true;
  action: string;
  provider: string | null;
  model: string | null;
  local_runtime_configured: boolean;
  local_runtime_endpoint_configured: boolean;
  local_model_path_configured: boolean;
  local_vector_db_path_configured: boolean;
  required_next_step: "configure_local_runtime";
  message: string;
};

const OFFLINE_MODE_ENV_KEYS = [
  "AI_OFFLINE_SECURE_MODE",
  "OFFLINE_SECURE_MODE",
  "MY_WEB_APP_OFFLINE_SECURE_MODE",
];

const LOCAL_RUNTIME_ENDPOINT_KEYS = [
  "LOCAL_LLM_ENDPOINT",
  "LOCAL_RAG_ENDPOINT",
  "AI_LOCAL_RUNTIME_ENDPOINT",
];

const LOCAL_MODEL_PATH_KEYS = [
  "LOCAL_LLM_MODEL_PATH",
  "LOCAL_MODEL_PATH",
  "PLEIAS_MODEL_PATH",
];

const LOCAL_VECTOR_DB_PATH_KEYS = [
  "LOCAL_VECTOR_DB_PATH",
  "LOCAL_LANCEDB_PATH",
  "LANCEDB_PATH",
];

function defaultEnvReader(key: string): string | undefined {
  return Deno.env.get(key) ?? undefined;
}

export function envFlagEnabled(value: string | undefined): boolean {
  if (value === undefined) return false;
  return ["1", "true", "yes", "on", "enabled"].includes(
    value.trim().toLowerCase(),
  );
}

function hasAnyEnv(keys: string[], readEnv: EnvReader): boolean {
  return keys.some((key) => {
    const value = readEnv(key);
    return typeof value === "string" && value.trim().length > 0;
  });
}

export function readOfflineSecureModeConfig(
  readEnv: EnvReader = defaultEnvReader,
): OfflineSecureModeConfig {
  const source =
    OFFLINE_MODE_ENV_KEYS.find((key) => envFlagEnabled(readEnv(key))) ?? null;
  const localRuntimeEndpointConfigured = hasAnyEnv(
    LOCAL_RUNTIME_ENDPOINT_KEYS,
    readEnv,
  );
  const localModelPathConfigured = hasAnyEnv(LOCAL_MODEL_PATH_KEYS, readEnv);
  const localVectorDbPathConfigured = hasAnyEnv(
    LOCAL_VECTOR_DB_PATH_KEYS,
    readEnv,
  );

  return {
    enabled: source !== null,
    source,
    localRuntimeConfigured: localRuntimeEndpointConfigured ||
      (localModelPathConfigured && localVectorDbPathConfigured),
    localRuntimeEndpointConfigured,
    localModelPathConfigured,
    localVectorDbPathConfigured,
  };
}

export function buildOfflineBlockedPayload(
  action: string,
  options: {
    provider?: string | null;
    model?: string | null;
    readEnv?: EnvReader;
  } = {},
): OfflineBlockedPayload | null {
  const config = readOfflineSecureModeConfig(options.readEnv);
  if (!config.enabled) return null;

  return {
    success: false,
    status: "offlineSecureModeBlocked",
    error: "offline_secure_mode_enabled",
    offline_blocked: true,
    action,
    provider: options.provider ?? null,
    model: options.model ?? null,
    local_runtime_configured: config.localRuntimeConfigured,
    local_runtime_endpoint_configured: config.localRuntimeEndpointConfigured,
    local_model_path_configured: config.localModelPathConfigured,
    local_vector_db_path_configured: config.localVectorDbPathConfigured,
    required_next_step: "configure_local_runtime",
    message:
      "Offline secure mode is enabled. External AI providers are blocked; configure the local runtime before invoking AI.",
  };
}
