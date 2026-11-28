import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildShopReturnUrls } from "./shop_urls.ts";

Deno.test("both Stripe returns preserve the same normalized campaign and post", () => {
  const urls = buildShopReturnUrls(
    "https://store.example.invalid",
    "hexciv-win64",
    {
      source: " X ",
      campaign: " H4_H7_Pitch ",
      content_id: " Post-A ",
    },
  );
  for (
    const [key, result] of [["successUrl", "success"], [
      "cancelUrl",
      "canceled",
    ]] as const
  ) {
    const url = new URL(urls[key]);
    assertEquals(url.origin, "https://store.example.invalid");
    assertEquals(url.pathname, "/shop/product");
    assertEquals(Object.fromEntries(url.searchParams), {
      product_id: "hexciv-win64",
      purchase: result,
      utm_source: "x",
      utm_campaign: "h4_h7_pitch",
      utm_content: "post-a",
    });
  }
});

Deno.test("legacy callers retain their existing exact URLs", () => {
  assertEquals(
    buildShopReturnUrls("https://store.example.invalid", "hexciv-win64"),
    {
      successUrl:
        "https://store.example.invalid/shop/product?product_id=hexciv-win64&purchase=success",
      cancelUrl:
        "https://store.example.invalid/shop/product?product_id=hexciv-win64&purchase=canceled",
    },
  );
});

Deno.test("invalid tags do not prevent the checkout return URL", () => {
  for (
    const payload of [
      { source: "x", campaign: "launch", content_id: "invalid/id" },
      { attribution_valid: false },
    ]
  ) {
    const urls = buildShopReturnUrls(
      "https://store.example.invalid",
      "hexciv-win64",
      payload,
    );
    for (
      const [key, result] of [["successUrl", "success"], [
        "cancelUrl",
        "canceled",
      ]] as const
    ) {
      const url = new URL(urls[key]);
      assertEquals(url.origin, "https://store.example.invalid");
      assertEquals(url.pathname, "/shop/product");
      assertEquals(Object.fromEntries(url.searchParams), {
        product_id: "hexciv-win64",
        purchase: result,
        shop_attribution: "unavailable",
      });
    }
  }
});

Deno.test("untrusted input cannot replace origin, product, price or purchase result", () => {
  const urls = buildShopReturnUrls(
    "https://store.example.invalid/base?secret=none",
    "a&b",
    {
      source: "x",
      campaign: "launch",
      content_id: "post-a",
      redirect: "https://evil.invalid",
      product_id: "another",
      purchase: "paid",
      user_id: "synthetic-user",
      amount: 1,
    },
  );
  const url = new URL(urls.successUrl);
  assertEquals(url.origin, "https://store.example.invalid");
  assertEquals(Object.fromEntries(url.searchParams), {
    product_id: "a&b",
    purchase: "success",
    utm_source: "x",
    utm_campaign: "launch",
    utm_content: "post-a",
  });
});
