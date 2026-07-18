import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  allPlatformsFailed,
  buildUpstreamErrorPayload,
  classifyUpstreamError,
  DEVTO_KEY_ROTATE_HINT,
  QIITA_RATE_LIMIT_HINT,
  QIITA_TOKEN_ROTATE_HINT,
  summarizePlatformFailures,
} from "./upstream_error.ts";

Deno.test("classifyUpstreamError: 401 は auth error", () => {
  assertEquals(classifyUpstreamError(401), "upstream_auth_error");
});

Deno.test("classifyUpstreamError: 403 は auth error (rate limit body なし)", () => {
  assertEquals(classifyUpstreamError(403, "Forbidden"), "upstream_auth_error");
});

Deno.test("classifyUpstreamError: 403 + rate limit body は rate_limited", () => {
  assertEquals(
    classifyUpstreamError(403, '{"message":"Rate limit exceeded"}'),
    "upstream_rate_limited",
  );
  assertEquals(
    classifyUpstreamError(403, "ratelimit reached"),
    "upstream_rate_limited",
  );
});

Deno.test("classifyUpstreamError: 429 は rate_limited", () => {
  assertEquals(classifyUpstreamError(429), "upstream_rate_limited");
});

Deno.test("classifyUpstreamError: 404 / 500 / null は generic", () => {
  assertEquals(classifyUpstreamError(404), "upstream_error");
  assertEquals(classifyUpstreamError(500), "upstream_error");
  assertEquals(classifyUpstreamError(null), "upstream_error");
});

Deno.test("buildUpstreamErrorPayload: qiita 401 → rotate hint 付き", () => {
  const p = buildUpstreamErrorPayload({
    targetApi: "qiita",
    status: 401,
    detail: "Unauthorized",
  });
  assertEquals(p.ok, false);
  assertEquals(p.error_code, "upstream_auth_error");
  assertEquals(p.target_api, "qiita");
  assertEquals(p.upstream_status, 401);
  assertEquals(p.hint, QIITA_TOKEN_ROTATE_HINT);
  assertStringIncludes(p.error, "Qiita API error 401");
  assertStringIncludes(p.error, "Unauthorized");
});

Deno.test("buildUpstreamErrorPayload: dev.to 401 → DEVTO hint", () => {
  const p = buildUpstreamErrorPayload({ targetApi: "dev.to", status: 401 });
  assertEquals(p.hint, DEVTO_KEY_ROTATE_HINT);
  assertStringIncludes(p.error, "dev.to API error 401");
});

Deno.test("buildUpstreamErrorPayload: qiita 429 → rate limit hint", () => {
  const p = buildUpstreamErrorPayload({ targetApi: "qiita", status: 429 });
  assertEquals(p.error_code, "upstream_rate_limited");
  assertEquals(p.hint, QIITA_RATE_LIMIT_HINT);
});

Deno.test("buildUpstreamErrorPayload: 404 は hint なし", () => {
  const p = buildUpstreamErrorPayload({
    targetApi: "qiita",
    status: 404,
    detail: "Not found",
  });
  assertEquals(p.error_code, "upstream_error");
  assertEquals("hint" in p, false);
});

Deno.test("buildUpstreamErrorPayload: detail は 300 字に切り詰め", () => {
  const p = buildUpstreamErrorPayload({
    targetApi: "qiita",
    status: 400,
    detail: "x".repeat(1000),
  });
  // "Qiita API error 400: " + 300 chars
  assertEquals(p.error.length <= "Qiita API error 400: ".length + 300, true);
});

Deno.test("buildUpstreamErrorPayload: status null / detail なし", () => {
  const p = buildUpstreamErrorPayload({ targetApi: "qiita", status: null });
  assertEquals(p.upstream_status, null);
  assertEquals(p.error, "Qiita API error");
});

Deno.test("allPlatformsFailed: 空 map は false (未試行)", () => {
  assertEquals(allPlatformsFailed({}), false);
});

Deno.test("allPlatformsFailed: 1 件でも成功があれば false", () => {
  assertEquals(
    allPlatformsFailed({
      qiita: { ok: false, error: "401" },
      devto: { ok: true, url: "https://dev.to/x" },
    }),
    false,
  );
});

Deno.test("allPlatformsFailed: 全滅は true", () => {
  assertEquals(
    allPlatformsFailed({
      qiita: { ok: false, error: "401" },
      devto: { ok: false, error: "key not set" },
    }),
    true,
  );
});

Deno.test("allPlatformsFailed: ok 欠落 entry は失敗扱い", () => {
  assertEquals(allPlatformsFailed({ qiita: { status: 500 } }), true);
});

Deno.test("summarizePlatformFailures: platform 名 + error を列挙", () => {
  const msg = summarizePlatformFailures({
    qiita: { ok: false, error: "Qiita API error 401: Unauthorized" },
    devto: { ok: false, error: "DEVTO_API_KEY not set" },
  });
  assertStringIncludes(msg, "All requested platforms failed");
  assertStringIncludes(msg, "qiita: Qiita API error 401: Unauthorized");
  assertStringIncludes(msg, "devto: DEVTO_API_KEY not set");
});

Deno.test("summarizePlatformFailures: error 欠落は unknown error", () => {
  const msg = summarizePlatformFailures({ qiita: { ok: false } });
  assertStringIncludes(msg, "qiita: unknown error");
});
