// AI Writing Assistant Edge Function
// AI文章作成支援 (Grammarly/Notion AI競合)
// - 文章の改善・校正・要約
// - トーン変換 (フォーマル/カジュアル/SNS向け)
// - 続き文章の生成
// - タイトル・見出し提案
// - 多言語翻訳
//
// POST → improve / summarize / continue / translate / tone / titles

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const TONE_DESCRIPTIONS: Record<string, string> = {
  formal: "フォーマルでプロフェッショナルなトーン",
  casual: "カジュアルで親しみやすいトーン",
  sns: "SNS向けの短くキャッチーなトーン",
  academic: "学術的で論文調のトーン",
  sales: "説得力のある営業向けトーン",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const { action, text, tone, target_language } = body;

    if (!text || text.trim() === "") {
      return new Response(JSON.stringify({ success: false, error: "text is required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let prompt = "";
    switch (action) {
      case "improve":
        prompt = `以下の文章を、読みやすく自然な日本語に改善してください。元の意味を変えずに表現を洗練させてください。\n\n${text}`;
        break;
      case "summarize":
        prompt = `以下の文章を3〜5行で簡潔に要約してください。\n\n${text}`;
        break;
      case "continue":
        prompt = `以下の文章の続きを自然な流れで200字程度書いてください。\n\n${text}`;
        break;
      case "translate":
        prompt = `以下の文章を${target_language ?? "英語"}に翻訳してください。\n\n${text}`;
        break;
      case "tone":
        prompt = `以下の文章を${TONE_DESCRIPTIONS[tone ?? "formal"]}に書き直してください。\n\n${text}`;
        break;
      case "titles":
        prompt = `以下の文章のタイトル候補を5つ提案してください。各タイトルは20字以内で、魅力的で検索されやすいものにしてください。番号付きリストで回答してください。\n\n${text}`;
        break;
      default:
        return new Response(JSON.stringify({ success: false, error: "Unknown action" }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    if (!GEMINI_API_KEY) {
      // Fallback response when API key is not configured
      return new Response(JSON.stringify({
        success: true,
        result: `[AI Writing Assistant] ${action}機能はGEMINI_API_KEYの設定が必要です。`,
        action,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
      },
    );

    const geminiData = await geminiRes.json();
    const result = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    return new Response(JSON.stringify({ success: true, result, action }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
