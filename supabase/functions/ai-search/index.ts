// AI Search Edge Function
// 自然言語検索とセマンティックサーチを提供
// fallback: OpenAI 未設定時は ILIKE ベースの全文検索にフォールバック

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface SearchRequest {
  query: string;
  limit?: number;
  mode?: "ai" | "text" | "auto"; // auto = AI if configured, else text
}

interface Note {
  id: string;
  title: string;
  content?: string;
  tags?: string[];
  category_id?: string;
  created_at: string;
  updated_at: string;
}

/** ILIKE ベースの全文検索 (OpenAI 不要・常に動作) */
async function textSearch(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  query: string,
  limit: number,
): Promise<Note[]> {
  const keywords = query.trim().split(/\s+/).filter((k) => k.length > 0);
  if (keywords.length === 0) return [];

  // 全キーワードが title か content のいずれかに含まれる行を OR 検索
  const orConditions = keywords
    .map((k) => `title.ilike.%${k}%,content.ilike.%${k}%`)
    .join(",");

  const { data, error } = await supabase
    .from("notes")
    .select("id, title, content, tags, category_id, created_at, updated_at")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .or(orConditions)
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data as Note[]) ?? [];
}

/** AI 再ランク: OpenAI GPT-4o-mini でノートを意味的に並べ替え */
async function aiRank(
  openaiApiKey: string,
  query: string,
  notes: Note[],
  limit: number,
): Promise<{ rankedNotes: Note[]; explanation: string; tokens: number }> {
  const systemPrompt =
    `あなたは検索エキスパートです。ユーザーの検索クエリに最も関連性の高いメモを見つけてください。

検索クエリ: ${query}

以下のメモリストから、最も関連性の高いメモのIDを順番に並べてください。
関連性が低いものは除外してください。

JSON形式で回答してください:
{
  "rankedIds": ["note_id1", "note_id2", ...],
  "explanation": "ランク付けの理由"
}`;

  const notesData = notes.map((note) => ({
    id: note.id,
    title: note.title,
    content: note.content?.substring(0, 300),
    tags: note.tags,
  }));

  const rankingResponse = await fetch(
    "https://api.openai.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: JSON.stringify(notesData, null, 2) },
        ],
        temperature: 0.3,
        max_tokens: 800,
        response_format: { type: "json_object" },
      }),
    },
  );

  if (!rankingResponse.ok) {
    throw new Error(`OpenAI API error: ${rankingResponse.status}`);
  }

  const rankingData = await rankingResponse.json();
  const rankingResult = JSON.parse(
    rankingData.choices[0]?.message?.content || "{}",
  );
  const rankedIds: string[] = rankingResult.rankedIds || [];
  const tokens: number = rankingData.usage?.total_tokens || 0;

  const rankedNotes = rankedIds
    .map((id: string) => notes.find((note) => note.id === id))
    .filter((note): note is Note => note !== undefined)
    .slice(0, limit);

  return {
    rankedNotes,
    explanation: rankingResult.explanation || "",
    tokens,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing authorization header" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 },
      );
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized", results: [], totalResults: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 },
      );
    }

    let parsedBody: SearchRequest;
    try {
      parsedBody = await req.json().catch(() => ({}));
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid JSON body" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
      );
    }
    const { query, limit = 20, mode = "auto" } = parsedBody;
    if (!query) {
      return new Response(
        JSON.stringify({ success: false, error: "Query is required", results: [], totalResults: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
      );
    }

    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    const useAi = (mode === "ai" || mode === "auto") && !!openaiApiKey;

    let results: Note[] = [];
    let explanation = "";
    let searchMode = "text";
    let totalTokens = 0;

    if (useAi) {
      try {
        // AI モード: 全ノート取得 → AI 再ランク
        const { data: allNotes, error: notesError } = await supabaseClient
          .from("notes")
          .select("id, title, content, tags, category_id, created_at, updated_at")
          .eq("user_id", user.id)
          .is("deleted_at", null)
          .limit(100);

        if (notesError) throw notesError;

        const { rankedNotes, explanation: exp, tokens } = await aiRank(
          openaiApiKey!,
          query,
          (allNotes as Note[]) ?? [],
          limit,
        );

        results = rankedNotes;
        explanation = exp;
        totalTokens = tokens;
        searchMode = "ai";

        // AI 使用量ログ
        await supabaseClient.from("ai_usage_log").insert({
          user_id: user.id,
          action: "search",
          input_tokens: tokens,
          output_tokens: 0,
          total_tokens: tokens,
          cost_estimate: tokens * 0.00001,
          created_at: new Date().toISOString(),
        });
      } catch (aiError) {
        // AI 失敗 → テキスト検索にフォールバック
        console.warn("AI search failed, falling back to text search:", aiError);
        results = await textSearch(supabaseClient, user.id, query, limit);
        explanation = "AI検索に失敗したため、テキスト検索を使用しました";
        searchMode = "text_fallback";
      }
    } else {
      // テキスト検索モード (OpenAI 不要)
      results = await textSearch(supabaseClient, user.id, query, limit);
      searchMode = "text";
    }

    return new Response(
      JSON.stringify({
        success: true,
        results,
        totalResults: results.length,
        explanation,
        searchMode,
        totalTokens,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error("Error in AI search:", error);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage, results: [], totalResults: 0 }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});
