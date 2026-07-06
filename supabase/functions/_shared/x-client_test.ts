import {
  assertEquals,
  assertFalse,
  assertObjectMatch,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMediaAltTextBody,
  buildTweetPayload,
  buildXApiErrorPayload,
} from "./x-client.ts";

Deno.test("buildXApiErrorPayload classifies client-not-enrolled", () => {
  const payload = buildXApiErrorPayload(403, {
    detail:
      "When authenticating requests to the Twitter API v2 endpoints, you must use keys and tokens from a Twitter developer App that is attached to a Project.",
    registration_url: "https://developer.twitter.com/en/docs/projects/overview",
    title: "Client Forbidden",
    required_enrollment: "Appropriate Level of API Access",
    reason: "client-not-enrolled",
  }, "");

  assertEquals(payload.code, "x_client_not_enrolled");
  assertEquals(payload.status, 403);
  assertEquals(payload.reason, "client-not-enrolled");
  assertStringIncludes(payload.actionRequired, "attach the App");
  assertStringIncludes(payload.actionRequired, "Read and write permissions");
});

Deno.test("buildMediaAltTextBody builds media/metadata/create JSON body", () => {
  const body = buildMediaAltTextBody(
    "1234567890",
    "自分株式会社の共有カード画像",
  );

  assertEquals(body, {
    media_id: "1234567890",
    alt_text: { text: "自分株式会社の共有カード画像" },
  });
  // JSON.stringify で送る形も検証 (= media_id / alt_text.text のキー構造)。
  assertEquals(
    JSON.stringify(body),
    '{"media_id":"1234567890","alt_text":{"text":"自分株式会社の共有カード画像"}}',
  );
});

Deno.test("buildMediaAltTextBody caps alt_text at 1000 chars", () => {
  const longText = "あ".repeat(1500);
  const body = buildMediaAltTextBody("42", longText);

  assertEquals(body.media_id, "42");
  assertEquals(body.alt_text.text.length, 1000);
  assertEquals(body.alt_text.text, "あ".repeat(1000));
});

Deno.test("buildTweetPayload without poll is byte-identical to plain text", () => {
  const payload = buildTweetPayload({ text: "hello" });
  assertEquals(payload, { text: "hello" });
  assertFalse("poll" in payload);
});

Deno.test("buildTweetPayload attaches poll when 2+ options are present", () => {
  const payload = buildTweetPayload({
    text: "どっちが好き?",
    poll: { options: ["きのこ", "たけのこ"], durationMinutes: 1440 },
  });
  assertObjectMatch(payload, {
    text: "どっちが好き?",
    poll: { options: ["きのこ", "たけのこ"], duration_minutes: 1440 },
  });
});

Deno.test("buildTweetPayload gates out polls with fewer than 2 usable options", () => {
  const single = buildTweetPayload({
    text: "poll?",
    poll: { options: ["only one"], durationMinutes: 1440 },
  });
  assertFalse("poll" in single);

  // Empty / whitespace options are dropped, so this collapses to <2 options.
  const collapsed = buildTweetPayload({
    text: "poll?",
    poll: { options: ["ok", "", "   "], durationMinutes: 1440 },
  });
  assertFalse("poll" in collapsed);

  const none = buildTweetPayload({
    text: "poll?",
    poll: { options: [], durationMinutes: 1440 },
  });
  assertFalse("poll" in none);
});

Deno.test("buildTweetPayload rejects poll + media on the same tweet", () => {
  assertThrows(
    () =>
      buildTweetPayload({
        text: "lead with media",
        mediaIds: ["media_123"],
        poll: { options: ["a", "b"], durationMinutes: 1440 },
      }),
    Error,
    "poll and media cannot coexist on one tweet",
  );
});

Deno.test("buildTweetPayload clamps poll duration and caps options at 4", () => {
  const tooShort = buildTweetPayload({
    text: "p",
    poll: { options: ["a", "b"], durationMinutes: 1 },
  });
  assertEquals(
    (tooShort.poll as { duration_minutes: number }).duration_minutes,
    5,
  );

  const tooLong = buildTweetPayload({
    text: "p",
    poll: { options: ["a", "b"], durationMinutes: 99999 },
  });
  assertEquals(
    (tooLong.poll as { duration_minutes: number }).duration_minutes,
    10080,
  );

  const zeroDefaults = buildTweetPayload({
    text: "p",
    poll: { options: ["a", "b"], durationMinutes: 0 },
  });
  assertEquals(
    (zeroDefaults.poll as { duration_minutes: number }).duration_minutes,
    1440,
  );

  const fiveOptions = buildTweetPayload({
    text: "p",
    poll: { options: ["a", "b", "c", "d", "e"], durationMinutes: 1440 },
  });
  assertEquals((fiveOptions.poll as { options: string[] }).options, [
    "a",
    "b",
    "c",
    "d",
  ]);
});
