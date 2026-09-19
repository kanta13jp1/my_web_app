import { shopAttributionQuery } from "../_shared/shop_attribution.ts";

export interface ShopReturnUrls {
  successUrl: string;
  cancelUrl: string;
}

/// Stripeから戻るURLを商品単位で作る。product_idはURLSearchParamsに任せ、
/// 手作業の文字列連結でクエリを壊さない。
export function buildShopReturnUrls(
  siteUrl: string,
  productId: string,
  attributionPayload?: unknown,
): ShopReturnUrls {
  const id = productId.trim();
  if (!id) throw new Error("product_id is required");

  const base = new URL(siteUrl);
  const build = (result: "success" | "canceled") => {
    const url = new URL("/shop/product", base);
    url.searchParams.set("product_id", id);
    url.searchParams.set("purchase", result);
    // No arbitrary return URL, account ID, or client-controlled price copied.
    const tags = attributionPayload === undefined
      ? null
      : shopAttributionQuery(attributionPayload);
    if (attributionPayload !== undefined && tags === null) {
      // Do not reclassify suppressed/invalid attribution as direct on return.
      url.searchParams.set("shop_attribution", "unavailable");
    }
    for (const [key, value] of Object.entries(tags ?? {})) {
      url.searchParams.set(key, value);
    }
    return url.toString();
  };

  return {
    successUrl: build("success"),
    cancelUrl: build("canceled"),
  };
}
