// AI Summarizer Edge Function
// AIテキスト要約・分析 (Claude競合)
// - テキスト要約 (短/中/長)
// - キーポイント抽出
// - 感情分析
// - アクションアイテム抽出
//
// POST → 要約 / キーポイント / 感情分析 / アクションアイテム

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "history") {
        const { data: history } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "ai_summary")
          .order("created_at", { ascending: false })
          .limit(20);

        return new Response(
          JSON.stringify({
            success: true,
            history: (history ?? []).map((h) => ({
              ...(h.metadata as Record<string, unknown>),
              createdAt: h.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          actions: ["summarize", "key_points", "sentiment", "action_items"],
          lengths: ["short", "medium", "long"],
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action, text, length } = body;

      if (!text || typeof text !== "string" || text.trim().length === 0) {
        return new Response(
          JSON.stringify({ success: false, error: "text required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const maxLength = length === "long" ? 500 : length === "medium" ? 200 : 100;

      let prompt = "";
      if (action === "key_points") {
        prompt = `以下のテキストから重要なポイントを箇条書きで5つ以内に抽出してください。日本語で回答:\n\n${text}`;
      } else if (action === "sentiment") {
        prompt = `以下のテキストの感情分析を行ってください。ポジティブ/ネガティブ/ニュートラルの判定と、主要な感情キーワードを日本語で回答:\n\n${text}`;
      } else if (action === "action_items") {
        prompt = `以下のテキストからアクションアイテム（やるべきこと）を抽出してください。箇条書きで日本語回答:\n\n${text}`;
      } else {
        prompt = `以下のテキストを${maxLength}文字以内で要約してください。日本語で回答:\n\n${text}`;
      }

      let result: string;

      if (ANTHROPIC_API_KEY) {
        const aiRes = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-haiku-4-5-20251001",
            max_tokens: 1024,
            messages: [{ role: "user", content: prompt }],
          }),
        });

        if (!aiRes.ok) {
          const errText = await aiRes.text();
          throw new Error(`AI API error: ${aiRes.status} ${errText}`);
        }

        const aiData = await aiRes.json();
        result = aiData.content?.[0]?.text ?? "要約を生成できませんでした";
      } else {
        // Fallback: simple extractive summary
        const sentences = text.split(/[。！？\n]+/).filter((s: string) => s.trim().length > 0);
        if (action === "key_points") {
          result = sentences.slice(0, 5).map((s: string) => `・${s.trim()}`).join("\n");
        } else if (action === "sentiment") {
          const positiveWords = ["良い", "素晴らしい", "嬉しい", "楽しい", "成功", "感謝", "最高"];
          const negativeWords = ["悪い", "問題", "失敗", "困る", "残念", "エラー", "不具合"];
          let posCount = 0;
          let negCount = 0;
          for (const w of positiveWords) { if (text.includes(w)) posCount++; }
          for (const w of negativeWords) { if (text.includes(w)) negCount++; }
          const sentiment = posCount > negCount ? "ポジティブ" : negCount > posCount ? "ネガティブ" : "ニュートラル";
          result = `感情: ${sentiment} (ポジティブワード: ${posCount}, ネガティブワード: ${negCount})`;
        } else if (action === "action_items") {
          const actionSentences = sentences.filter((s: string) =>
            /する|やる|必要|確認|対応|実装|修正|追加|作成|更新/.test(s)
          );
          result = actionSentences.length > 0
            ? actionSentences.slice(0, 5).map((s: string) => `・${s.trim()}`).join("\n")
            : "アクションアイテムが見つかりませんでした";
        } else {
          result = sentences.slice(0, 3).join("。") + "。";
        }
      }

      // Log summary
      await adminClient.from("app_analytics").insert({
        user_id: user.id,
        source: "ai_summary",
        metadata: {
          summary_id: crypto.randomUUID(),
          action: action ?? "summarize",
          inputLength: text.length,
          outputLength: result.length,
          length: length ?? "short",
        },
        created_at: new Date().toISOString(),
      });

      return new Response(
        JSON.stringify({ success: true, action: action ?? "summarize", result }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ai-summarizer error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
