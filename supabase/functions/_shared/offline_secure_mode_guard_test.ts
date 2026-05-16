import {
  buildOfflineBlockedResponseBody,
  parseOfflineSecureModePolicy,
  shouldBlockExternalProviderCall,
} from "./offline_secure_mode_guard.ts";
import {
  assertEquals,
  assertObjectMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("offline guard blocks external providers when secure mode is enabled", () => {
  const policy = parseOfflineSecureModePolicy({
    offline_secure_mode: true,
    offline_external_api_blocked: true,
    offline_runtime_configured: false,
    offline_inference_engine: "pleias-rag",
  });

  assertEquals(shouldBlockExternalProviderCall(policy), true);
  assertObjectMatch(
    buildOfflineBlockedResponseBody(policy, {
      action: "edge_llm.invoke",
      provider: "openai",
    }),
    {
      success: false,
      status: "offlineBlocked",
      offline_blocked: true,
      offline_secure_mode: true,
      provider: "openai",
      settings_route: "/settings",
    },
  );
});

Deno.test("offline guard allows online fallback when secure mode is disabled", () => {
  const policy = parseOfflineSecureModePolicy({
    offline_secure_mode: false,
    offline_external_api_blocked: false,
  });

  assertEquals(shouldBlockExternalProviderCall(policy), false);
  assertEquals(policy.localRuntimeConfigured, false);
});

Deno.test("offline guard reports pending local runtime when paths are configured", () => {
  const policy = parseOfflineSecureModePolicy({
    offline_secure_mode: "true",
    offline_external_api_blocked: "true",
    offline_local_model_path: "C:/models/pleias-rag.gguf",
    offline_local_vector_db_path: "C:/rag/lancedb",
    offline_local_runtime_url: "http://127.0.0.1:8765/rag",
    offline_inference_engine: "ollama",
  });

  assertEquals(policy.localRuntimeConfigured, true);
  assertObjectMatch(
    buildOfflineBlockedResponseBody(policy, {
      action: "provider.chat",
      provider: "anthropic",
    }),
    {
      status: "localRuntimePending",
      offline_blocked: true,
      offline_runtime_configured: true,
      offline_inference_engine: "ollama",
      local_runtime_url: "http://127.0.0.1:8765/rag",
    },
  );
});
