// 販売 funnel の到達を記録する Edge Function (2026-07-29)
//
// 目的: 商品ページの閲覧・購入ボタン押下・Checkout 到達を数える。
// 現状は購入完了しか記録が無く、「どこで落ちているか」が分からない。
//
// 設計の要点:
//  * **認証を要求しない**。未ログインの閲覧者こそが母数なので、ログインを
//    条件にすると funnel の入口が丸ごと欠測する。
//  * 認証しない代わりに、**書き込める内容を列挙値に限定**する。stage は4種、
//    source は文字種を制限。任意の文字列は入らない。
//  * 主キー衝突は**無視する**(同じ訪問者の同じ段は1回だけ数えたい)。
//    リロードのたびに閲覧数が増えると、到達人数として読めなくなる。
//  * 記録の失敗で呼び出し元の体験を止めない。計測は本体機能ではない。
//  * `purchase_complete` はここでは受け付けない。金銭が絡む段だけは
//    **クライアントの自己申告を信じず**、webhook がサーバ側で記録する。

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

/** クライアントから受け付ける段。purchase_complete は意図的に含めない。 */
const CLIENT_STAGES = new Set([
  "product_view",
  "purchase_click",
  "checkout_redirect",
]);

const SOURCE_PATTERN = /^[a-z0-9_.-]{1,64}$/;
const CAMPAIGN_PATTERN = /^[a-z0-9_.-]{0,64}$/;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
    const body = await req.json().catch(() => ({}));
    const payload = body as Record<string, unknown>;

    const visitorId = asString(payload.visitor_id).toLowerCase();
    const productId = asString(payload.product_id);
    const stage = asString(payload.stage);
    // 流入元が無い訪問は「直接」として数える。捨てると母数が合わなくなる。
    const source = asString(payload.source, "direct").toLowerCase() || "direct";
    const campaign = asString(payload.campaign).toLowerCase();

    if (!UUID_PATTERN.test(visitorId)) {
      return json({ error: "visitor_id must be a uuid" }, 400);
    }
    if (!productId) return json({ error: "product_id is required" }, 400);
    if (!CLIENT_STAGES.has(stage)) {
      // purchase_complete をここへ投げてきた場合もこちらで弾かれる。
      return json({ error: "unsupported stage" }, 400);
    }
    if (!SOURCE_PATTERN.test(source)) {
      return json({ error: "invalid source" }, 400);
    }
    if (!CAMPAIGN_PATTERN.test(campaign)) {
      return json({ error: "invalid campaign" }, 400);
    }

    // ログイン済みなら紐付ける。未ログインでも記録は続ける (母数を欠かさない)。
    let authUserId: string | null = null;
    const authHeader = req.headers.get("Authorization");
    if (authHeader) {
      try {
        const userClient = createClient(
          SUPABASE_URL,
          Deno.env.get("SUPABASE_ANON_KEY") ?? "",
          { global: { headers: { Authorization: authHeader } } },
        );
        const { data } = await userClient.auth.getUser();
        authUserId = data?.user?.id ?? null;
      } catch (_) {
        // 認証できなくても計測は続ける。ここで失敗を伝播させる価値はない。
        authUserId = null;
      }
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { error } = await admin
      .from("shop_funnel_events")
      .upsert({
        visitor_id: visitorId,
        product_id: productId,
        stage,
        source,
        campaign,
        auth_user_id: authUserId,
      }, {
        onConflict: "visitor_id,product_id,source,stage",
        // 既にある行は更新しない。first_occurred_at を「最初に到達した時刻」の
        // ままにしておきたい (リロードで時刻が上書きされると経路の順序が壊れる)。
        ignoreDuplicates: true,
      });
    if (error) throw new Error(error.message);

    return json({ recorded: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[shop-funnel]", message);
    return json({ error: message }, 500);
  }
});
