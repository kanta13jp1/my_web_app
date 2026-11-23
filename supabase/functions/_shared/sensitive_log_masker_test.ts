import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createMaskedLogger,
  DEFAULT_SENSITIVE_LOG_KEYS,
  isSensitiveLogKey,
  MASK_PLACEHOLDER,
  maskLogString,
  maskLogValue,
  maskPayloadMiddleware,
} from "./sensitive_log_masker.ts";

Deno.test("DEFAULT_SENSITIVE_LOG_KEYS and isSensitiveLogKey match normalized keys", () => {
  assertEquals(DEFAULT_SENSITIVE_LOG_KEYS.has("password"), true);
  assertEquals(DEFAULT_SENSITIVE_LOG_KEYS.has("service_role_key"), true);
  assertEquals(isSensitiveLogKey("accessToken"), true);
  assertEquals(isSensitiveLogKey("x-api-key"), true);
  assertEquals(isSensitiveLogKey("userSecret"), true);
  assertEquals(isSensitiveLogKey("customTag"), false);
  assertEquals(isSensitiveLogKey("customTag", ["custom_tag"]), true);
  assertEquals(isSensitiveLogKey("keyboardLayout"), false);
});

Deno.test("maskLogString redacts tokens, JSON secrets, and emails while keeping safe text", () => {
  const input =
    'Authorization: Bearer live_abc123 {"api_key":"k_999","status":"ok"} email=ops@example.com page=3';
  const masked = maskLogString(input);

  assertEquals(masked.includes("live_abc123"), false);
  assertEquals(masked.includes("k_999"), false);
  assertEquals(masked.includes("ops@example.com"), false);
  assertStringIncludes(masked, `"status":"ok"`);
  assertStringIncludes(masked, "page=3");
  assertStringIncludes(masked, `Bearer ${MASK_PLACEHOLDER}`);
});

Deno.test("maskLogValue handles nested objects, Headers, Error, and circular refs", () => {
  const selfRef: Record<string, unknown> = { label: "node", token: "t_secret" };
  selfRef.loop = selfRef;

  const headers = new Headers({
    Authorization: "Bearer super_jwt_val",
    "x-trace-id": "trace-42",
  });

  const masked = maskLogValue({
    headers,
    err: new Error("failed for user@example.com with password=secretPass"),
    nested: [selfRef],
  }) as Record<string, unknown>;

  const mHeaders = masked.headers as Record<string, unknown>;
  assertEquals(mHeaders.authorization ?? mHeaders.Authorization, MASK_PLACEHOLDER);
  assertEquals(mHeaders["x-trace-id"], "trace-42");

  const mErr = masked.err as { name: string; message: string };
  assertEquals(mErr.name, "Error");
  assertEquals(mErr.message.includes("user@example.com"), false);
  assertEquals(mErr.message.includes("secretPass"), false);

  const mNested = masked.nested as Record<string, unknown>[];
  assertEquals(mNested[0].label, "node");
  assertEquals(mNested[0].token, MASK_PLACEHOLDER);
  assertEquals(mNested[0].loop, "[Circular]");
});

Deno.test("maskPayloadMiddleware and createMaskedLogger sanitize request/response logs", () => {
  const summary = maskPayloadMiddleware({
    headers: { cookie: "session=xyz", accept: "application/json" },
    requestBody: { password: "pw1", title: "Hello" },
    responseBody: { refresh_token: "rt_123", count: 5 },
  });

  assertEquals((summary.headers as Record<string, unknown>).cookie, MASK_PLACEHOLDER);
  assertEquals((summary.headers as Record<string, unknown>).accept, "application/json");
  assertEquals((summary.requestBody as Record<string, unknown>).password, MASK_PLACEHOLDER);
  assertEquals((summary.requestBody as Record<string, unknown>).title, "Hello");
  assertEquals((summary.responseBody as Record<string, unknown>).refresh_token, MASK_PLACEHOLDER);
  assertEquals((summary.responseBody as Record<string, unknown>).count, 5);

  const entries: Array<{ level: string; message: string; context: unknown }> = [];
  const logger = createMaskedLogger((level, message, context) => {
    entries.push({ level, message, context });
  });
  logger.error("Auth failed email=admin@example.com", { api_key: "key_1", code: 401 });

  assertEquals(entries.length, 1);
  assertEquals(entries[0].level, "error");
  assertEquals(entries[0].message.includes("admin@example.com"), false);
  const ctx = entries[0].context as Record<string, unknown>;
  assertEquals(ctx.api_key, MASK_PLACEHOLDER);
  assertEquals(ctx.code, 401);
});
