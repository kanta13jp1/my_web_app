// 購入者にだけ配信ファイルの署名付きURLを発行する Edge Function (2026-07-28)
//
// これが有料化の要。ここが緩いと、非公開バケットにしても意味がなくなる。
//
// 流れ:
//   1. ログイン済みか確認する
//   2. その利用者に status = 'paid' の購入行があるか確認する
//   3. 非公開バケットの対象ファイルに、短い有効期限の署名付きURLを発行する
//   4. 発行を監査ログに残す
//
// 設計の要点:
//  * 権利確認は **service role で購入行を読む**。利用者トークン + RLS でも同じ
//    結果にはなるが、「RLS の書き方を後から緩めた瞬間に配信が漏れる」構造に
//    したくないため、この関数の中で明示的に条件を書く。
//  * 有効期限は短くする (既定 5 分)。URL は署名さえあれば誰でも使えるので、
//    長い期限を付けると実質的に共有可能なリンクを配ることになる。
//  * 商品が is_active でなくても、**既に買った人には配信する**。販売停止は
//    「これから売らない」であって「買った人から取り上げる」ではない。
//  * 発行回数は数えて残すが、ここでは上限で止めない。正当な買い直し
//    (PC 故障・再インストール) を機械的に阻むと問い合わせ対応の方が高くつく。
//    異常が起きたときに後から気づけるよう、記録だけは必ず残す。

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { safeDownloadFileName } from "./download_file_name.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 署名付きURLの有効期限 (秒)。落とし始めるまでの猶予として十分で、
// かつ URL を貼って回すには短い、という水準。
const SIGNED_URL_TTL_SECONDS = 300;

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

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // ---- 権利確認 ----
    const { data: purchase, error: purchaseError } = await admin
      .from("shop_purchases")
      .select("id, status, purchased_at")
      .eq("user_id", user.id)
      .eq("product_id", productId)
      .eq("status", "paid")
      .order("purchased_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (purchaseError) throw new Error(purchaseError.message);
    if (!purchase) {
      // 「買っていない」と「商品が無い」を区別して返す必要はない。
      // どちらも利用者にできることは同じ (購入導線へ戻る)。
      return json({ error: "purchase not found", purchased: false }, 403);
    }

    // ---- 配信ファイルの所在 ----
    const { data: product, error: productError } = await admin
      .from("shop_products")
      .select(
        "id, storage_bucket, storage_path, version, file_size_bytes, sha256, download_file_name",
      )
      .eq("id", productId)
      .maybeSingle();
    if (productError) throw new Error(productError.message);
    if (!product) return json({ error: "product not found" }, 404);

    const bucket = asString(product.storage_bucket);
    const path = asString(product.storage_path);
    if (!bucket || !path) {
      return json({ error: "product file location is not configured" }, 500);
    }

    // ---- 署名付きURLの発行 ----
    const { data: signed, error: signError } = await admin.storage
      .from(bucket)
      .createSignedUrl(path, SIGNED_URL_TTL_SECONDS, {
        download: safeDownloadFileName(
          asString(product.download_file_name),
          productId,
          asString(product.version, "1.0"),
        ),
      });
    if (signError) throw new Error(signError.message);
    const signedUrl = asString(signed?.signedUrl);
    if (!signedUrl) {
      // 権利はあるのにファイルが無い = 出荷事故。呼び出し元に握り潰させない。
      throw new Error("failed to create signed url");
    }

    const expiresAt = new Date(Date.now() + SIGNED_URL_TTL_SECONDS * 1000);

    // ---- 監査ログ (失敗しても配信自体は止めない) ----
    const { error: logError } = await admin.from("shop_download_events").insert(
      {
        purchase_id: purchase.id,
        user_id: user.id,
        product_id: productId,
        expires_at: expiresAt.toISOString(),
        user_agent: req.headers.get("User-Agent"),
      },
    );
    if (logError) {
      console.error("[shop-download] audit log failed:", logError.message);
    }

    return json({
      download_url: signedUrl,
      expires_at: expiresAt.toISOString(),
      expires_in_seconds: SIGNED_URL_TTL_SECONDS,
      version: asString(product.version),
      file_size_bytes: product.file_size_bytes,
      // 落としたファイルの同一性を購入者自身が確認できるようにする
      sha256: asString(product.sha256),
      file_name: safeDownloadFileName(
        asString(product.download_file_name),
        productId,
        asString(product.version, "1.0"),
      ),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[shop-download]", message);
    return json({ error: message }, 500);
  }
});
