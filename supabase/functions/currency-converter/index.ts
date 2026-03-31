// Currency Converter Edge Function
// 通貨換算 (金融ツール)
// - リアルタイム為替レート
// - 通貨変換
// - 主要通貨ペア
// - 履歴記録
//
// GET → 為替レート / 変換 / 通貨一覧

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Fallback rates (JPY base, updated periodically)
const FALLBACK_RATES: Record<string, number> = {
  JPY: 1,
  USD: 0.0067,
  EUR: 0.0061,
  GBP: 0.0053,
  CNY: 0.0485,
  KRW: 9.13,
  AUD: 0.0103,
  CAD: 0.0091,
  CHF: 0.0059,
  HKD: 0.0523,
  SGD: 0.0089,
  TWD: 0.216,
  THB: 0.235,
  INR: 0.561,
  BRL: 0.0345,
};

const CURRENCY_NAMES: Record<string, string> = {
  JPY: "日本円", USD: "米ドル", EUR: "ユーロ", GBP: "英ポンド",
  CNY: "人民元", KRW: "韓国ウォン", AUD: "豪ドル", CAD: "カナダドル",
  CHF: "スイスフラン", HKD: "香港ドル", SGD: "シンガポールドル",
  TWD: "台湾ドル", THB: "タイバーツ", INR: "インドルピー", BRL: "ブラジルレアル",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'currencies' | 'convert' | 'rates'
      const from = url.searchParams.get("from") ?? "JPY";
      const to = url.searchParams.get("to") ?? "USD";
      const amountStr = url.searchParams.get("amount") ?? "1";
      const amount = parseFloat(amountStr) || 1;

      if (view === "currencies") {
        const currencies = Object.entries(CURRENCY_NAMES).map(([code, name]) => ({ code, name }));
        return new Response(
          JSON.stringify({ success: true, currencies }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Try to fetch live rates from a free API
      let rates = FALLBACK_RATES;
      let source = "fallback";
      try {
        const rateRes = await fetch("https://api.exchangerate-api.com/v4/latest/JPY");
        if (rateRes.ok) {
          const rateData = await rateRes.json();
          if (rateData.rates) {
            rates = rateData.rates;
            source = "live";
          }
        }
      } catch {
        // Use fallback
      }

      if (view === "rates") {
        const rateList = Object.entries(CURRENCY_NAMES).map(([code, name]) => ({
          code,
          name,
          rateFromJPY: rates[code] ?? null,
        }));
        return new Response(
          JSON.stringify({ success: true, base: "JPY", rates: rateList, source }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Convert
      const fromRate = rates[from];
      const toRate = rates[to];

      if (!fromRate || !toRate) {
        return new Response(
          JSON.stringify({ success: false, error: `Unsupported currency: ${!fromRate ? from : to}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Convert via JPY as base
      const inJPY = amount / fromRate;
      const result = inJPY * toRate;

      return new Response(
        JSON.stringify({
          success: true,
          from: { code: from, name: CURRENCY_NAMES[from] ?? from, amount },
          to: { code: to, name: CURRENCY_NAMES[to] ?? to, amount: Math.round(result * 100) / 100 },
          rate: Math.round((toRate / fromRate) * 1000000) / 1000000,
          source,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
