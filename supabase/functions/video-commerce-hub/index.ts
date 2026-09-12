import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  isUuid,
  safeErrorCode,
  sha256Hex,
  validatePublicationPacket,
} from "./publication.ts";

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SUPABASE_ANON_KEY = (Deno.env.get("SUPABASE_ANON_KEY") ?? "").trim();
const SERVICE_ROLE_KEY = (
  Deno.env.get("SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
).trim();
const STRIPE_SECRET_KEY = (Deno.env.get("STRIPE_SECRET_KEY") ?? "").trim();
const SITE_URL = (Deno.env.get("SHOP_SITE_URL") ??
  "https://my-web-app-b67f4.web.app").replace(/\/+$/, "");
const STRIPE_API_VERSION = "2026-06-24.dahlia";
const SOURCE_BUCKET = "video-generations";
const DELIVERY_BUCKET = "product-downloads";
const MAX_VIDEO_BYTES = 52_428_800;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  let claimed: { userId: string; authorizationId: string } | null = null;
  let finalized = false;
  let rolledBack = false;
  let stripeProductId = "";
  try {
    assertConfiguration();
    const body = asRecord(await req.json().catch(() => ({})));
    const action = asString(body.action);
    const userId = await authorizedUserId(req, body);
    if (!userId) return json({ error: "unauthorized" }, 401);
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    switch (action) {
      case "publication_status":
        return await publicationStatus(admin, userId, body);
      case "authorize_publication":
        return await authorizePublication(admin, userId, body);
      case "publish_authorized": {
        const authorizationId = asString(body.authorization_id);
        if (!isUuid(authorizationId)) {
          return json({ error: "invalid_publication_authorization_id" }, 400);
        }
        claimed = { userId, authorizationId };
        const result = await publishAuthorized(
          admin,
          userId,
          authorizationId,
          (state) => {
            finalized = state.finalized;
            rolledBack = state.rolledBack;
            stripeProductId = state.stripeProductId;
          },
        );
        return json(result);
      }
      case "rollback_publication":
        return await rollbackPublication(admin, userId, body);
      default:
        return json({ error: "unknown_action" }, 400);
    }
  } catch (error) {
    const code = safeErrorCode(error);
    console.error("[video-commerce-hub]", code);
    if (claimed && !rolledBack) {
      const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
      if (finalized) {
        await deactivateStripeProduct(stripeProductId).catch((rollbackError) =>
          console.error(
            "[video-commerce-hub] stripe rollback",
            safeErrorCode(rollbackError),
          )
        );
        await admin.rpc("video_rollback_publication", {
          p_user_id: claimed.userId,
          p_authorization_id: claimed.authorizationId,
          p_error_code: code,
        }).catch((rollbackError) =>
          console.error(
            "[video-commerce-hub] database rollback",
            safeErrorCode(rollbackError),
          )
        );
      } else {
        await admin.rpc("video_release_publication_authorization", {
          p_user_id: claimed.userId,
          p_authorization_id: claimed.authorizationId,
          p_error_code: code,
        }).catch((releaseError) =>
          console.error(
            "[video-commerce-hub] lease release",
            safeErrorCode(releaseError),
          )
        );
      }
    }
    const known = knownError(code);
    return json({ error: code }, known ?? 500);
  }
});

async function publicationStatus(
  admin: SupabaseClient,
  userId: string,
  body: JsonRecord,
): Promise<Response> {
  let query = admin.from("video_publication_authorizations").select(
    "id,status,valid_from,valid_until,artifact_id,review_id,product_id,title,price_jpy,currency,territory,license_summary,publication_channel,rollback_action,stripe_product_id,stripe_price_id,delivery_storage_bucket,delivery_storage_path,delivery_file_size_bytes,delivery_sha256,attempt_count,last_error_code,published_at,rolled_back_at,created_at,updated_at",
  ).eq("user_id", userId).order("created_at", { ascending: false }).limit(20);
  const authorizationId = asString(body.authorization_id);
  if (authorizationId) {
    if (!isUuid(authorizationId)) {
      return json({ error: "invalid_publication_authorization_id" }, 400);
    }
    query = query.eq("id", authorizationId);
  }
  const { data, error } = await query;
  if (error) throw error;
  const now = Date.now();
  const authorizations = (data ?? []).map((row) => ({
    ...row,
    status: row.status === "active" && Date.parse(row.valid_until) <= now
      ? "expired"
      : row.status,
  }));
  return json({ success: true, authorizations });
}

async function authorizePublication(
  admin: SupabaseClient,
  userId: string,
  body: JsonRecord,
): Promise<Response> {
  const validation = validatePublicationPacket(body);
  if (!validation.ok) return json({ error: validation.code }, 400);
  const value = validation.value;
  const validUntil = new Date(
    Date.now() + value.validityHours * 60 * 60 * 1000,
  ).toISOString();
  const { data, error } = await admin.rpc(
    "video_register_publication_authorization",
    {
      p_user_id: userId,
      p_artifact_id: value.artifactId,
      p_review_id: value.reviewId,
      p_valid_until: validUntil,
      p_product_id: value.productId,
      p_title: value.title,
      p_summary: value.summary,
      p_description: value.description,
      p_price_jpy: value.priceJpy,
      p_license_summary: value.licenseSummary,
      p_rights_confirmed: true,
      p_privacy_confirmed: true,
      p_fictional_person_confirmed: true,
      p_no_third_party_logos_confirmed: true,
      p_no_unlicensed_material_confirmed: true,
    },
  );
  if (error) throw error;
  return json({ success: true, ...asRecord(data) }, 201);
}

async function publishAuthorized(
  admin: SupabaseClient,
  userId: string,
  authorizationId: string,
  reportState: (state: {
    finalized: boolean;
    rolledBack: boolean;
    stripeProductId: string;
  }) => void,
): Promise<JsonRecord> {
  if (!STRIPE_SECRET_KEY) throw new Error("stripe_secret_key_not_configured");
  const { data: claimData, error: claimError } = await admin.rpc(
    "video_claim_publication_authorization",
    { p_user_id: userId, p_authorization_id: authorizationId },
  );
  if (claimError) throw claimError;
  let authorization = asRecord(asRecord(claimData).authorization);
  if (asString(authorization.status) === "expired") {
    throw new Error("video_publication_authorization_expired");
  }
  if (asString(authorization.status) === "published") {
    reportState({
      finalized: true,
      rolledBack: false,
      stripeProductId: asString(authorization.stripe_product_id),
    });
    await verifyPublishedState(admin, authorization);
    return {
      success: true,
      idempotent_replay: true,
      authorization: publicAuthorization(authorization),
      product_url: productUrl(asString(authorization.product_id)),
    };
  }

  const artifactId = asString(authorization.artifact_id);
  const reviewId = asString(authorization.review_id);
  const { data: artifact, error: artifactError } = await admin
    .from("video_artifacts")
    .select(
      "id,user_id,latest_review_id,storage_bucket,storage_path,file_size_bytes,sha256,rights_status,privacy_status,intended_for_sale,commerce_status",
    )
    .eq("id", artifactId)
    .eq("user_id", userId)
    .maybeSingle();
  if (artifactError) throw artifactError;
  if (!artifact) throw new Error("video_artifact_not_found");
  const { data: review, error: reviewError } = await admin
    .from("video_artifact_reviews")
    .select("id,artifact_id,user_id,decision")
    .eq("id", reviewId)
    .eq("artifact_id", artifactId)
    .eq("user_id", userId)
    .maybeSingle();
  if (reviewError) throw reviewError;
  if (
    !review || artifact.latest_review_id !== reviewId ||
    review.decision !== "keep" || artifact.rights_status !== "allowed" ||
    artifact.privacy_status !== "cleared" ||
    artifact.intended_for_sale !== true ||
    ["not_for_sale", "blocked"].includes(artifact.commerce_status)
  ) {
    throw new Error("artifact_not_cleared_for_publication");
  }
  if (artifact.storage_bucket !== SOURCE_BUCKET) {
    throw new Error("invalid_video_source_bucket");
  }

  const { data: source, error: sourceError } = await admin.storage
    .from(SOURCE_BUCKET).download(artifact.storage_path);
  if (sourceError || !source) throw new Error("video_source_download_failed");
  if (source.size < 1 || source.size > MAX_VIDEO_BYTES) {
    throw new Error("video_source_size_invalid");
  }
  const digest = await sha256Hex(source);
  if (artifact.sha256 && artifact.sha256 !== digest) {
    throw new Error("video_source_sha256_mismatch");
  }
  if (artifact.file_size_bytes && artifact.file_size_bytes !== source.size) {
    throw new Error("video_source_size_mismatch");
  }
  const { error: artifactMetadataError } = await admin.from("video_artifacts")
    .update({ file_size_bytes: source.size, sha256: digest })
    .eq("id", artifactId).eq("user_id", userId);
  if (artifactMetadataError) throw artifactMetadataError;

  const productId = asString(authorization.product_id);
  const deliveryPath = `video/${productId}/${digest}.mp4`;
  await putVerifiedDeliveryObject(admin, deliveryPath, source, digest);

  const stripeProduct = await ensureStripeProduct(authorization);
  const stripePrice = await ensureStripePrice(authorization, stripeProduct.id);
  reportState({
    finalized: false,
    rolledBack: false,
    stripeProductId: stripeProduct.id,
  });

  const { data: staged, error: stageError } = await admin.rpc(
    "video_stage_publication_product",
    {
      p_user_id: userId,
      p_authorization_id: authorizationId,
      p_stripe_product_id: stripeProduct.id,
      p_stripe_price_id: stripePrice.id,
      p_storage_path: deliveryPath,
      p_file_size_bytes: source.size,
      p_sha256: digest,
    },
  );
  if (stageError) throw stageError;
  authorization = asRecord(staged);

  await verifyStagedState(
    admin,
    authorization,
    stripeProduct.id,
    stripePrice.id,
    deliveryPath,
    source.size,
    digest,
  );
  const { data: finalizedData, error: finalizeError } = await admin.rpc(
    "video_finalize_publication",
    { p_user_id: userId, p_authorization_id: authorizationId },
  );
  if (finalizeError) throw finalizeError;
  authorization = asRecord(finalizedData);
  reportState({
    finalized: true,
    rolledBack: false,
    stripeProductId: stripeProduct.id,
  });

  try {
    await verifyPublishedState(admin, authorization);
  } catch (error) {
    await deactivateStripeProduct(stripeProduct.id).catch(() => undefined);
    const { error: rollbackError } = await admin.rpc(
      "video_rollback_publication",
      {
        p_user_id: userId,
        p_authorization_id: authorizationId,
        p_error_code: safeErrorCode(error),
      },
    );
    if (rollbackError) throw rollbackError;
    reportState({
      finalized: true,
      rolledBack: true,
      stripeProductId: stripeProduct.id,
    });
    throw error;
  }

  return {
    success: true,
    idempotent_replay: false,
    authorization: publicAuthorization(authorization),
    product_url: productUrl(productId),
  };
}

async function rollbackPublication(
  admin: SupabaseClient,
  userId: string,
  body: JsonRecord,
): Promise<Response> {
  const authorizationId = asString(body.authorization_id);
  if (!isUuid(authorizationId)) {
    return json({ error: "invalid_publication_authorization_id" }, 400);
  }
  const { data: row, error: loadError } = await admin
    .from("video_publication_authorizations")
    .select("id,user_id,status,stripe_product_id")
    .eq("id", authorizationId).eq("user_id", userId).maybeSingle();
  if (loadError) throw loadError;
  if (!row) {
    return json({ error: "video_publication_authorization_not_found" }, 404);
  }
  if (row.status === "rolled_back") {
    return json({ success: true, idempotent_replay: true });
  }
  await deactivateStripeProduct(asString(row.stripe_product_id));
  const { data, error } = await admin.rpc("video_rollback_publication", {
    p_user_id: userId,
    p_authorization_id: authorizationId,
    p_error_code: "owner_requested_rollback",
  });
  if (error) throw error;
  return json({
    success: true,
    authorization: publicAuthorization(asRecord(data)),
  });
}

async function putVerifiedDeliveryObject(
  admin: SupabaseClient,
  path: string,
  source: Blob,
  expectedSha256: string,
): Promise<void> {
  const { error: uploadError } = await admin.storage.from(DELIVERY_BUCKET)
    .upload(path, source, {
      contentType: "video/mp4",
      cacheControl: "3600",
      upsert: false,
    });
  if (uploadError) {
    const { data: existing, error: downloadError } = await admin.storage
      .from(DELIVERY_BUCKET).download(path);
    if (downloadError || !existing) throw uploadError;
    if (
      existing.size !== source.size ||
      await sha256Hex(existing) !== expectedSha256
    ) {
      throw new Error("delivery_object_conflict");
    }
  }
}

async function ensureStripeProduct(
  authorization: JsonRecord,
): Promise<{ id: string }> {
  const existingId = asString(authorization.stripe_product_id);
  const product = existingId
    ? await stripeGet(`/products/${encodeURIComponent(existingId)}`)
    : await stripePostForm(
      "/products",
      {
        name: asString(authorization.title),
        description: asString(authorization.description),
        "metadata[video_publication_authorization]": asString(authorization.id),
        "metadata[video_artifact_id]": asString(authorization.artifact_id),
        "metadata[shop_product_id]": asString(authorization.product_id),
      },
      `video-pub-product-${asString(authorization.id)}`,
    );
  const id = asString(product.id);
  const metadata = asRecord(product.metadata);
  if (
    !/^prod_[A-Za-z0-9]+$/.test(id) || product.active !== true ||
    asString(metadata.video_publication_authorization) !==
      asString(authorization.id) ||
    asString(metadata.video_artifact_id) !==
      asString(authorization.artifact_id) ||
    asString(metadata.shop_product_id) !== asString(authorization.product_id)
  ) {
    throw new Error("stripe_product_verification_failed");
  }
  return { id };
}

async function ensureStripePrice(
  authorization: JsonRecord,
  stripeProductId: string,
): Promise<{ id: string }> {
  const existingId = asString(authorization.stripe_price_id);
  const price = existingId
    ? await stripeGet(`/prices/${encodeURIComponent(existingId)}`)
    : await stripePostForm(
      "/prices",
      {
        product: stripeProductId,
        currency: "jpy",
        unit_amount: String(asInteger(authorization.price_jpy)),
        "metadata[video_publication_authorization]": asString(authorization.id),
        "metadata[shop_product_id]": asString(authorization.product_id),
      },
      `video-pub-price-${asString(authorization.id)}`,
    );
  const id = asString(price.id);
  const metadata = asRecord(price.metadata);
  if (
    !/^price_[A-Za-z0-9]+$/.test(id) || price.active !== true ||
    asString(price.product) !== stripeProductId ||
    asString(price.currency).toLowerCase() !== "jpy" ||
    asInteger(price.unit_amount) !== asInteger(authorization.price_jpy) ||
    asString(metadata.video_publication_authorization) !==
      asString(authorization.id) ||
    asString(metadata.shop_product_id) !== asString(authorization.product_id)
  ) {
    throw new Error("stripe_price_verification_failed");
  }
  return { id };
}

async function verifyStagedState(
  admin: SupabaseClient,
  authorization: JsonRecord,
  stripeProductId: string,
  stripePriceId: string,
  deliveryPath: string,
  expectedSize: number,
  expectedSha256: string,
): Promise<void> {
  const { data: product, error } = await admin.from("shop_products").select(
    "id,price_jpy,stripe_price_id,storage_bucket,storage_path,file_size_bytes,sha256,is_active,product_type",
  ).eq("id", asString(authorization.product_id)).maybeSingle();
  if (error) throw error;
  if (
    !product || product.is_active !== false ||
    product.product_type !== "video" ||
    product.price_jpy !== asInteger(authorization.price_jpy) ||
    product.stripe_price_id !== stripePriceId ||
    product.storage_bucket !== DELIVERY_BUCKET ||
    product.storage_path !== deliveryPath ||
    product.file_size_bytes !== expectedSize ||
    product.sha256 !== expectedSha256
  ) {
    throw new Error("staged_product_verification_failed");
  }
  const { data: delivered, error: deliveryError } = await admin.storage
    .from(DELIVERY_BUCKET).download(deliveryPath);
  if (
    deliveryError || !delivered || delivered.size !== expectedSize ||
    await sha256Hex(delivered) !== expectedSha256
  ) {
    throw new Error("delivery_object_verification_failed");
  }
  await ensureStripeProduct({
    ...authorization,
    stripe_product_id: stripeProductId,
  });
  await ensureStripePrice(
    { ...authorization, stripe_price_id: stripePriceId },
    stripeProductId,
  );
}

async function verifyPublishedState(
  admin: SupabaseClient,
  authorization: JsonRecord,
): Promise<void> {
  const productId = asString(authorization.product_id);
  const { data: privateProduct, error: privateError } = await admin
    .from("shop_products")
    .select(
      "id,is_active,price_jpy,stripe_price_id,storage_bucket,storage_path,sha256",
    )
    .eq("id", productId).maybeSingle();
  if (privateError) throw privateError;
  if (
    !privateProduct || privateProduct.is_active !== true ||
    privateProduct.price_jpy !== asInteger(authorization.price_jpy) ||
    privateProduct.stripe_price_id !==
      asString(authorization.stripe_price_id) ||
    privateProduct.storage_bucket !== DELIVERY_BUCKET ||
    privateProduct.storage_path !==
      asString(authorization.delivery_storage_path) ||
    privateProduct.sha256 !== asString(authorization.delivery_sha256)
  ) {
    throw new Error("published_product_verification_failed");
  }
  const anonymous = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: publicProduct, error: publicError } = await anonymous
    .from("shop_products").select("id,price_jpy,is_active")
    .eq("id", productId).maybeSingle();
  if (
    publicError || !publicProduct || publicProduct.is_active !== true ||
    publicProduct.price_jpy !== asInteger(authorization.price_jpy)
  ) {
    throw new Error("public_catalog_verification_failed");
  }
  if (asString(authorization.stripe_product_id)) {
    await ensureStripeProduct(authorization);
    await ensureStripePrice(
      authorization,
      asString(authorization.stripe_product_id),
    );
  }
  const response = await fetch(productUrl(productId), {
    method: "GET",
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) throw new Error("shop_product_page_verification_failed");
}

async function deactivateStripeProduct(productId: string): Promise<void> {
  if (!productId) return;
  const product = await stripePostForm(
    `/products/${encodeURIComponent(productId)}`,
    { active: "false" },
    `video-pub-rollback-${productId}`,
  );
  if (product.active !== false) {
    throw new Error("stripe_product_rollback_failed");
  }
}

async function stripeGet(path: string): Promise<JsonRecord> {
  if (!STRIPE_SECRET_KEY) throw new Error("stripe_secret_key_not_configured");
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      "Stripe-Version": STRIPE_API_VERSION,
    },
  });
  const data = asRecord(await response.json().catch(() => ({})));
  if (!response.ok) throw new Error(stripeError(data, response.status));
  return data;
}

async function stripePostForm(
  path: string,
  params: Record<string, string>,
  idempotencyKey: string,
): Promise<JsonRecord> {
  if (!STRIPE_SECRET_KEY) throw new Error("stripe_secret_key_not_configured");
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Stripe-Version": STRIPE_API_VERSION,
      "Idempotency-Key": idempotencyKey,
    },
    body: new URLSearchParams(params),
  });
  const data = asRecord(await response.json().catch(() => ({})));
  if (!response.ok) throw new Error(stripeError(data, response.status));
  return data;
}

function stripeError(data: JsonRecord, status: number): string {
  const error = asRecord(data.error);
  const type = asString(error.type);
  return safeErrorCode(type || `stripe_api_${status}`);
}

async function authorizedUserId(
  req: Request,
  body: JsonRecord,
): Promise<string | null> {
  const authorization = req.headers.get("Authorization") ?? "";
  if (
    SERVICE_ROLE_KEY && authorization === `Bearer ${SERVICE_ROLE_KEY}`
  ) {
    const userId = asString(body.user_id);
    return isUuid(userId) ? userId : null;
  }
  if (!authorization) return null;
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user || data.user.is_anonymous === true) return null;
  return data.user.id;
}

function publicAuthorization(value: JsonRecord): JsonRecord {
  return {
    id: value.id,
    status: value.status,
    valid_until: value.valid_until,
    artifact_id: value.artifact_id,
    review_id: value.review_id,
    product_id: value.product_id,
    title: value.title,
    price_jpy: value.price_jpy,
    currency: value.currency,
    territory: value.territory,
    publication_channel: value.publication_channel,
    stripe_product_id: value.stripe_product_id,
    stripe_price_id: value.stripe_price_id,
    delivery_storage_bucket: value.delivery_storage_bucket,
    delivery_storage_path: value.delivery_storage_path,
    delivery_file_size_bytes: value.delivery_file_size_bytes,
    delivery_sha256: value.delivery_sha256,
    attempt_count: value.attempt_count,
    last_error_code: value.last_error_code,
    published_at: value.published_at,
    rolled_back_at: value.rolled_back_at,
  };
}

function productUrl(productId: string): string {
  return `${SITE_URL}/shop/product?product_id=${encodeURIComponent(productId)}`;
}

function asRecord(value: unknown): JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asInteger(value: unknown): number {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^\d+$/.test(value.trim())) {
    return Number(value);
  }
  return 0;
}

function assertConfiguration(): void {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SERVICE_ROLE_KEY) {
    throw new Error("supabase_configuration_missing");
  }
}

function knownError(code: string): number | null {
  if (code.includes("not_found")) return 404;
  if (code.includes("unauthorized")) return 401;
  if (
    code.includes("invalid") || code.includes("required") ||
    code.includes("unsupported") || code.includes("confirmations")
  ) return 400;
  if (
    code.includes("inactive") || code.includes("expired") ||
    code.includes("conflict") || code.includes("not_cleared") ||
    code.includes("already_in_progress") || code.includes("not_latest") ||
    code.includes("must_be_keep")
  ) return 409;
  return null;
}
