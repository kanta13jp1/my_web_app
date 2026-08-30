export interface ShopReturnUrls {
  successUrl: string;
  cancelUrl: string;
}

/// Stripeから戻るURLを商品単位で作る。product_idはURLSearchParamsに任せ、
/// 手作業の文字列連結でクエリを壊さない。
export function buildShopReturnUrls(
  siteUrl: string,
  productId: string,
): ShopReturnUrls {
  const id = productId.trim();
  if (!id) throw new Error("product_id is required");

  const base = new URL(siteUrl);
  const build = (result: "success" | "canceled") => {
    const url = new URL("/shop/product", base);
    url.searchParams.set("product_id", id);
    url.searchParams.set("purchase", result);
    return url.toString();
  };

  return {
    successUrl: build("success"),
    cancelUrl: build("canceled"),
  };
}
