import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildXApiErrorPayload } from "./x-client.ts";

Deno.test("402 credits exhaustion maps to x_billing_blocked", () => {
  // 実障害(2026-07-06): "Your enrolled account [id] does not have any
  // credits to fulfill this request." が生英語のまま UI に出た。
  const payload = buildXApiErrorPayload(
    402,
    {
      detail:
        "Your enrolled account [1601394201349935104] does not have any credits to fulfill this request.",
    },
    "",
  );
  assertEquals(payload.code, "x_billing_blocked");
  assertStringIncludes(payload.actionRequired, "クレジット");
  assertStringIncludes(payload.actionRequired, "console.x.com");
});

Deno.test("spend-cap 403 also maps to x_billing_blocked", () => {
  const payload = buildXApiErrorPayload(
    403,
    { detail: "Monthly spend cap reached for this billing cycle." },
    "",
  );
  assertEquals(payload.code, "x_billing_blocked");
});

Deno.test("ordinary 403 keeps the x_forbidden mapping", () => {
  const payload = buildXApiErrorPayload(
    403,
    { detail: "You are not permitted to perform this action." },
    "",
  );
  assertEquals(payload.code, "x_forbidden");
});

Deno.test("client-not-enrolled mapping is unchanged", () => {
  const payload = buildXApiErrorPayload(
    403,
    { reason: "client-not-enrolled" },
    "",
  );
  // reason=client-not-enrolled は billing 語を含まない限り従来コードを維持。
  assertEquals(payload.code, "x_client_not_enrolled");
});
