// 買い切り商品の Stripe Checkout セッションを作る Edge Function (2026-07-28)
//
// 役割はこれだけ:
//   1. 呼び出し元がログイン済みであることを確かめる
//   2. 商品が実際に販売可能な状態か (is_active / Price 設定済み) を確かめる
//   3. Stripe Checkout セッションを作って URL を返す
//
// 設計の要点:
//  * 金額はこの関数では**決めない**。Stripe 側の Price を参照するだけにする。
//    ここで amount を組み立てると、決済側と DB で価格の二重管理になり、
//    片方だけ変えたときに「表示 500円・請求 1000円」のような事故が起きる。
//  * metadata に user_id と商品IDを載せる。webhook はこれを見て購入行を作る。
//    metadata が無いと「誰が何を買ったか」を後から確定できない。
//  * 未ログインは弾く。購入とダウンロード権利を user_id に紐づける方式のため、
//    匿名で買われると権利の持ち主が決まらない。

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { buildShopReturnUrls } from "./shop_urls.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
// 決済後の戻り先。環境変数で差し替えられるようにして、本番URLを埋め込まない。
const SITE_URL = Deno.env.get("SHOP_SITE_URL") ??
  "https://my-web-app-b67f4.web.app";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value.trim() : fallback;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    if (!STRIPE_SECRET_KEY) {
      // 設定漏れを「買えないだけ」で終わらせず、原因が分かる形で返す。
      return json({ error: "STRIPE_SECRET_KEY not configured" }, 503);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Unauthorized" }, 401);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userError } = await userClient.auth
      .getUser();
    if (userError || !user) return json({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const productId = asString((body as Record<string, unknown>).product_id);
    if (!productId) return json({ error: "product_id is required" }, 400);

    // 商品の実在と販売可否は service role で確認する。
    // 匿名クライアントだと RLS により is_active=false の商品が「存在しない」と
    // 区別できず、準備中なのか ID 違いなのかを切り分けられないため。
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: product, error: productError } = await admin
      .from("shop_products")
      .select("id, name_ja, price_jpy, stripe_price_id, is_active")
      .eq("id", productId)
      .maybeSingle();
    if (productError) throw new Error(productError.message);
    if (!product) return json({ error: "product not found" }, 404);

    if (!product.is_active) {
      return json({ error: "この商品は現在購入できません" }, 409);
    }
    if (!asString(product.stripe_price_id)) {
      // 価格未設定のまま購入導線に来た = 設定漏れ。金額を勝手に補わない。
      return json({ error: "product price is not configured" }, 409);
    }

    // 既に購入済みなら二重課金させない。買い直しではなく再ダウンロードへ誘導する。
    const { data: existing, error: existingError } = await admin
      .from("shop_purchases")
      .select("id")
      .eq("user_id", user.id)
      .eq("product_id", productId)
      .eq("status", "paid")
      .maybeSingle();
    if (existingError) throw new Error(existingError.message);
    if (existing) {
      return json({ already_purchased: true, purchase_id: existing.id }, 200);
    }

    const form = new URLSearchParams();
    form.set("mode", "payment");
    form.set("line_items[0][price]", asString(product.stripe_price_id));
    form.set("line_items[0][quantity]", "1");
    const returnUrls = buildShopReturnUrls(SITE_URL, productId);
    form.set("success_url", returnUrls.successUrl);
    form.set("cancel_url", returnUrls.cancelUrl);
    form.set("client_reference_id", user.id);
    // webhook が購入行を作るのに必要な情報。ここが欠けると支払いは通るのに
    // 権利が付与されない (= 客からは「金だけ取られた」に見える) 事故になる。
    form.set("metadata[user_id]", user.id);
    form.set("metadata[shop_product_id]", productId);
    // funnel の最終段をサーバ側で記録するために持ち回す (2026-07-29 追加)。
    // クライアントに「買えました」と自己申告させると、金銭の絡む段だけ
    // 検証できない数字になる。visitor_id を Stripe 経由で webhook まで運び、
    // 入金を確認した webhook が purchase_complete を書く。
    const visitorId = asString((body as Record<string, unknown>).visitor_id);
    if (visitorId) form.set("metadata[shop_visitor_id]", visitorId);
    const source = asString((body as Record<string, unknown>).source);
    if (source) form.set("metadata[shop_source]", source);
    if (user.email) form.set("customer_email", user.email);

    const response = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: form.toString(),
      },
    );
    const session = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = asString(session?.error?.message) ||
        `Stripe API failed: ${response.status}`;
      throw new Error(message);
    }

    return json({
      checkout_url: asString(session.url),
      session_id: asString(session.id),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[shop-checkout]", message);
    return json({ error: message }, 500);
  }
});
