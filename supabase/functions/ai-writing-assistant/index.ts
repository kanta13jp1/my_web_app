// AI Writing Assistant Edge Function
// AI文章作成支援 (Grammarly/Notion AI競合)
// - 文章の改善・校正・要約
// - トーン変換 (フォーマル/カジュアル/SNS向け)
// - 続き文章の生成
// - タイトル・見出し提案
// - 多言語翻訳
// - 議事録生成 (meeting minutes)
// - X/Twitterスレッド生成 (twitter thread)
// - 技術ブログ記事アウトライン生成 (blog outline)
//
// POST → improve / summarize / continue / translate / tone / titles / minutes / thread / blog

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { prependCharacter } from "../_shared/ai_character_preamble.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
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
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json().catch(() => ({}));
    const { action, text, tone, target_language } = body;

    if (!text || text.trim() === "") {
      return new Response(
        JSON.stringify({ success: false, error: "text is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let prompt = "";
    switch (action) {
      case "improve":
        prompt =
          `以下の文章を、読みやすく自然な日本語に改善してください。元の意味を変えずに表現を洗練させてください。\n\n${text}`;
        break;
      case "summarize":
        prompt = `以下の文章を3〜5行で簡潔に要約してください。\n\n${text}`;
        break;
      case "continue":
        prompt =
          `以下の文章の続きを自然な流れで200字程度書いてください。\n\n${text}`;
        break;
      case "translate":
        prompt = `以下の文章を${
          target_language ?? "英語"
        }に翻訳してください。\n\n${text}`;
        break;
      case "tone":
        prompt = `以下の文章を${
          TONE_DESCRIPTIONS[tone ?? "formal"]
        }に書き直してください。\n\n${text}`;
        break;
      case "titles":
        prompt =
          `以下の文章のタイトル候補を5つ提案してください。各タイトルは20字以内で、魅力的で検索されやすいものにしてください。番号付きリストで回答してください。\n\n${text}`;
        break;
      case "minutes":
        prompt =
          `以下のメモ・会話内容を整理して、ビジネス会議の議事録フォーマットに変換してください。\n\n【出力フォーマット】\n## 議事録\n\n**日時**: [記載があれば抽出、なければ「未記載」]\n**参加者**: [記載があれば抽出]\n\n### 議事内容\n（箇条書きで整理）\n\n### 決定事項\n（明確に決まったことを箇条書き）\n\n### アクションアイテム\n| 担当者 | タスク | 期限 |\n|--------|--------|------|\n\n### 次回予定\n[記載があれば抽出]\n\n---\n入力テキスト:\n${text}`;
        break;
      case "thread":
        prompt =
          `以下の内容をX (Twitter) のスレッド形式に変換してください。\n\n【ルール】\n- 各ツイートは140字以内\n- スレッドは5〜8ツイートで構成\n- 1ツイート目は注目を集めるフックで始める\n- 各ツイートの冒頭に番号 (1/ 2/ ...) を付ける\n- 最後のツイートに #buildinpublic #自分株式会社 のハッシュタグを付ける\n- 日本語で書く\n\n入力テキスト:\n${text}`;
        break;
      case "blog":
        prompt =
          `以下の内容を元に、Zenn/Qiita向けの技術記事アウトラインを生成してください。\n\n【出力フォーマット】\n## 記事タイトル案（3案）\n1. ...\n2. ...\n3. ...\n\n## タグ候補\n#Flutter #Supabase #個人開発 など\n\n## 記事構成\n### はじめに\n（何を作ったか・なぜ作ったかの導入文案）\n\n### 技術スタック\n（使用技術と選定理由）\n\n### 実装のポイント\n（コア部分の説明ポイント3〜5個）\n\n### つまずいたポイントと解決策\n（ハマりどころ）\n\n### まとめ\n（成果と今後の展望）\n\n---\n入力テキスト:\n${text}`;
        break;
      default:
        return new Response(
          JSON.stringify({ success: false, error: "Unknown action" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
    }

    if (!GEMINI_API_KEY) {
      // Fallback response when API key is not configured
      return new Response(
        JSON.stringify({
          success: true,
          result:
            `[AI Writing Assistant] ${action}機能はGEMINI_API_KEYの設定が必要です。`,
          action,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prependCharacter(prompt) }] }],
        }),
      },
    );

    const geminiData = await geminiRes.json();
    const result = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    return new Response(JSON.stringify({ success: true, result, action }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
