// Onboarding Flow Edge Function
// 新規ユーザーのオンボーディング管理
// - ステップ進捗管理
// - プロフィール完成度チェック
// - 初回設定ガイド
// - 競合からのインポート誘導
//
// GET  → オンボーディング進捗
// POST → ステップ完了 / スキップ

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

// オンボーディングステップ定義
const ONBOARDING_STEPS = [
  {
    key: "welcome",
    order: 1,
    title: "自分株式会社へようこそ",
    description: "21の競合サービスを超えるAI統合プラットフォームです",
    action: "次へ進む",
    required: true,
  },
  {
    key: "profile",
    order: 2,
    title: "プロフィールを設定",
    description: "表示名、アバター、自己紹介を設定しましょう",
    action: "プロフィール設定へ",
    link: "/profile",
    required: true,
  },
  {
    key: "first_note",
    order: 3,
    title: "最初のノートを作成",
    description: "AI がタグ提案や検索をサポートします",
    action: "ノートを作成",
    link: "/note-editor",
    required: false,
  },
  {
    key: "import",
    order: 4,
    title: "他サービスからインポート",
    description: "Notion, Evernote, MoneyForward 等からデータを移行できます",
    action: "インポート設定へ",
    link: "/import",
    required: false,
  },
  {
    key: "ai_assistant",
    order: 5,
    title: "AI アシスタントを試す",
    description: "AI 秘書に質問して、やるべきことを提案してもらいましょう",
    action: "AI 秘書へ",
    link: "/ai-secretary",
    required: false,
  },
  {
    key: "share",
    order: 6,
    title: "友達に紹介する",
    description: "リファラルで自分株式会社を広めましょう",
    action: "紹介リンクをコピー",
    required: false,
  },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        // 未ログイン: ステップ定義のみ返す
        return new Response(
          JSON.stringify({
            success: true,
            steps: ONBOARDING_STEPS,
            progress: { completed: 0, total: ONBOARDING_STEPS.length, percent: 0 },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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

      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      // ユーザーの完了済みステップを並列取得
      const [{ data: profile }, { count: noteCount }] = await Promise.all([
        adminClient
          .from("user_profiles")
          .select("onboarding_completed, display_name, avatar_url, bio")
          .eq("user_id", user.id)
          .single(),
        adminClient
          .from("notes")
          .select("*", { count: "exact", head: true })
          .eq("user_id", user.id),
      ]);

      // プロフィール完成度からステップを自動判定
      const completedSteps = new Set<string>();
      completedSteps.add("welcome"); // ログイン済み = welcome 完了

      if (profile?.display_name) completedSteps.add("profile");

      // ノート作成確認
      if ((noteCount ?? 0) > 0) completedSteps.add("first_note");

      // metadata のオンボーディング状態
      const onboardingData = (profile?.onboarding_completed ?? {}) as Record<string, boolean>;
      for (const [key, val] of Object.entries(onboardingData)) {
        if (val) completedSteps.add(key);
      }

      const stepsWithProgress = ONBOARDING_STEPS.map((step) => ({
        ...step,
        completed: completedSteps.has(step.key),
      }));

      const completedCount = stepsWithProgress.filter((s) => s.completed).length;
      const totalSteps = ONBOARDING_STEPS.length;

      return new Response(
        JSON.stringify({
          success: true,
          steps: stepsWithProgress,
          progress: {
            completed: completedCount,
            total: totalSteps,
            percent: Math.round((completedCount / totalSteps) * 100),
          },
          isComplete: completedCount === totalSteps,
          nextStep: stepsWithProgress.find((s) => !s.completed) ?? null,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
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

      const body = await req.json().catch(() => ({}));
      const { step_key } = body;

      if (!step_key) {
        return new Response(
          JSON.stringify({ success: false, error: "step_key is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      // 現在の onboarding_completed を取得して更新
      const { data: profile } = await adminClient
        .from("user_profiles")
        .select("onboarding_completed")
        .eq("user_id", user.id)
        .single();

      const current = (profile?.onboarding_completed ?? {}) as Record<string, boolean>;
      current[step_key] = true;

      const { error } = await adminClient
        .from("user_profiles")
        .update({
          onboarding_completed: current,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", user.id);

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, step: step_key, completed: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("onboarding-flow error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
