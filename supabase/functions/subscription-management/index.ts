// Subscription Management Edge Function
// サブスクリプション管理・プラン制御・利用量追跡
// - Free / Pro (¥480/月) / Premium (¥980/月) プラン管理
// - 利用量クォータ (ノート数、AI呼び出し、ストレージ)
// - プランアップグレード/ダウングレード
//
// GET  → プラン情報 / 利用量 / プラン一覧
// POST → プラン変更 / 利用量記録

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

// プラン定義
const PLANS = [
  {
    key: "free",
    label: "Free",
    price: 0,
    limits: { notes: 50, ai_calls: 10, storage_mb: 100, exports: 1 },
    features: ["基本メモ機能", "AI検索 (10回/月)", "公開メモ共有", "デイリーチャレンジ"],
  },
  {
    key: "pro",
    label: "Pro",
    price: 480,
    limits: { notes: 500, ai_calls: 100, storage_mb: 1000, exports: 10 },
    features: [
      "Free の全機能",
      "AI アシスタント (100回/月)",
      "データエクスポート (10回/月)",
      "A/B テスト参加",
      "優先サポート",
      "高度な分析ダッシュボード",
    ],
  },
  {
    key: "premium",
    label: "Premium",
    price: 980,
    limits: { notes: -1, ai_calls: -1, storage_mb: 10000, exports: -1 }, // -1 = 無制限
    features: [
      "Pro の全機能",
      "AI 呼び出し無制限",
      "ノート数無制限",
      "API アクセス",
      "Webhook 連携",
      "専用サポート",
      "カスタムブランディング",
    ],
  },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'plans' | 'my_plan' | 'usage' | 'revenue'

      if (view === "plans") {
        return new Response(
          JSON.stringify({ success: true, plans: PLANS }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "my_plan" || view === "usage") {
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

        // ユーザーのプラン情報を取得
        const { data: profile } = await adminClient
          .from("user_profiles")
          .select("subscription_plan, subscription_expires_at, metadata")
          .eq("user_id", user.id)
          .maybeSingle();

        const currentPlan = (profile?.subscription_plan as string) ?? "free";
        const planDef = PLANS.find((p) => p.key === currentPlan) ?? PLANS[0];

        if (view === "my_plan") {
          return new Response(
            JSON.stringify({
              success: true,
              plan: {
                key: currentPlan,
                label: planDef.label,
                price: planDef.price,
                features: planDef.features,
                expiresAt: profile?.subscription_expires_at ?? null,
              },
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // view === "usage"
        const now = new Date();
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

        const [notesRes, aiCallsRes, exportsRes] = await Promise.all([
          adminClient.from("notes").select("*", { count: "exact", head: true }).eq("user_id", user.id),
          adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("user_id", user.id).eq("source", "ai_call").gte("created_at", monthStart),
          adminClient.from("app_analytics").select("*", { count: "exact", head: true })
            .eq("user_id", user.id).eq("source", "data_export").gte("created_at", monthStart),
        ]);

        const usage = {
          notes: { used: notesRes.count ?? 0, limit: planDef.limits.notes },
          ai_calls: { used: aiCallsRes.count ?? 0, limit: planDef.limits.ai_calls },
          exports: { used: exportsRes.count ?? 0, limit: planDef.limits.exports },
        };

        return new Response(
          JSON.stringify({ success: true, plan: currentPlan, usage, period: monthStart }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "revenue") {
        // 管理者向け: service_role 認証チェック (完全一致)
        const serviceAuth = req.headers.get("Authorization");
        const bearerToken = serviceAuth?.replace(/^Bearer\s+/i, "") ?? "";
        if (!bearerToken || bearerToken !== SERVICE_ROLE_KEY) {
          return new Response(
            JSON.stringify({ error: "管理者権限が必要です" }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: profiles } = await adminClient
          .from("user_profiles")
          .select("subscription_plan");

        const planCounts: Record<string, number> = { free: 0, pro: 0, premium: 0 };
        for (const p of profiles ?? []) {
          const plan = (p.subscription_plan as string) ?? "free";
          planCounts[plan] = (planCounts[plan] ?? 0) + 1;
        }

        const mrr = (planCounts.pro ?? 0) * 480 + (planCounts.premium ?? 0) * 980;

        return new Response(
          JSON.stringify({
            success: true,
            revenue: { mrr, arr: mrr * 12, planCounts, totalUsers: (profiles ?? []).length },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト
      return new Response(
        JSON.stringify({ success: true, plans: PLANS, note: "Use ?view=plans|my_plan|usage|revenue" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

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

      if (action === "change_plan") {
        const { plan } = body;
        if (!plan || !PLANS.find((p) => p.key === plan)) {
          return new Response(
            JSON.stringify({ success: false, error: "Invalid plan. Use: free, pro, or premium" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 変更前のプランを取得
        const { data: currentProfile } = await adminClient
          .from("user_profiles")
          .select("subscription_plan")
          .eq("user_id", user.id)
          .maybeSingle();
        const previousPlan = (currentProfile?.subscription_plan as string) ?? "free";

        const expiresAt = plan === "free"
          ? null
          : new Date(Date.now() + 30 * 86400000).toISOString();

        const { error } = await adminClient
          .from("user_profiles")
          .update({
            subscription_plan: plan,
            subscription_expires_at: expiresAt,
          })
          .eq("user_id", user.id);

        if (error) throw error;

        // 変更ログ記録
        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "plan_change",
          metadata: { from: previousPlan, to: plan },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, newPlan: plan, expiresAt }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "record_usage") {
        const { type } = body; // 'ai_call' | 'export' etc.
        if (!type) {
          return new Response(
            JSON.stringify({ success: false, error: "type is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: type,
          metadata: { recorded_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, recorded: type }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("subscription-management error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
