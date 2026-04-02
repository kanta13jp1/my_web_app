// Customer Feedback & NPS Edge Function
// 顧客フィードバック・NPS管理 (Slack/Intercom競合)
// - フィードバック収集
// - NPS (Net Promoter Score) 調査
// - 感情分析
// - フィードバック分類
// - トレンド分析

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const FEEDBACK_CATEGORIES = ["feature_request", "bug_report", "ux_issue", "performance", "praise", "complaint", "suggestion", "question"];
const SENTIMENT_LEVELS = ["very_negative", "negative", "neutral", "positive", "very_positive"];
const FEEDBACK_CHANNELS = ["in_app", "email", "twitter", "support_ticket", "survey", "review"];

function analyzeSentiment(text: string): { sentiment: string; score: number } {
  const positiveWords = ["良い", "素晴らしい", "便利", "使いやすい", "great", "good", "love", "excellent", "amazing", "helpful", "awesome"];
  const negativeWords = ["悪い", "使いにくい", "バグ", "エラー", "遅い", "bad", "terrible", "broken", "slow", "frustrating", "awful", "hate"];
  let score = 0;
  const lower = text.toLowerCase();
  for (const w of positiveWords) if (lower.includes(w)) score++;
  for (const w of negativeWords) if (lower.includes(w)) score--;
  if (score >= 2) return { sentiment: "very_positive", score: 5 };
  if (score >= 1) return { sentiment: "positive", score: 4 };
  if (score <= -2) return { sentiment: "very_negative", score: 1 };
  if (score <= -1) return { sentiment: "negative", score: 2 };
  return { sentiment: "neutral", score: 3 };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: FEEDBACK_CATEGORIES, sentiments: SENTIMENT_LEVELS, channels: FEEDBACK_CHANNELS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "nps") {
        const { data: responses } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "nps_response");
        const scores = (responses ?? []).map((r) => ((r.metadata as Record<string, unknown>).score as number) ?? 0);
        const promoters = scores.filter((s) => s >= 9).length;
        const detractors = scores.filter((s) => s <= 6).length;
        const total = scores.length;
        const npsScore = total > 0 ? Math.round(((promoters - detractors) / total) * 100) : 0;
        return new Response(JSON.stringify({
          success: true, nps: {
            score: npsScore, totalResponses: total,
            promoters, passives: total - promoters - detractors, detractors,
            avgScore: total > 0 ? Math.round((scores.reduce((a, b) => a + b, 0) / total) * 10) / 10 : 0,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "trends") {
        const days = parseInt(url.searchParams.get("days") ?? "30", 10);
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const { data: feedback } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "customer_feedback").gte("created_at", since)
          .order("created_at", { ascending: true });
        const dailyMap = new Map<string, { positive: number; negative: number; neutral: number }>();
        for (const f of feedback ?? []) {
          const date = (f.created_at as string)?.slice(0, 10) ?? "unknown";
          if (!dailyMap.has(date)) dailyMap.set(date, { positive: 0, negative: 0, neutral: 0 });
          const d = dailyMap.get(date)!;
          const sentiment = ((f.metadata as Record<string, unknown>).sentiment as string) ?? "neutral";
          if (sentiment.includes("positive")) d.positive++;
          else if (sentiment.includes("negative")) d.negative++;
          else d.neutral++;
        }
        return new Response(JSON.stringify({
          success: true,
          trends: [...dailyMap.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([date, data]) => ({ date, ...data })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: feedback } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "customer_feedback");
        const catCount: Record<string, number> = {};
        const sentCount: Record<string, number> = {};
        for (const f of feedback ?? []) {
          const m = f.metadata as Record<string, unknown>;
          const c = (m.category as string) ?? "other";
          const s = (m.sentiment as string) ?? "neutral";
          catCount[c] = (catCount[c] ?? 0) + 1;
          sentCount[s] = (sentCount[s] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true, stats: {
            totalFeedback: (feedback ?? []).length,
            categoryBreakdown: catCount, sentimentBreakdown: sentCount,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: recent feedback
      const { data: feedback } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "customer_feedback")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({ success: true, feedback: (feedback ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "submit_feedback") {
        const { message, category, channel, rating } = body;
        if (!message) return new Response(JSON.stringify({ success: false, error: "message required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const feedbackId = crypto.randomUUID();
        const sentimentResult = analyzeSentiment(message);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "customer_feedback",
          metadata: {
            feedback_id: feedbackId, message, category: category ?? "suggestion",
            channel: channel ?? "in_app", rating: rating ?? null,
            sentiment: sentimentResult.sentiment, sentiment_score: sentimentResult.score,
            status: "new", response: null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, feedbackId, sentiment: sentimentResult }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "submit_nps") {
        const { score, comment } = body;
        if (score === undefined || score < 0 || score > 10) return new Response(JSON.stringify({ success: false, error: "score (0-10) required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const responseId = crypto.randomUUID();
        const category = score >= 9 ? "promoter" : score >= 7 ? "passive" : "detractor";
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "nps_response",
          metadata: { response_id: responseId, score, comment: comment ?? "", category },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, responseId, category }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "respond_feedback") {
        const { feedback_id, response } = body;
        if (!feedback_id || !response) return new Response(JSON.stringify({ success: false, error: "feedback_id and response required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "customer_feedback").eq("metadata->>feedback_id", feedback_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Feedback not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({
          metadata: { ...(existing.metadata as Record<string, unknown>), status: "responded", response, responded_at: new Date().toISOString() },
        }).eq("source", "customer_feedback").eq("metadata->>feedback_id", feedback_id);
        return new Response(JSON.stringify({ success: true, responded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
