// Poll & Survey Edge Function
// アンケート・投票機能 (Google Forms競合)
// - アンケート作成 (単一/複数選択/自由回答)
// - 投票・回答
// - 結果集計・グラフ用データ
//
// GET  → アンケート一覧 / 結果 / 詳細
// POST → 作成 / 回答

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
      const view = url.searchParams.get("view"); // 'results' | 'detail'
      const pollId = url.searchParams.get("poll_id");

      if (view === "results" && pollId) {
        const { data: responses } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "poll_response")
          .eq("metadata->>poll_id", pollId);

        const tally = new Map<string, number>();
        const freeTexts: string[] = [];
        for (const r of responses ?? []) {
          const meta = r.metadata as Record<string, unknown>;
          const answer = meta?.answer;
          if (typeof answer === "string") {
            if (meta?.question_type === "free_text") {
              freeTexts.push(answer);
            } else {
              tally.set(answer, (tally.get(answer) ?? 0) + 1);
            }
          } else if (Array.isArray(answer)) {
            for (const a of answer) {
              tally.set(a as string, (tally.get(a as string) ?? 0) + 1);
            }
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            pollId,
            totalResponses: (responses ?? []).length,
            tally: [...tally.entries()].map(([option, count]) => ({ option, count })).sort((a, b) => b.count - a.count),
            freeTexts: freeTexts.slice(0, 50),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "detail" && pollId) {
        const { data: poll } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "poll_definition")
          .eq("metadata->>poll_id", pollId)
          .maybeSingle();

        if (!poll) {
          return new Response(
            JSON.stringify({ success: false, error: "Poll not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        return new Response(
          JSON.stringify({ success: true, poll: { ...(poll.metadata as Record<string, unknown>), createdAt: poll.created_at } }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Poll list
      const { data: polls } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "poll_definition")
        .order("created_at", { ascending: false });

      return new Response(
        JSON.stringify({
          success: true,
          polls: (polls ?? []).map((p) => ({
            ...(p.metadata as Record<string, unknown>),
            createdAt: p.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        const { title, description, questions } = body;
        if (!title || !questions || !Array.isArray(questions) || questions.length === 0) {
          return new Response(
            JSON.stringify({ success: false, error: "title and questions[] required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const pollId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "poll_definition",
          metadata: {
            poll_id: pollId,
            title,
            description: description ?? "",
            questions, // [{question, type: 'single'|'multiple'|'free_text', options: [...]}]
            status: "active",
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, pollId, poll: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "respond") {
        const { poll_id, answers } = body;
        if (!poll_id || !answers || !Array.isArray(answers)) {
          return new Response(
            JSON.stringify({ success: false, error: "poll_id and answers[] required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Check if already responded
        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "poll_response")
          .eq("metadata->>poll_id", poll_id)
          .limit(1);

        if (existing && existing.length > 0) {
          return new Response(
            JSON.stringify({ success: false, error: "Already responded to this poll" }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Insert each answer as separate record for easy aggregation
        const inserts = answers.map((a: { question_index: number; answer: string | string[]; question_type?: string }) => ({
          user_id: user.id,
          source: "poll_response",
          metadata: {
            poll_id,
            question_index: a.question_index,
            answer: a.answer,
            question_type: a.question_type ?? "single",
          },
          created_at: new Date().toISOString(),
        }));

        const { error } = await adminClient.from("app_analytics").insert(inserts);
        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, responded: true, answersCount: answers.length }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("poll-survey error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
