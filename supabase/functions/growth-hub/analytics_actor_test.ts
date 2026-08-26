import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  analyticsActorHash,
  analyticsActorMaterial,
} from "./analytics_actor.ts";

Deno.test("authenticated analytics actors are keyed by user", async () => {
  const first = new Request("https://example.test", {
    headers: { "cf-connecting-ip": "203.0.113.1", "user-agent": "first" },
  });
  const second = new Request("https://example.test", {
    headers: { "cf-connecting-ip": "203.0.113.2", "user-agent": "second" },
  });

  assertEquals(
    await analyticsActorHash(first, "00000000-0000-4000-8000-000000004091"),
    await analyticsActorHash(second, "00000000-0000-4000-8000-000000004091"),
  );
});

Deno.test("anonymous analytics actors prefer the trusted edge address", async () => {
  const request = new Request("https://example.test", {
    headers: {
      "cf-connecting-ip": "203.0.113.9",
      "x-forwarded-for": "198.51.100.7, 10.0.0.1",
      "user-agent": "fixture-browser",
    },
  });

  assertEquals(
    analyticsActorMaterial(request, null),
    "anonymous:203.0.113.9",
  );
  assertMatch(await analyticsActorHash(request, null), /^[0-9a-f]{64}$/);
});
