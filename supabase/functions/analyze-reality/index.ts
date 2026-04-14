import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method not allowed." }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    const { text } = await req.json().catch(() => ({}));
    if (!text || typeof text !== "string") {
      return new Response(
        JSON.stringify({ success: false, error: "text is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      // Gemini APIキーがない場合はルールベースで分析
      return new Response(
        JSON.stringify({
          success: true,
          analysis: ruleBasedAnalysis(text),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Gemini API で分析
    const prompt = `あなたは認知行動療法の専門家です。以下のテキストを分析してください。

テキスト: "${text}"

以下のJSON形式で回答してください（日本語で）:
{
  "classification": "fact" か "interpretation" か "emotion",
  "category": "geopolitics" / "economy" / "career" / "relationship" / "health" / "self" / "other" のいずれか,
  "analysis": "このテキストの分析（事実と解釈と感情を区別し、認知の歪みがあれば指摘。ただし相手の現実認識を否定せず、共感した上で別の視点を提示）",
  "action_suggestions": ["取りうる行動1", "取りうる行動2", "取りうる行動3"],
  "severity": 1-5の数値（人生への影響度）
}`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 1024,
          },
        }),
      },
    );

    if (!geminiRes.ok) {
      return new Response(
        JSON.stringify({
          success: true,
          analysis: ruleBasedAnalysis(text),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const geminiData = await geminiRes.json();
    const raw = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    // JSON部分を抽出
    const jsonMatch = raw.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        const parsed = JSON.parse(jsonMatch[0]);
        return new Response(
          JSON.stringify({ success: true, analysis: parsed }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      } catch {
        // JSONパース失敗時はルールベース
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        analysis: {
          ...ruleBasedAnalysis(text),
          ai_raw: raw,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ success: false, error: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

// deno-lint-ignore no-explicit-any
function ruleBasedAnalysis(text: string): Record<string, any> {
  // キーワードベースの簡易分類
  const emotionWords = ["悲しい", "辛い", "怖い", "不安", "怒り", "絶望", "嫌", "苦しい"];
  const factIndicators = ["である", "されている", "という事実", "実際に", "統計", "データ"];
  const interpretationWords = ["と思う", "だろう", "かもしれない", "に違いない", "はず", "できない"];

  const hasEmotion = emotionWords.some((w) => text.includes(w));
  const hasFact = factIndicators.some((w) => text.includes(w));
  const hasInterpretation = interpretationWords.some((w) => text.includes(w));

  let classification = "fact";
  if (hasEmotion && !hasFact) classification = "emotion";
  else if (hasInterpretation) classification = "interpretation";

  // カテゴリ推定
  let category = "other";
  if (/国|政治|占領|アメリカ|中国|戦争/.test(text)) category = "geopolitics";
  else if (/給料|お金|借金|経済|貧困|会社/.test(text)) category = "economy";
  else if (/仕事|キャリア|転職|上司/.test(text)) category = "career";
  else if (/付き合い|恋愛|友人|孤独|人間関係/.test(text)) category = "relationship";
  else if (/健康|病気|体重|運動/.test(text)) category = "health";
  else if (/自分|年齢|能力|歳/.test(text)) category = "self";

  return {
    classification,
    category,
    analysis:
      "この記述には事実と解釈が混在している可能性があります。" +
      "事実（変えられない現実）と解釈（自分の見方）を分けて考えると、" +
      "行動可能な部分が見えてくることがあります。",
    action_suggestions: [
      "この現実の中で自分がコントロールできる部分を1つ特定する",
      "同じ状況でも異なる行動を取っている人の事例を調べる",
      "3ヶ月後の自分に向けて手紙を書く",
    ],
    severity: 3,
  };
}
