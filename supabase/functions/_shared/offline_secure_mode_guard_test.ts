import {
  buildOfflineBlockedResponseBody,
  DEFAULT_MEMORY_LIMIT_MB,
  listOfflineSecureModeAuditLogs,
  OFFLINE_SECURE_MODE_AUDIT_SOURCE,
  type OfflineSecureAuditStore,
  parseOfflineSecureModePolicy,
  recordAuthorizedOfflineAudit,
  recordOfflineSecureModeAudit,
  resolveOfflineAuditUserId,
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
      memory_limit_mb: DEFAULT_MEMORY_LIMIT_MB,
    },
  );
});

Deno.test(
  "records and lists user-scoped offline secure audit entries safely",
  async () => {
    const stored: Array<{
      id: string;
      source: string;
      metadata: Record<string, unknown>;
      created_at: string;
    }> = [];
    const store: OfflineSecureAuditStore = {
      insertAuditRow(row) {
        stored.push({
          id: `audit-${stored.length + 1}`,
          source: row.source,
          metadata: row.metadata,
          created_at: "2026-11-25T14:00:00Z",
        });
        return Promise.resolve();
      },
      listAuditRows(userId, limit) {
        return Promise.resolve(
          stored
            .filter(
              (r) =>
                r.source === OFFLINE_SECURE_MODE_AUDIT_SOURCE &&
                r.metadata.user_id === userId,
            )
            .slice(0, limit),
        );
      },
    };

    const policy = parseOfflineSecureModePolicy({
      offline_secure_mode: true,
      offline_external_api_blocked: true,
      offline_memory_limit_mb: 16384,
      offline_local_model_path: "C:/models/pleias.gguf",
      offline_local_vector_db_path: "C:/rag/lancedb",
    });
    assertEquals(policy.memoryLimitMb, DEFAULT_MEMORY_LIMIT_MB);

    const res = await recordOfflineSecureModeAudit(store, {
      userId: "user-1",
      action: "memory.rag.query",
      provider: "pleias-rag",
      policy,
      status: "external_api_blocked",
      recordedAt: "2026-11-25T14:00:00Z",
    });
    assertEquals(res.recorded, true);
    assertEquals(res.entry.memory_limit_mb, 8192);

    const logs = await listOfflineSecureModeAuditLogs(store, "user-1", 10);
    assertEquals(logs.length, 1);
    assertEquals(logs[0].action, "memory.rag.query");
    assertEquals(logs[0].external_api_blocked, true);

    const otherLogs = await listOfflineSecureModeAuditLogs(store, "user-2", 10);
    assertEquals(otherLogs.length, 0);

    const failingStore: OfflineSecureAuditStore = {
      insertAuditRow() {
        return Promise.reject(new Error("db offline"));
      },
      listAuditRows() {
        return Promise.resolve([]);
      },
    };
    const safeFail = await recordOfflineSecureModeAudit(failingStore, {
      userId: "user-1",
      action: "memory.search",
      policy,
      status: "external_api_blocked",
    });
    assertEquals(safeFail.recorded, false);
  },
);

Deno.test(
  "resolveOfflineAuditUserId enforces service-role vs WorkOS subject",
  async () => {
    assertEquals(
      resolveOfflineAuditUserId(
        { client_id: "service-role" },
        "11111111-1111-4111-8111-111111111111",
      ),
      { ok: true, userId: "11111111-1111-4111-8111-111111111111" },
    );

    assertEquals(
      resolveOfflineAuditUserId(
        { client_id: "claude", subject: "user_01ABCXYZ" },
        undefined,
      ),
      { ok: true, userId: "user_01ABCXYZ" },
    );

    assertEquals(
      resolveOfflineAuditUserId(
        { client_id: "claude", subject: "user_01ABCXYZ" },
        "user_01ABCXYZ",
      ),
      { ok: true, userId: "user_01ABCXYZ" },
    );

    assertEquals(
      resolveOfflineAuditUserId(
        { client_id: "claude", subject: "user_01ABCXYZ" },
        "22222222-2222-4222-8222-222222222222",
      ),
      { ok: false, status: 403, error: "Forbidden" },
    );

    assertEquals(
      resolveOfflineAuditUserId(
        { client_id: "claude" },
        "22222222-2222-4222-8222-222222222222",
      ),
      { ok: false, status: 403, error: "Forbidden" },
    );

    const policy = parseOfflineSecureModePolicy({
      offline_secure_mode: true,
      offline_external_api_blocked: true,
    });
    const inserted: string[] = [];
    const store: OfflineSecureAuditStore = {
      insertAuditRow(row) {
        inserted.push(String(row.metadata.user_id ?? ""));
        return Promise.resolve();
      },
      listAuditRows() {
        return Promise.resolve([]);
      },
    };
    await recordAuthorizedOfflineAudit(
      store,
      { client_id: "claude", subject: "user_01ABCXYZ" },
      "22222222-2222-4222-8222-222222222222",
      {
        action: "memory.search",
        provider: "pleias-rag",
        policy,
        status: "external_api_blocked",
      },
    );
    assertEquals(inserted, ["user_01ABCXYZ"]);
  },
);
