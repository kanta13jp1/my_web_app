import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { buildShopReturnUrls } from "./shop_urls.ts";

Deno.test("shop return URLs preserve the product and purchase result", () => {
  const urls = buildShopReturnUrls(
    "https://example.com/ignored/path",
    "prompt starter / 日本語",
  );

  const success = new URL(urls.successUrl);
  const canceled = new URL(urls.cancelUrl);
  assertEquals(success.origin, "https://example.com");
  assertEquals(success.pathname, "/shop/product");
  assertEquals(
    success.searchParams.get("product_id"),
    "prompt starter / 日本語",
  );
  assertEquals(success.searchParams.get("purchase"), "success");
  assertEquals(canceled.searchParams.get("purchase"), "canceled");
});

Deno.test("shop return URLs reject a blank product id", () => {
  assertThrows(
    () => buildShopReturnUrls("https://example.com", "   "),
    Error,
    "product_id is required",
  );
});
