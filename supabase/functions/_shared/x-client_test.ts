import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildXApiErrorPayload } from "./x-client.ts";

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
