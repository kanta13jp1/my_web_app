import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY is not set in environment variables.");
    }

    const prompt = `
あなたは優秀な政治アナリスト・リサーチャーです。
国民民主党の統一地方選に向けた「700人必達」目標（現状約340人、純増目標約360人）の月次KPI管理、現在の所属地方議員の最新情報、直近の地方選挙スケジュール、および地方議員数の時系列推移データを調査・整理してください。

必ず以下のJSONスキーマに従った形式で出力してください。Markdownのコードブロック（\`\`\`json）は使用せず、純粋なJSON文字列のみを出力してください。

{
  "type": "object",
  "properties": {
    "politicians": {
      "type": "array",
      "description": "現在ネット上で確認できる国民民主党の所属地方議員のリスト（代表的な数名〜10名程度をピックアップしてください）",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "number" },
          "name": { "type": "string" },
          "region": { "type": "string", "description": "都道府県" },
          "municipality": { "type": "string", "description": "市区町村（県議の場合は空文字または県名）" },
          "type": { "type": "string", "description": "県議、市議、区議、町議など" },
          "gender": { "type": "string", "description": "男性 または 女性" },
          "age": { "type": "number", "description": "年齢が不明な場合は推測値または0" },
          "profile": { "type": "string", "description": "簡易プロフィール" }
        },
        "required": ["id", "name", "region", "municipality", "type", "gender", "age", "profile"]
      }
    },
    "monthlyKpi": {
      "type": "object",
      "description": "統一地方選700人倍増に向けた工程管理KPI（都道府県連ごとの配分シミュレーション）",
      "properties": {
        "targetTotal": { "type": "number", "description": "700" },
        "currentTotal": { "type": "number", "description": "340" },
        "requiredAddition": { "type": "number", "description": "360" },
        "message": { "type": "string", "description": "「700という看板だけではなく、各県連に“何人積むか”を割り振る管理型選挙にしないと、最後は雰囲気目標で終わります。倍増は“勢い”ではなく“工程管理”の勝負です。万が一達成できなければ解党しなければなりません」という趣旨のメッセージ" },
        "regions": {
          "type": "array",
          "description": "重点都道府県のKPI配分（東京都、愛知県、大阪府など数県）",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "current": { "type": "number", "description": "現在の現職維持目標数" },
              "target": { "type": "number", "description": "必達目標数" },
              "newCandidates": { "type": "number", "description": "新人擁立数" },
              "supportCount": { "type": "number", "description": "接戦区支援回数" },
              "expectedEndorsement": { "type": "string", "description": "公認内定時期 (YYYY-MM)" }
            },
            "required": ["name", "current", "target", "newCandidates", "supportCount", "expectedEndorsement"]
          }
        }
      },
      "required": ["targetTotal", "currentTotal", "requiredAddition", "message", "regions"]
    },
    "electionSchedules": {
      "type": "array",
      "description": "直近の地方選挙のスケジュール情報（数件ピックアップ）",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "number" },
          "electionName": { "type": "string", "description": "選挙名（例: 〇〇市議会議員選挙）" },
          "date": { "type": "string", "description": "投票日 (YYYY-MM-DD)" },
          "dppCandidateCount": { "type": "number", "description": "国民民主党の擁立候補者数" },
          "location": { "type": "string", "description": "自治体名・場所" }
        },
        "required": ["id", "electionName", "date", "dppCandidateCount", "location"]
      }
    },
    "timeSeriesData": {
      "type": "array",
      "description": "国民民主党の地方議員数の時系列推移（過去の統一地方選〜現在〜2027年目標）",
      "items": {
        "type": "object",
        "properties": {
          "label": { "type": "string", "description": "時期（例: 2023年4月, 現在, 2027年4月(目標)）" },
          "count": { "type": "number", "description": "議員数" }
        },
        "required": ["label", "count"]
      }
    }
  },
  "required": ["politicians", "monthlyKpi", "electionSchedules", "timeSeriesData"]
}
`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.2,
          },
        }),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      console.error("Gemini API Error:", errorBody);
      throw new Error(`Gemini API returned status: ${response.status}`);
    }

    const responseData = await response.json();
    const generatedText = responseData.candidates?.[0]?.content?.parts?.[0]?.text;
    
    if (!generatedText) {
      throw new Error("Failed to extract content from Gemini API response.");
    }

    const parsedData = JSON.parse(generatedText);

    return new Response(
      JSON.stringify({
        success: true,
        politicians: parsedData.politicians || [],
        monthlyKpi: parsedData.monthlyKpi || {},
        electionSchedules: parsedData.electionSchedules || [],
        timeSeriesData: parsedData.timeSeriesData || [],
        generatedAt: new Date().toISOString()
      }),
      { 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  } catch (error) {
    console.error("Function error:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});