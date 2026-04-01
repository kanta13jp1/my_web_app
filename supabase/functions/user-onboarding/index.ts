// User Onboarding Flow Edge Function
// ユーザーオンボーディング (Notion/Slack/Discord競合)
// - ステップ管理
// - 進捗追跡
// - チュートリアル
// - ウェルカムチェックリスト
// - 完了率分析

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const ONBOARDING_STEPS = [
  { id: "profile", order: 1, title: "プロフィール設定", description: "名前とアバターを設定しましょう", action: "プロフィールページへ" },
  { id: "first_note", order: 2, title: "最初のメモを作成", description: "メモ機能を試してみましょう", action: "メモ作成" },
  { id: "ai_chat", order: 3, title: "AIアシスタントと会話", description: "AIに質問してみましょう", action: "AI チャットへ" },
  { id: "task_create", order: 4, title: "タスクを作成", description: "やるべきことを管理しましょう", action: "タスク作成" },
  { id: "explore_features", order: 5, title: "機能を探索", description: "ホーム画面から機能を探索しましょう", action: "ホームへ" },
  { id: "invite_friend", order: 6, title: "友達を招待", description: "紹介コードを共有しましょう", action: "紹介ページへ" },
];

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

      if (view === "progress") {
        const { data: progress } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "onboarding_progress").maybeSingle();
        const completedSteps = progress ? ((progress.metadata as Record<string, unknown>).completed_steps as string[]) ?? [] : [];
        return new Response(JSON.stringify({
          success: true,
          steps: ONBOARDING_STEPS.map((s) => ({ ...s, completed: completedSteps.includes(s.id) })),
          completedCount: completedSteps.length, totalSteps: ONBOARDING_STEPS.length,
          percent: Math.round((completedSteps.length / ONBOARDING_STEPS.length) * 100),
          isComplete: completedSteps.length >= ONBOARDING_STEPS.length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analytics") {
        const { data: allProgress } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "onboarding_progress");
        const stepCompletion: Record<string, number> = {};
        let totalComplete = 0;
        for (const p of allProgress ?? []) {
          const steps = ((p.metadata as Record<string, unknown>).completed_steps as string[]) ?? [];
          if (steps.length >= ONBOARDING_STEPS.length) totalComplete++;
          for (const s of steps) stepCompletion[s] = (stepCompletion[s] ?? 0) + 1;
        }
        const totalUsers = (allProgress ?? []).length;
        return new Response(JSON.stringify({
          success: true, analytics: {
            totalUsers, completedUsers: totalComplete, completionRate: totalUsers > 0 ? Math.round((totalComplete / totalUsers) * 100) : 0,
            stepBreakdown: ONBOARDING_STEPS.map((s) => ({ ...s, completions: stepCompletion[s.id] ?? 0, rate: totalUsers > 0 ? Math.round(((stepCompletion[s.id] ?? 0) / totalUsers) * 100) : 0 })),
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, steps: ONBOARDING_STEPS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "complete_step") {
        const { step_id } = body;
        if (!step_id) return new Response(JSON.stringify({ success: false, error: "step_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "onboarding_progress").maybeSingle();
        const completedSteps = existing ? [...((existing.metadata as Record<string, unknown>).completed_steps as string[]) ?? []] : [];
        if (!completedSteps.includes(step_id)) completedSteps.push(step_id);
        const isComplete = completedSteps.length >= ONBOARDING_STEPS.length;
        if (existing) {
          await adminClient.from("app_analytics").update({ metadata: { completed_steps: completedSteps, completed_at: isComplete ? new Date().toISOString() : null } })
            .eq("user_id", user.id).eq("source", "onboarding_progress");
        } else {
          await adminClient.from("app_analytics").insert({ user_id: user.id, source: "onboarding_progress", metadata: { completed_steps: completedSteps, completed_at: isComplete ? new Date().toISOString() : null }, created_at: new Date().toISOString() });
        }
        return new Response(JSON.stringify({ success: true, completedSteps, isComplete, percent: Math.round((completedSteps.length / ONBOARDING_STEPS.length) * 100) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "reset") {
        await adminClient.from("app_analytics").delete().eq("user_id", user.id).eq("source", "onboarding_progress");
        return new Response(JSON.stringify({ success: true, reset: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
