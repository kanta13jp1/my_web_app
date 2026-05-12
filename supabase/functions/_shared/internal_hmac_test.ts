import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildInternalHmacHeaders,
  clearInternalHmacNonceCacheForTest,
  sha256Hex,
  verifyInternalHmacRequest,
} from "./internal_hmac.ts";

const SECRET = "test-secret-with-enough-entropy";
const NOW = new Date("2026-05-09T00:00:00Z");
const NONCE = "018f3b68-6d8f-4b62-9f9b-2e826b33c000";

Deno.test("sha256Hex returns deterministic hex", async () => {
  assertEquals(
    await sha256Hex("hello"),
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  );
});

Deno.test("verifyInternalHmacRequest accepts a fresh signed request", async () => {
  clearInternalHmacNonceCacheForTest();
  const body = JSON.stringify({ action: "memory.search" });
  const headers = await buildInternalHmacHeaders(
    "POST",
    "/functions/v1/memory-search-hub",
    body,
    SECRET,
    NOW,
    NONCE,
  );
  const req = new Request(
    "https://example.test/functions/v1/memory-search-hub",
    {
      method: "POST",
      headers,
      body,
    },
  );

  assertEquals(
    await verifyInternalHmacRequest(req, { secret: SECRET, now: NOW }),
    { ok: true },
  );
});

Deno.test("verifyInternalHmacRequest rejects nonce replay", async () => {
  clearInternalHmacNonceCacheForTest();
  const body = "{}";
  const headers = await buildInternalHmacHeaders(
    "POST",
    "/internal/call",
    body,
    SECRET,
    NOW,
    NONCE,
  );
  const req = new Request("https://example.test/internal/call", {
    method: "POST",
    headers,
    body,
  });

  assertEquals(
    await verifyInternalHmacRequest(req, { secret: SECRET, now: NOW }),
    { ok: true },
  );
  assertEquals(
    await verifyInternalHmacRequest(req, { secret: SECRET, now: NOW }),
    { ok: false, reason: "nonce_replay" },
  );
});

Deno.test("verifyInternalHmacRequest rejects tampered bodies and stale timestamps", async () => {
  clearInternalHmacNonceCacheForTest();
  const headers = await buildInternalHmacHeaders(
    "POST",
    "/internal/call",
    '{"ok":true}',
    SECRET,
    NOW,
    NONCE,
  );
  const tampered = new Request("https://example.test/internal/call", {
    method: "POST",
    headers,
    body: '{"ok":false}',
  });

  assertEquals(
    await verifyInternalHmacRequest(tampered, { secret: SECRET, now: NOW }),
    { ok: false, reason: "signature_mismatch" },
  );

  clearInternalHmacNonceCacheForTest();
  const late = new Date(NOW.getTime() + 6 * 60 * 1000);
  const stale = new Request("https://example.test/internal/call", {
    method: "POST",
    headers,
    body: '{"ok":true}',
  });
  assertEquals(
    await verifyInternalHmacRequest(stale, { secret: SECRET, now: late }),
    { ok: false, reason: "timestamp_skew" },
  );
});

Deno.test("buildInternalHmacHeaders produces unique nonce by default", async () => {
  const first = await buildInternalHmacHeaders("GET", "/a", "", SECRET, NOW);
  const second = await buildInternalHmacHeaders("GET", "/a", "", SECRET, NOW);
  assertNotEquals(
    first.get("X-Internal-Nonce"),
    second.get("X-Internal-Nonce"),
  );
});
