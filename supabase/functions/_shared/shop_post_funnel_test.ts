import {
  assert,
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  SHOP_POST_FUNNEL_CONFLICT,
  ShopPostFunnelInput,
  shopPostFunnelEvent,
  writeShopPostFunnelEvent,
} from "./shop_post_funnel.ts";

const input: ShopPostFunnelInput = {
  visitorId: "a1000000-0000-4000-8000-000000000001",
  productId: "hexciv-win64",
  stage: "product_view",
  attribution: { source: "x", campaign: "h4_h7_pitch", content_id: "post-a" },
};

Deno.test("the same visitor's separate posts and campaigns remain separate", () => {
  const a = shopPostFunnelEvent(input);
  const b = shopPostFunnelEvent({ ...input, attribution: {
    source: "x", campaign: "h4_h7_pitch", content_id: "post-b",
  } });
  const c = shopPostFunnelEvent({ ...input, attribution: {
    source: "x", campaign: "another-campaign", content_id: "post-a",
  } });
  assertNotEquals(a, b);
  assertNotEquals(a, c);
  assertEquals(a, shopPostFunnelEvent(input));
  assertEquals(SHOP_POST_FUNNEL_CONFLICT,
    "visitor_id,product_id,source,campaign,content_id,stage");
});

Deno.test("legacy missing tags stay empty and do not invent a post", () => {
  assertEquals(shopPostFunnelEvent({ ...input, attribution: {} }), {
    visitor_id: input.visitorId,
    product_id: input.productId,
    stage: "product_view",
    source: "direct",
    campaign: "",
    content_id: "",
  });
});

Deno.test("the caller stage is not overridden by client stage or account fields", () => {
  const row = shopPostFunnelEvent({ ...input, attribution: {
    source: "x", campaign: "launch", content_id: "post-a",
    stage: "purchase_complete", auth_user_id: "synthetic-user", price: 1,
  } });
  assertEquals(row, {
    visitor_id: input.visitorId, product_id: input.productId,
    stage: "product_view", source: "x", campaign: "launch", content_id: "post-a",
  });
});

Deno.test("missing identity or invalid tags skip attribution without a write", async () => {
  let calls = 0;
  const write = () => { calls++; return Promise.resolve({ error: null }); };
  for (const invalid of [
    { ...input, visitorId: "" },
    { ...input, visitorId: "not-a-uuid" },
    { ...input, productId: " " },
    { ...input, attribution: { content_id: "too long ".repeat(10) } },
  ]) {
    assertEquals(await writeShopPostFunnelEvent(write, invalid), false);
  }
  assertEquals(calls, 0);
});

Deno.test("writer uses the six-column key, ignores repeats, and bounds transport", async () => {
  let calls = 0;
  assertEquals(await writeShopPostFunnelEvent((row, options, signal) => {
    calls++;
    assertEquals(row, shopPostFunnelEvent(input));
    assertEquals(options, {
      onConflict: SHOP_POST_FUNNEL_CONFLICT, ignoreDuplicates: true,
    });
    assert(signal instanceof AbortSignal);
    return Promise.resolve({ error: null });
  }, input), true);
  assertEquals(calls, 1);
});

Deno.test("missing-schema errors are reported as gaps, not thrown into payment", async () => {
  const result = await writeShopPostFunnelEvent(
    () => Promise.resolve({ error: { code: "42P01" } }), input,
  );
  assertEquals(result, false);
});

Deno.test("transport rejection is isolated from the caller", async () => {
  assertEquals(await writeShopPostFunnelEvent(
    () => Promise.reject(new Error("synthetic network fault")), input,
  ), false);
});

Deno.test("a stalled transport actually receives abort and settles as a gap", async () => {
  let aborted = false;
  // A bounded referenced timer also keeps this no-I/O test alive on runtimes
  // whose AbortSignal timeout timer is unreferenced. Missing abort must fail,
  // not leave an unresolved promise forever or disable test sanitizers.
  let deadline = 0;
  const tooSlow = new Promise<boolean>((_resolve, reject) => {
    deadline = setTimeout(() => reject(new Error("abort was not delivered")), 10000);
  });
  const pending = writeShopPostFunnelEvent((_row, _options, signal) => {
    return new Promise<{ error: unknown }>((_resolve, reject) => {
      signal.addEventListener("abort", () => {
        aborted = true;
        reject(signal.reason);
      }, { once: true });
    });
  }, input);
  try {
    assertEquals(await Promise.race([pending, tooSlow]), false);
    assertEquals(aborted, true);
  } finally {
    clearTimeout(deadline);
  }
});

Deno.test("synchronous transport exception is also isolated", async () => {
  assertEquals(await writeShopPostFunnelEvent(() => {
    throw new Error("synthetic client fault");
  }, input), false);
});
