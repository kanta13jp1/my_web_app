// User Feedback Collector Edge Function
// ユーザーフィードバック収集・NPS・満足度調査
// - NPS (Net Promoter Score) 収集
// - 機能満足度評価
// - フリーテキストフィードバック
// - フィードバック集計・トレンド
//
// GET  → NPS スコア / フィードバック一覧 / トレンド
// POST → フィードバック送信

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
      const view = url.searchParams.get("view"); // 'nps' | 'list' | 'summary'

      if (view === "nps") {
        // NPS スコア算出
        const { data: npsData } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("source", "nps_feedback");

        let promoters = 0, passives = 0, detractors = 0;
        for (const d of npsData ?? []) {
          const score = (d.metadata as Record<string, unknown>)?.score as number;
          if (score >= 9) promoters++;
          else if (score >= 7) passives++;
          else detractors++;
        }

        const total = promoters + passives + detractors;
        const nps = total > 0 ? Math.round(((promoters - detractors) / total) * 100) : 0;

        return new Response(
          JSON.stringify({
            success: true,
            nps: { score: nps, promoters, passives, detractors, totalResponses: total },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "list") {
        // フィードバック一覧
        const { data: feedbacks } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .in("source", ["nps_feedback", "feature_feedback", "general_feedback"])
          .order("created_at", { ascending: false })
          .limit(50);

        return new Response(
          JSON.stringify({
            success: true,
            feedbacks: (feedbacks ?? []).map((f) => ({
              ...(f.metadata as Record<string, unknown>),
              userId: f.user_id,
              createdAt: f.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: サマリー
      const [npsRes, featureRes, generalRes] = await Promise.all([
        adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "nps_feedback"),
        adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "feature_feedback"),
        adminClient.from("app_analytics").select("*", { count: "exact", head: true }).eq("source", "general_feedback"),
      ]);

      return new Response(
        JSON.stringify({
          success: true,
          summary: {
            npsResponses: npsRes.count ?? 0,
            featureFeedbacks: featureRes.count ?? 0,
            generalFeedbacks: generalRes.count ?? 0,
            total: (npsRes.count ?? 0) + (featureRes.count ?? 0) + (generalRes.count ?? 0),
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { type } = body; // 'nps' | 'feature' | 'general'

      let userId = null;
      const authHeader = req.headers.get("Authorization");
      if (authHeader) {
        const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
          global: { headers: { Authorization: authHeader } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (user) userId = user.id;
      }

      if (type === "nps") {
        const { score, comment } = body;
        if (score === undefined || score < 0 || score > 10) {
          return new Response(
            JSON.stringify({ success: false, error: "score must be 0-10" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: userId,
          source: "nps_feedback",
          metadata: { score, comment: comment ?? "", type: "nps" },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, feedback: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (type === "feature") {
        const { feature_name, rating, comment } = body;
        if (!feature_name || !rating) {
          return new Response(
            JSON.stringify({ success: false, error: "feature_name and rating required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: userId,
          source: "feature_feedback",
          metadata: { feature_name, rating, comment: comment ?? "", type: "feature" },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, feedback: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (type === "general") {
        const { message, category } = body;
        if (!message) {
          return new Response(
            JSON.stringify({ success: false, error: "message required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: userId,
          source: "general_feedback",
          metadata: { message, category: category ?? "general", type: "general" },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, feedback: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "type must be nps, feature, or general" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("user-feedback-collector error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
