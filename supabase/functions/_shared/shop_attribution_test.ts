import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  shopAttributionFromClient,
  shopAttributionFromMetadata,
  shopAttributionMetadata,
  shopAttributionQuery,
} from "./shop_attribution.ts";

const first = {
  source: "x",
  campaign: "h4_h7_pitch",
  content_id: "growth_game_t30_r1",
};

Deno.test("unavailable URL attribution is not recounted as direct", () => {
  for (const flag of [false, null, 0, "true", "false", [], {}]) {
    const payload = { ...first, attribution_valid: flag };
    assertEquals(shopAttributionFromClient(payload), null);
    assertEquals(shopAttributionMetadata(payload), null);
    assertEquals(shopAttributionQuery(payload), null);
  }
  assertEquals(
    shopAttributionFromClient({ ...first, attribution_valid: true }),
    shopAttributionFromClient(first),
  );
});

Deno.test("shop campaign and post survive the metadata round trip", () => {
  assertEquals(shopAttributionFromMetadata(shopAttributionMetadata(first)), {
    source: "x",
    campaign: "h4_h7_pitch",
    contentId: "growth_game_t30_r1",
  });
});

Deno.test("different registered posts stay distinct", () => {
  const second = { ...first, content_id: "historical_ai_t80_r1" };
  assertNotEquals(shopAttributionMetadata(first), shopAttributionMetadata(second));
  assertEquals(shopAttributionQuery(second), {
    utm_source: "x",
    utm_campaign: "h4_h7_pitch",
    utm_content: "historical_ai_t80_r1",
  });
});

Deno.test("old metadata never invents a campaign or post", () => {
  assertEquals(shopAttributionFromMetadata({ shop_source: "itch_io" }), {
    source: "itch_io",
    campaign: "",
    contentId: "",
  });
  assertEquals(shopAttributionFromClient({}), {
    source: "direct",
    campaign: "",
    contentId: "",
  });
  assertEquals(shopAttributionQuery({}), { utm_source: "direct" });
});

Deno.test("ASCII tags have the same canonical form at each boundary", () => {
  const mixed = { source: " X ", campaign: " Launch-1 ", content_id: " Post.1 " };
  assertEquals(shopAttributionFromClient(mixed), {
    source: "x",
    campaign: "launch-1",
    contentId: "post.1",
  });
  assertEquals(
    shopAttributionFromMetadata(shopAttributionMetadata(mixed)),
    shopAttributionFromClient(mixed),
  );
});

Deno.test("invalid identifiers are rejected without substitution or truncation", () => {
  for (const bad of ["a".repeat(65), "a/b", "post id", "日本語", "x@test.example"]) {
    for (const field of ["source", "campaign", "content_id"]) {
      const payload = { ...first, [field]: bad };
      assertEquals(shopAttributionFromClient(payload), null);
      assertEquals(shopAttributionMetadata(payload), null);
      assertEquals(shopAttributionQuery(payload), null);
    }
  }
  assertEquals(shopAttributionFromClient({ content_id: "a".repeat(64) })?.contentId.length, 64);
});

Deno.test("non-string tags and non-object payloads cannot become identifiers", () => {
  for (const bad of [true, 1, [], {}]) {
    assertEquals(shopAttributionFromClient({ ...first, content_id: bad }), null);
    assertEquals(shopAttributionFromMetadata({ shop_content_id: bad }), null);
  }
  for (const bad of [null, undefined, "x", 1, []]) {
    assertEquals(shopAttributionFromClient(bad), null);
    assertEquals(shopAttributionFromMetadata(bad), null);
  }
});

Deno.test("only shop tags are copied; callers retain payment and auth responsibility", () => {
  const payload = {
    ...first,
    user_id: "not-a-real-user",
    price: "1",
    stage: "purchase_complete",
    redirect: "https://untrusted.invalid/",
    email: "synthetic@example.invalid",
  };
  assertEquals(shopAttributionMetadata(payload), {
    shop_source: "x",
    shop_campaign: "h4_h7_pitch",
    shop_content_id: "growth_game_t30_r1",
  });
  assertEquals(shopAttributionQuery(payload), shopAttributionQuery(first));
  assertEquals(payload.price, "1");
});

Deno.test("unrelated metadata is not treated as shop attribution", () => {
  assertEquals(shopAttributionFromMetadata({
    utm_source: "another-source",
    utm_campaign: "another-campaign",
    utm_content: "another-post",
  }), { source: "direct", campaign: "", contentId: "" });
});
