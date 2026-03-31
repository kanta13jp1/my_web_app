// A/B Testing Manager Edge Function
// 機能実験・A/Bテスト管理
// - 実験の作成・管理・結果集計
// - ユーザーへのバリアント割り当て
// - コンバージョン記録・統計分析
//
// GET  → 実験一覧 / 結果 / ユーザーの割り当て
// POST → 実験作成 / バリアント割り当て / コンバージョン記録

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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'list' | 'results' | 'assignment'
      const experimentId = url.searchParams.get("experiment_id");

      if (view === "results" && experimentId) {
        // 実験結果の集計
        const { data: experiment } = await adminClient
          .from("ab_experiments")
          .select("*")
          .eq("id", experimentId)
          .single();

        if (!experiment) {
          return new Response(
            JSON.stringify({ success: false, error: "Experiment not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // バリアント別の参加者数・コンバージョン数を集計
        const { data: assignments } = await adminClient
          .from("ab_assignments")
          .select("variant, converted")
          .eq("experiment_id", experimentId);

        const variantStats = new Map<string, { participants: number; conversions: number }>();
        for (const a of assignments ?? []) {
          const v = a.variant as string;
          if (!variantStats.has(v)) variantStats.set(v, { participants: 0, conversions: 0 });
          const stat = variantStats.get(v)!;
          stat.participants++;
          if (a.converted) stat.conversions++;
        }

        const results = [...variantStats.entries()].map(([variant, stats]) => ({
          variant,
          ...stats,
          conversionRate: stats.participants > 0
            ? Math.round((stats.conversions / stats.participants) * 10000) / 100
            : 0,
        }));

        return new Response(
          JSON.stringify({ success: true, experiment, results }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "assignment") {
        // ユーザーの割り当て確認
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

        // アクティブな実験のユーザー割り当てを取得
        const { data: assignments } = await adminClient
          .from("ab_assignments")
          .select("experiment_id, variant, converted, created_at")
          .eq("user_id", user.id);

        return new Response(
          JSON.stringify({ success: true, assignments: assignments ?? [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: 実験一覧
      const status = url.searchParams.get("status"); // 'active' | 'completed' | 'draft'
      let query = adminClient
        .from("ab_experiments")
        .select("*")
        .order("created_at", { ascending: false });

      if (status) query = query.eq("status", status);

      const { data, error } = await query;
      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, experiments: data ?? [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        // 実験作成
        const { name, description, variants, target_metric } = body;

        if (!name || !variants || !Array.isArray(variants) || variants.length < 2) {
          return new Response(
            JSON.stringify({ success: false, error: "name and at least 2 variants are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("ab_experiments")
          .insert({
            name,
            description: description ?? "",
            variants,
            target_metric: target_metric ?? "conversion",
            status: "draft",
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, experiment: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "activate" || action === "complete") {
        // ステータス変更
        const { experiment_id } = body;
        if (!experiment_id) {
          return new Response(
            JSON.stringify({ success: false, error: "experiment_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const newStatus = action === "activate" ? "active" : "completed";
        const { data, error } = await adminClient
          .from("ab_experiments")
          .update({ status: newStatus, updated_at: new Date().toISOString() })
          .eq("id", experiment_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, experiment: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "assign") {
        // ユーザーをバリアントに割り当て
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

        const { experiment_id } = body;
        if (!experiment_id) {
          return new Response(
            JSON.stringify({ success: false, error: "experiment_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 既存割り当てを確認
        const { data: existing } = await adminClient
          .from("ab_assignments")
          .select("variant")
          .eq("experiment_id", experiment_id)
          .eq("user_id", user.id)
          .maybeSingle();

        if (existing) {
          return new Response(
            JSON.stringify({ success: true, variant: existing.variant, alreadyAssigned: true }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // 実験のバリアントを取得してランダム割り当て
        const { data: experiment } = await adminClient
          .from("ab_experiments")
          .select("variants, status")
          .eq("id", experiment_id)
          .single();

        if (!experiment || experiment.status !== "active") {
          return new Response(
            JSON.stringify({ success: false, error: "Experiment not found or not active" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const variants = experiment.variants as string[];
        const assigned = variants[Math.floor(Math.random() * variants.length)];

        const { data, error } = await adminClient
          .from("ab_assignments")
          .insert({
            experiment_id,
            user_id: user.id,
            variant: assigned,
            converted: false,
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, variant: assigned, assignment: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "convert") {
        // コンバージョン記録
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

        const { experiment_id } = body;
        if (!experiment_id) {
          return new Response(
            JSON.stringify({ success: false, error: "experiment_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("ab_assignments")
          .update({ converted: true, converted_at: new Date().toISOString() })
          .eq("experiment_id", experiment_id)
          .eq("user_id", user.id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, assignment: data }),
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
    console.error("ab-testing-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
