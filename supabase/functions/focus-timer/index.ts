// Focus Timer Edge Function
// 集中タイマー・フォーカスモード (Forest/Focusmate競合)
// - ポモドーロセッション記録・統計
// - 集中目標設定・達成トラッキング
// - ブロック中サイト/アプリの記録
// - 週次集中スコア算出
//
// GET  → セッション履歴 / 統計 / 集中スコア
// POST → セッション開始 / 完了 / キャンセル / 目標設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(req.url);
    const action = req.method === "GET" ? (url.searchParams.get("action") ?? "stats") : "post";

    if (action === "stats") {
      const days = parseInt(url.searchParams.get("days") ?? "7", 10);
      const since = new Date(Date.now() - days * 86400000).toISOString();
      const { data: sessions } = await userClient
        .from("focus_sessions")
        .select("*")
        .eq("user_id", user.id)
        .gte("started_at", since)
        .order("started_at", { ascending: false });

      const completed = (sessions ?? []).filter((s: { status?: string }) => s.status === "completed");
      const totalMinutes = completed.reduce((sum: number, s: { duration_minutes?: number }) => sum + (s.duration_minutes ?? 25), 0);
      const streak = _calculateStreak(sessions ?? []);

      return new Response(JSON.stringify({
        success: true,
        sessions: sessions ?? [],
        stats: {
          total_sessions: (sessions ?? []).length,
          completed_sessions: completed.length,
          total_minutes: totalMinutes,
          streak_days: streak,
          focus_score: Math.min(100, Math.round((completed.length / Math.max(1, days * 4)) * 100)),
        },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const body = await req.json().catch(() => ({}));

    if (body.action === "start") {
      const { data, error } = await userClient.from("focus_sessions").insert({
        user_id: user.id,
        task_label: body.task_label ?? "集中作業",
        duration_minutes: body.duration_minutes ?? 25,
        status: "active",
        started_at: new Date().toISOString(),
      }).select().single();
      if (error) throw error;
      return new Response(JSON.stringify({ success: true, session: data }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "complete") {
      const { error } = await userClient.from("focus_sessions").update({
        status: "completed",
        completed_at: new Date().toISOString(),
      }).eq("id", body.session_id).eq("user_id", user.id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "cancel") {
      const { error } = await userClient.from("focus_sessions").update({
        status: "cancelled",
        completed_at: new Date().toISOString(),
      }).eq("id", body.session_id).eq("user_id", user.id);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: false, error: "Unknown action" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function _calculateStreak(sessions: Array<{ started_at?: string; status?: string }>): number {
  const dates = sessions
    .filter((s) => s.status === "completed" && s.started_at)
    .map((s) => new Date(s.started_at!).toDateString());
  const unique = [...new Set(dates)];
  if (unique.length === 0) return 0;
  let streak = 0;
  const today = new Date();
  for (let i = 0; i < 30; i++) {
    const d = new Date(today);
    d.setDate(today.getDate() - i);
    if (unique.includes(d.toDateString())) {
      streak++;
    } else if (i > 0) {
      break;
    }
  }
  return streak;
}
