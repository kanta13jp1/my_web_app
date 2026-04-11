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
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("app_analytics").select("id, metadata, created_at")
    .eq("source", source).filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false }).limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("app_analytics")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function _deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("app_analytics")
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
        await admin.from("ai_university_streaks").upsert(
          {
            user_id: userId,
            current_streak: body.current_streak ?? 1,
            max_streak: body.max_streak ?? 1,
            last_studied_at: new Date().toISOString(),
          },
          { onConflict: "user_id" }
        );
        return json({ success: true });
      }

      case "university.badges": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data: badges } = await admin.from("ai_university_badges")
          .select("*")
          .eq("user_id", userId)
          .order("earned_at", { ascending: false });
        return json({ success: true, badges: badges ?? [] });
      }

      case "university.award_badge": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        await admin.from("ai_university_badges").insert({
          user_id: userId,
          badge_type: body.badge_type,
          badge_name: body.badge_name,
          earned_at: new Date().toISOString(),
        });
        return json({ success: true });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
