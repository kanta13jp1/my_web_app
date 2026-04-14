// ai-hub — AI・エージェント・AI大学統合EF
// Merges (16 EFs): daily-judgment, ai-search, ai-suggest-tags, ai-secretary,
//   ai-summarizer, agent-hub, virtual-organization, my-ai-agent,
//   generate-daily-challenges, trigger-analysis, analyze-reality,
//   local-election-intelligence, ai-university-content,
//   ai-university-streaks, ai-university-badges
// NOTE: ai-assistant stays standalone (1079 lines, complex multi-provider logic)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const QUIZ_MASTER_3 = {
  badge_id: "quiz_master_3",
  badge_name: "クイズ3冠",
  icon_emoji: "🥉",
  condition: "3社以上でクイズ正解",
};
const QUIZ_MASTER_ALL = {
  badge_id: "quiz_master_all",
  badge_name: "全社制覇",
  icon_emoji: "🏆",
  condition: "全アクティブプロバイダーでクイズ正解",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await c.auth.getUser();
  return user?.id ?? null;
}

async function evaluateUniversityQuizMaster(admin: SupabaseClient, userId: string) {
  const { data: scoreRows, error: scoreErr } = await admin
    .from("ai_university_scores")
    .select("provider_id")
    .eq("user_id", userId)
    .eq("quiz_correct", true);
  if (scoreErr) throw new Error(scoreErr.message);

  const correctSet = new Set<string>();
  for (const row of scoreRows ?? []) {
    const providerId = asString((row as { provider_id?: unknown }).provider_id);
    if (providerId) correctSet.add(providerId);
  }

  const { data: providerRows, error: providerErr } = await admin
    .from("ai_university_content")
    .select("provider")
    .eq("is_active", true);
  if (providerErr) throw new Error(providerErr.message);

  const providerSet = new Set<string>();
  for (const row of providerRows ?? []) {
    const provider = asString((row as { provider?: unknown }).provider);
    if (provider) providerSet.add(provider);
  }

  const awarded: string[] = [];
  if (correctSet.size >= 3) {
    const { data, error } = await admin.rpc("award_ai_university_badge", {
      p_user_id: userId,
      p_badge_id: QUIZ_MASTER_3.badge_id,
      p_badge_name: QUIZ_MASTER_3.badge_name,
      p_icon_emoji: QUIZ_MASTER_3.icon_emoji,
      p_condition: QUIZ_MASTER_3.condition,
    });
    if (error) throw new Error(error.message);
    if (data === true) awarded.push(QUIZ_MASTER_3.badge_id);
  }

  if (providerSet.size > 0 && correctSet.size >= providerSet.size) {
    const { data, error } = await admin.rpc("award_ai_university_badge", {
      p_user_id: userId,
      p_badge_id: QUIZ_MASTER_ALL.badge_id,
      p_badge_name: QUIZ_MASTER_ALL.badge_name,
      p_icon_emoji: QUIZ_MASTER_ALL.icon_emoji,
      p_condition: QUIZ_MASTER_ALL.condition,
    });
    if (error) throw new Error(error.message);
    if (data === true) awarded.push(QUIZ_MASTER_ALL.badge_id);
  }

  return {
    correct_count: correctSet.size,
    total_providers: providerSet.size,
    awarded,
  };
}

async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("hub_data").select("id, metadata, created_at")
    .eq("source", source).filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false }).limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function _deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source).filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

async function callGemini(prompt: string, apiKey: string): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
    }
  );
  const data = await res.json() as { candidates?: [{ content: { parts: [{ text: string }] } }] };
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const body = req.method === "POST" ? await req.json() as Record<string, unknown> : {};
    const action = String(body.action ?? new URL(req.url).searchParams.get("action") ?? "");
    const userId = await getUserId(req);

    // Actions that require authentication
    const authRequired = [
      "secretary.task", "secretary.history",
      "summarize.text",
      "agent.list", "agent.create", "agent.run",
      "org.get",
      "my_agent.chat", "my_agent.history",
      "challenges.list",
      "trigger.analyze", "analyze.reality",
    ];
    if (authRequired.includes(action) && !userId) {
      return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      case "judgment.get": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const today = new Date().toLocaleDateString("ja-JP");
        const prompt = `今日${today}の自己成長・キャリア・健康に関するAI判定をしてください。JSON: {"score":0-100,"judgment":"良好/注意/警戒","advice":"...", "focus_area":"..."}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "search.query": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `検索クエリ「${body.query}」に対して、関連する情報を5件列挙してください。JSON: {"results":[{"title":"...","summary":"...","relevance":0-100}]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, query: body.query, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "tags.suggest": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `次のテキストに適切なタグを5つ提案してください: "${body.text}". JSON: {"tags":["tag1","tag2","tag3","tag4","tag5"]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          const parsed = JSON.parse(text.replace(/```json\n?|\n?```/g, ""));
          return json({ success: true, tags: parsed.tags ?? [] });
        } catch {
          return json({ success: true, tags: [] });
        }
      }

      case "secretary.task": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `あなたはAI秘書です。以下のタスクを処理してください: ${body.task ?? body.message ?? ""}. 返答はJSON: {"result":"...","actions":[],"priority":"high|medium|low"}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "secretary.history": {
        const items = await listItems(admin, "secretary_log", userId!);
        return json({ success: true, history: items });
      }

      case "summarize.text": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
        const text = String(body.text ?? "");
        if (!text) return json({ error: "text required" }, 400);
        if (geminiKey) {
          const prompt = `次のテキストを日本語で200字以内に要約してください:\n\n${text}`;
          const result = await callGemini(prompt, geminiKey);
          await addItem(admin, "summary_log", userId!, { original_length: text.length, summary: result });
          return json({ success: true, summary: result });
        }
        if (openaiKey) {
          const r = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: { Authorization: `Bearer ${openaiKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: `200字以内で要約: ${text}` }], max_tokens: 300 }),
          });
          const d = await r.json() as { choices?: [{ message: { content: string } }] };
          const summary = d.choices?.[0]?.message?.content ?? "";
          return json({ success: true, summary });
        }
        return json({ error: "No AI API key configured" }, 503);
      }

      case "agent.list": {
        const items = await listItems(admin, "agent_config", userId!);
        return json({ success: true, agents: items });
      }

      case "agent.create": {
        const item = await addItem(admin, "agent_config", userId!, {
          name: body.name,
          role: body.role ?? "assistant",
          department: body.department ?? "general",
          personality: body.personality ?? {},
          status: "active",
        });
        return json({ success: true, agent: item });
      }

      case "agent.run": {
        const item = await addItem(admin, "agent_run_log", userId!, {
          agent_id: body.agent_id,
          task: body.task,
          status: "queued",
        });
        return json({ success: true, run: item });
      }

      case "org.get": {
        const agents = await listItems(admin, "agent_config", userId!, 20);
        return json({ success: true, org: { agents, departments: ["CEO", "CMO", "CTO", "CFO", "COO"] } });
      }

      case "my_agent.chat": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const history = await listItems(admin, "my_agent_history", userId!, 10);
        const recentContext = history.map((h) => {
          const m = h.metadata as Record<string, unknown>;
          return `User: ${m.message}\nAgent: ${m.response}`;
        }).join("\n");
        const prompt = `あなたは個人AIエージェントです。${recentContext ? "履歴:\n" + recentContext + "\n\n" : ""}ユーザーメッセージ: ${body.message}`;
        const response = await callGemini(prompt, geminiKey);
        await addItem(admin, "my_agent_history", userId!, { message: body.message, response });
        return json({ success: true, response });
      }

      case "my_agent.history": {
        const items = await listItems(admin, "my_agent_history", userId!);
        return json({ success: true, history: items });
      }

      case "challenges.list": {
        const today = new Date().toISOString().split("T")[0];
        const existing = await listItems(admin, "daily_challenge", userId!, 3);
        if (existing.length > 0) return json({ success: true, challenges: existing });
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ success: true, challenges: [] });
        const prompt = `今日${today}のAI・生産性・健康に関するチャレンジを3つ生成してください。JSON: {"challenges":[{"id":"1","title":"...","description":"...","points":10,"category":"ai|productivity|health"}]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          const parsed = JSON.parse(text.replace(/```json\n?|\n?```/g, ""));
          for (const c of (parsed.challenges ?? [])) {
            await addItem(admin, "daily_challenge", userId!, { ...c as Record<string, unknown>, date: today });
          }
          return json({ success: true, challenges: parsed.challenges ?? [] });
        } catch {
          return json({ success: true, challenges: [] });
        }
      }

      case "trigger.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `行動トリガー分析: ${JSON.stringify(body)}. 引き金となる感情・状況・パターンを分析してください。JSON: {"triggers":[],"recommendations":[],"risk_level":"low|medium|high"}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "analyze.reality": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `現実分析: ${body.situation ?? ""}. 客観的な状況評価と改善策を提案してください。JSON: {"assessment":"...","score":0-100,"recommendations":[],"next_steps":[]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "election.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `選挙情勢分析: 地域=${body.region}, 候補者=${JSON.stringify(body.candidates ?? [])}. 勝率予測と戦略提案をしてください。JSON: {"predictions":[],"strategy":"...","key_issues":[]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "university.content": {
        const { data } = await admin.from("ai_university_content")
          .select("*")
          .eq("provider", String(body.provider ?? ""))
          .eq("category", String(body.category ?? "news"))
          .order("published_at", { ascending: false })
          .limit(10);
        return json({ success: true, content: data ?? [] });
      }

      case "university.upsert": {
        const { error } = await admin.from("ai_university_content").upsert(
          {
            provider: body.provider,
            category: body.category ?? "news",
            title: body.title,
            content: body.content,
            published_at: body.published_at ?? new Date().toISOString().split("T")[0],
          },
          { onConflict: "provider,category" }
        );
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "university.streak": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data: streak } = await admin.from("ai_university_streaks")
          .select("*")
          .eq("user_id", userId)
          .maybeSingle();
        return json({ success: true, streak: streak ?? null });
      }

      case "university.streak_update": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data, error } = await admin.rpc("update_ai_university_streak", {
          p_user_id: userId,
        });
        if (error) throw new Error(error.message);
        const row = Array.isArray(data) && data.length > 0
          ? data[0] as { current_streak?: number; longest_streak?: number; is_new_streak_day?: boolean }
          : null;
        return json({
          success: true,
          current_streak: row?.current_streak ?? 1,
          longest_streak: row?.longest_streak ?? 1,
          is_new_streak_day: row?.is_new_streak_day ?? true,
        });
      }

      case "university.badges": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data: badges } = await admin.from("ai_university_badges")
          .select("*")
          .eq("user_id", userId)
          .order("awarded_at", { ascending: false });
        return json({ success: true, badges: badges ?? [] });
      }

      case "university.award_badge": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const badgeId = asString(body.badge_id ?? body.badge_type);
        const badgeName = asString(body.badge_name);
        if (!badgeId || !badgeName) return json({ error: "badge_id and badge_name required" }, 400);
        const { data, error } = await admin.rpc("award_ai_university_badge", {
          p_user_id: userId,
          p_badge_id: badgeId,
          p_badge_name: badgeName,
          p_icon_emoji: asString(body.icon_emoji),
          p_condition: asString(body.condition) || null,
        });
        if (error) throw new Error(error.message);
        return json({ success: true, newly_awarded: data === true });
      }

      case "university.record_score": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const providerId = asString(body.provider_id);
        if (!providerId) return json({ error: "provider_id required" }, 400);

        const quizCorrect = body.quiz_correct === true;
        const now = new Date().toISOString();
        const { data: existing, error: existingErr } = await admin
          .from("ai_university_scores")
          .select("id, quiz_correct")
          .eq("user_id", userId)
          .eq("provider_id", providerId)
          .maybeSingle();
        if (existingErr) throw new Error(existingErr.message);

        const row = existing as { id?: string; quiz_correct?: boolean } | null;
        const wasCorrect = row?.quiz_correct === true;
        const isNewProvider = row == null;
        const newlyCorrect = !wasCorrect && quizCorrect;

        if (row?.id) {
          const { error } = await admin
            .from("ai_university_scores")
            .update({
              quiz_correct: wasCorrect || quizCorrect,
              studied_at: now,
            })
            .eq("id", row.id);
          if (error) throw new Error(error.message);
        } else {
          const { error } = await admin
            .from("ai_university_scores")
            .insert({
              user_id: userId,
              provider_id: providerId,
              quiz_correct: quizCorrect,
              studied_at: now,
            });
          if (error) throw new Error(error.message);
        }

        let awardedBadges: string[] = [];
        let correctCount = 0;
        let totalProviders = 0;
        if (newlyCorrect) {
          const evaluation = await evaluateUniversityQuizMaster(admin, userId);
          awardedBadges = evaluation.awarded;
          correctCount = evaluation.correct_count;
          totalProviders = evaluation.total_providers;
        }

        return json({
          success: true,
          is_new_provider: isNewProvider,
          newly_correct: newlyCorrect,
          awarded_badges: awardedBadges,
          correct_count: correctCount,
          total_providers: totalProviders,
        });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
