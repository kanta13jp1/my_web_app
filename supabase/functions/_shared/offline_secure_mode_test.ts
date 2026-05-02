import {
  buildOfflineBlockedPayload,
  envFlagEnabled,
  readOfflineSecureModeConfig,
} from "./offline_secure_mode.ts";

Deno.test("envFlagEnabled recognizes explicit truthy values", () => {
  for (const value of ["1", "true", "TRUE", "yes", "on", "enabled"]) {
    if (!envFlagEnabled(value)) {
      throw new Error(`expected ${value} to be truthy`);
    }
  }
  for (const value of [undefined, "", "0", "false", "off"]) {
    if (envFlagEnabled(value)) {
      throw new Error(`expected ${value} to be falsey`);
    }
  }
});

Deno.test("offline secure mode stays disabled without an explicit flag", () => {
  const config = readOfflineSecureModeConfig(() => undefined);

  if (config.enabled) throw new Error("offline mode should be disabled");
  if (
    buildOfflineBlockedPayload("edge_llm.invoke", {
      readEnv: () => undefined,
    })
  ) {
    throw new Error("disabled offline mode must not block requests");
  }
});

Deno.test("offline secure mode blocks external providers without local runtime", () => {
  const readEnv = (key: string) =>
    key === "AI_OFFLINE_SECURE_MODE" ? "true" : undefined;

  const payload = buildOfflineBlockedPayload("edge_llm.invoke", {
    provider: "openai",
    model: "gpt-4o-mini",
    readEnv,
  });

  if (!payload?.offline_blocked) throw new Error("payload should block");
  if (payload.provider !== "openai") throw new Error("provider not preserved");
  if (payload.local_runtime_configured) {
    throw new Error("local runtime should be reported missing");
  }
});

Deno.test("offline secure mode reports configured local runtime hints", () => {
  const readEnv = (key: string) => {
    const values: Record<string, string> = {
      OFFLINE_SECURE_MODE: "1",
      LOCAL_LLM_ENDPOINT: "http://127.0.0.1:11434",
    };
    return values[key];
  };

  const payload = buildOfflineBlockedPayload("provider.chat", {
    provider: "anthropic",
    readEnv,
  });

  if (!payload?.offline_blocked) throw new Error("payload should block");
  if (!payload.local_runtime_configured) {
    throw new Error("local runtime hint should be configured");
  }
  if (!payload.local_runtime_endpoint_configured) {
    throw new Error("local endpoint hint should be configured");
  }
});
