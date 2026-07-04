import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildMediaAltTextBody, buildXApiErrorPayload } from "./x-client.ts";

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
  const body = buildMediaAltTextBody("1234567890", "自分株式会社の共有カード画像");

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
