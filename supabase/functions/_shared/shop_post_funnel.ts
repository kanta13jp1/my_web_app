import { shopAttributionFromClient } from "./shop_attribution.ts";

export type ShopFunnelStage =
  | "product_view"
  | "purchase_click"
  | "checkout_redirect"
  | "purchase_complete";

export type ShopPostFunnelEvent = {
  visitor_id: string;
  product_id: string;
  source: string;
  campaign: string;
  content_id: string;
  stage: ShopFunnelStage;
};

export type ShopPostFunnelInput = {
  visitorId: string;
  productId: string;
  stage: ShopFunnelStage;
  attribution: unknown;
};

export const SHOP_POST_FUNNEL_CONFLICT =
  "visitor_id,product_id,source,campaign,content_id,stage";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STAGES = new Set<ShopFunnelStage>([
  "product_view",
  "purchase_click",
  "checkout_redirect",
  "purchase_complete",
]);

/** Callers, not tags, determine the stage; paid completion is server-only. */
export function shopPostFunnelEvent(
  input: ShopPostFunnelInput,
): ShopPostFunnelEvent | null {
  const attribution = shopAttributionFromClient(input.attribution);
  const visitorId = input.visitorId.trim().toLowerCase();
  const productId = input.productId.trim();
  if (!attribution || !UUID.test(visitorId) || !productId) return null;
  if (!STAGES.has(input.stage)) return null;
  return {
    visitor_id: visitorId,
    product_id: productId,
    source: attribution.source,
    campaign: attribution.campaign,
    content_id: attribution.contentId,
    stage: input.stage,
  };
}

type WritePostEvent = (
  row: ShopPostFunnelEvent,
  options: { onConflict: string; ignoreDuplicates: true },
  signal: AbortSignal,
) => PromiseLike<{ error: unknown }>;

/**
 * Separate telemetry from purchase rights. No row update on repeat visits.
 * The transport must use the provided abort signal, as both handlers do.
 * Return false on missing schema, invalid input or network failure so callers
 * can expose a measurement gap without rejecting a paid purchase.
 */
export async function writeShopPostFunnelEvent(
  write: WritePostEvent,
  input: ShopPostFunnelInput,
): Promise<boolean> {
  const row = shopPostFunnelEvent(input);
  if (!row) return false;
  try {
    const { error } = await write(row, {
      onConflict: SHOP_POST_FUNNEL_CONFLICT,
      ignoreDuplicates: true,
    }, AbortSignal.timeout(1500));
    return !error;
  } catch (_) {
    return false;
  }
}
