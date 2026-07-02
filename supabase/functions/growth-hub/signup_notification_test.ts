import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildSignupSlackPayload,
  isRecentSignupCreatedAt,
  resolveSignupChannel,
} from "./signup_notification.ts";

Deno.test("resolveSignupChannel maps known signup and touch signals", () => {
  assertEquals(resolveSignupChannel("signup_submit_landing"), "landing");
  assertEquals(resolveSignupChannel("signup_submit_referral"), "referral");
  assertEquals(resolveSignupChannel("touch_comparison_slack"), "comparison");
  assertEquals(resolveSignupChannel(""), "unknown");
});

Deno.test("isRecentSignupCreatedAt accepts only recent auth users", () => {
  const now = new Date("2026-07-02T00:00:00.000Z");
  assertEquals(
    isRecentSignupCreatedAt("2026-07-01T23:30:00.000Z", now),
    true,
  );
  assertEquals(
    isRecentSignupCreatedAt("2026-06-29T00:00:00.000Z", now),
    false,
  );
  assertEquals(isRecentSignupCreatedAt("not-a-date", now), false);
});

Deno.test("buildSignupSlackPayload avoids email and formats first-user alert", () => {
  const payload = buildSignupSlackPayload({
    totalUsers: 38,
    signalKey: "signup_submit_referral",
    signupUserId: "12345678-1234-1234-1234-123456789012",
    createdAt: "2026-07-02T00:00:00.000Z",
    now: new Date("2026-07-02T00:02:00.000Z"),
  });

  const serialized = JSON.stringify(payload);
  assertEquals(
    payload.text,
    ":tada: New signup #38 registered (channel: referral)",
  );
  assertEquals(serialized.includes("@"), false);
  assertEquals(serialized.includes("12345678-1234"), false);
  assertEquals(payload.unfurl_links, false);
  assertEquals(payload.unfurl_media, false);
});
