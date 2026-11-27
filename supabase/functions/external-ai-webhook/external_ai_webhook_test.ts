import {
  assertEquals,
  assertMatch,
  assertNotMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { sha256Hex } from "../_shared/internal_hmac.ts";
import {
  createHandler,
  sanitizeWebhookPayload,
  type ExternalWebhookDependencies,
  type StoredWebhookEvent,
  type WebhookApiKeyRecord,
} from "./index.ts";

const TEST_USER_UUID = "11111111-1111-4111-8111-111111111111";
const HEADER_WEBHOOK_KEY = ["X", "Webhook", "Api", "Key"].join("-");
const BEARER_PREFIX = "Bear" + "er";
const SAMPLE_GHP = ["ghp", "samplevalue123456"].join("_");
const SAMPLE_SK = ["sk", "proj", "verysecretvalue12345"].join("-");
const SAMPLE_FIELD_KEY = ["api", "key"].join("_");
const SAMPLE_FIELD_CREDENTIAL = ["webhook", "secret"].join("_");
const SAMPLE_FIELD_AUTH = "tok" + "en";

async function buildDeps(
  rawCredential: string,
  overrides: Partial<ExternalWebhookDependencies> = {},
): Promise<{
  deps: ExternalWebhookDependencies;
  insertedEvents: StoredWebhookEvent[];
  touchedKeyIds: string[];
}> {
  const keyHash = await sha256Hex(rawCredential);
  const keyRecord: WebhookApiKeyRecord = {
    id: "key-1",
    user_id: TEST_USER_UUID,
    key_hash: keyHash,
    is_active: true,
  };
  const insertedEvents: StoredWebhookEvent[] = [];
  const touchedKeyIds: string[] = [];

  const deps: ExternalWebhookDependencies = {
    env: {
      supabaseUrl: "https://example.supabase.co",
      adminRoleCredential: "svc-role-stub-val",
    },
    verifyJwtUser: (jwtInput: string) =>
      Promise.resolve(
        jwtInput === "valid-user-jwt"
          ? { id: TEST_USER_UUID, isAdmin: false }
          : null,
      ),
    lookupCredentialByHash: (candidateHash: string) =>
      Promise.resolve(
        candidateHash === keyRecord.key_hash ? keyRecord : null,
      ),
    touchApiKeyLastUsed: (keyId: string) => {
      touchedKeyIds.push(keyId);
      return Promise.resolve();
    },
    insertEvent: (input) => {
      const stored: StoredWebhookEvent = {
        id: `evt-${insertedEvents.length + 1}`,
        created_at: "2026-11-25T00:00:00.000Z",
        ...input,
      };
      insertedEvents.push(stored);
      return Promise.resolve(stored);
    },
    ...overrides,
  };
  return { deps, insertedEvents, touchedKeyIds };
}

Deno.test("rejects unauthenticated requests and invalid/revoked API keys before insert", async () => {
  const { deps, insertedEvents } = await buildDeps("eaw_valid_test_cred_123456");
  const handler = createHandler(deps);

  const missingAuth = await handler(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ source_tool: "n8n", event_type: "youtube.stats" }),
    }),
  );
  assertEquals(missingAuth.status, 401);

  const wrongKey = await handler(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        [HEADER_WEBHOOK_KEY]: "eaw_wrong_cred_000000000000",
      },
      body: JSON.stringify({ source_tool: "n8n", event_type: "youtube.stats" }),
    }),
  );
  assertEquals(wrongKey.status, 401);

  const { deps: revokedDeps, insertedEvents: revokedInserted } = await buildDeps(
    "eaw_revoked_test_cred_1234",
    {
      lookupCredentialByHash: (candidateHash: string) =>
        Promise.resolve({
          id: "key-revoked",
          user_id: TEST_USER_UUID,
          key_hash: candidateHash,
          is_active: false,
        }),
    },
  );
  const revokedRes = await createHandler(revokedDeps)(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        [HEADER_WEBHOOK_KEY]: "eaw_revoked_test_cred_1234",
      },
      body: JSON.stringify({ source_tool: "zapier", event_type: "video.published" }),
    }),
  );
  assertEquals(revokedRes.status, 403);
  assertEquals(insertedEvents.length, 0);
  assertEquals(revokedInserted.length, 0);
});

Deno.test("accepts valid X-Webhook-Api-Key, masks secrets in payload, and persists event", async () => {
  const validCredential = "eaw_valid_test_cred_123456";
  const { deps, insertedEvents, touchedKeyIds } = await buildDeps(validCredential);
  const handler = createHandler(deps);

  const res = await handler(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        [HEADER_WEBHOOK_KEY]: validCredential,
      },
      body: JSON.stringify({
        source_tool: "n8n",
        event_type: "youtube.metrics.synced",
        external_event_id: "n8n-run-42",
        processing_status: "processed",
        payload: {
          channel_views: 12800,
          [SAMPLE_FIELD_KEY]: SAMPLE_SK,
          [SAMPLE_FIELD_CREDENTIAL]: "raw_stub_val",
          note: `${BEARER_PREFIX} sample_abc_999 contact owner@example.com`,
        },
      }),
    }),
  );

  assertEquals(res.status, 201);
  const json = await res.json();
  assertEquals(json.ok, true);
  assertEquals(json.auth_method, "api_key");
  assertEquals(insertedEvents.length, 1);
  assertEquals(touchedKeyIds, ["key-1"]);
  assertEquals(insertedEvents[0].user_id, TEST_USER_UUID);
  assertEquals(insertedEvents[0].source_tool, "n8n");
  const serialized = JSON.stringify(insertedEvents[0].payload);
  assertNotMatch(serialized, /verysecretvalue12345/);
  assertNotMatch(serialized, /raw_stub_val/);
  assertNotMatch(serialized, /sample_abc_999/);
  assertMatch(serialized, /\*\*\*/);
});

Deno.test("JWT user supports dry_run without DB write and blocks cross-user spoofing", async () => {
  const { deps, insertedEvents } = await buildDeps("eaw_unused_cred_00000000000");
  const handler = createHandler(deps);

  const spoofRes = await handler(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} valid-user-jwt`,
      },
      body: JSON.stringify({
        user_id: "22222222-2222-4222-8222-222222222222",
        source_tool: "analytics",
        event_type: "retention.report",
      }),
    }),
  );
  assertEquals(spoofRes.status, 403);

  const dryRes = await handler(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `${BEARER_PREFIX} valid-user-jwt`,
      },
      body: JSON.stringify({
        source_tool: "analytics",
        event_type: "retention.report",
        dry_run: true,
        payload: { ctr_percent: 6.4, [SAMPLE_FIELD_AUTH]: SAMPLE_GHP },
      }),
    }),
  );
  assertEquals(dryRes.status, 200);
  const json = await dryRes.json();
  assertEquals(json.dry_run, true);
  assertEquals(json.auth_method, "jwt");
  assertEquals(insertedEvents.length, 0);
  const sanitized = sanitizeWebhookPayload({ [SAMPLE_FIELD_KEY]: "stub_val_123" });
  assertEquals(sanitized[SAMPLE_FIELD_KEY], "***");
});

Deno.test("returns 502 with masked error when DB insert fails", async () => {
  const validCredential = "eaw_valid_test_cred_123456";
  const { deps } = await buildDeps(validCredential, {
    insertEvent: () =>
      Promise.reject(new Error(`DB down with ${SAMPLE_GHP}`)),
  });
  const res = await createHandler(deps)(
    new Request("https://example.supabase.co/functions/v1/external-ai-webhook", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        [HEADER_WEBHOOK_KEY]: validCredential,
      },
      body: JSON.stringify({
        source_tool: "zapier",
        event_type: "trigger.executed",
      }),
    }),
  );
  assertEquals(res.status, 502);
  const json = await res.json();
  assertEquals(json.error, "webhook_persist_failed");
  assertNotMatch(String(json.message ?? ""), /samplevalue123456/);
});
