// Horse Racing Predictor Edge Function
// 競馬予想・分析 (netkeiba競合)
// - 馬・騎手・コース情報管理
// - レース予想スコア計算
// - 回収率シミュレーション
// - 予想履歴・成績管理
//
// GET  → レース一覧 / 予想 / 馬データ / 成績統計
// POST → レース登録 / 予想記録 / 結果登録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const RACE_TYPES = ["芝", "ダート", "障害"];
const GRADES = ["G1", "G2", "G3", "リステッド", "オープン", "3勝", "2勝", "1勝", "未勝利", "新馬"];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "race_types") {
        return new Response(JSON.stringify({ success: true, raceTypes: RACE_TYPES, grades: GRADES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "predictions") {
        const raceId = url.searchParams.get("race_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "race_prediction")
          .order("created_at", { ascending: false });
        if (raceId) query = query.eq("metadata->>race_id", raceId);
        const { data: predictions } = await query.limit(50);
        return new Response(JSON.stringify({
          success: true,
          predictions: (predictions ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: predictions } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "race_prediction");
        let totalBets = 0, wins = 0, totalStake = 0, totalReturn = 0;
        for (const p of predictions ?? []) {
          const meta = p.metadata as Record<string, unknown>;
          totalBets++;
          totalStake += (meta.stake as number) ?? 0;
          if (meta.result === "win") {
            wins++;
            totalReturn += (meta.payout as number) ?? 0;
          }
        }
        return new Response(JSON.stringify({
          success: true,
          stats: {
            totalBets, wins, winRate: totalBets > 0 ? Math.round(wins / totalBets * 100) : 0,
            totalStake, totalReturn,
            roi: totalStake > 0 ? Math.round((totalReturn - totalStake) / totalStake * 100) : 0,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "horses") {
        const { data: horses } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "horse_data")
          .order("created_at", { ascending: false }).limit(100);
        return new Response(JSON.stringify({
          success: true,
          horses: (horses ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), createdAt: h.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analyze") {
        const raceId = url.searchParams.get("race_id");
        if (!raceId) {
          return new Response(JSON.stringify({ success: false, error: "race_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Get race entries
        const { data: entries } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "race_entry").eq("metadata->>race_id", raceId);
        // Score each entry
        const scored = (entries ?? []).map((e) => {
          const meta = e.metadata as Record<string, unknown>;
          // Simple scoring: recent_form * 3 + jockey_win_rate * 2 + trainer_win_rate + track_affinity
          const form = (meta.recent_form as number) ?? 5;
          const jockey = (meta.jockey_win_rate as number) ?? 10;
          const trainer = (meta.trainer_win_rate as number) ?? 10;
          const track = (meta.track_affinity as number) ?? 5;
          const score = form * 3 + jockey * 2 + trainer + track;
          return { ...meta, prediction_score: score };
        }).sort((a, b) => (b.prediction_score as number) - (a.prediction_score as number));

        return new Response(JSON.stringify({
          success: true, raceId,
          analysis: scored.map((s, i) => ({ ...s, rank: i + 1 })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: race list
      const { data: races } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "race_info")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({
        success: true,
        races: (races ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "register_race") {
        const { name, date, venue, race_type, grade, distance, entries } = body;
        if (!name || !date) {
          return new Response(JSON.stringify({ success: false, error: "name and date required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const raceId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "race_info",
          metadata: { race_id: raceId, name, date, venue: venue ?? null, race_type: race_type ?? "芝", grade: grade ?? "未勝利", distance: distance ?? 1600 },
          created_at: new Date().toISOString(),
        });
        // Register entries
        for (const entry of entries ?? []) {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "race_entry",
            metadata: { race_id: raceId, horse_name: entry.horse_name, number: entry.number, jockey: entry.jockey, trainer: entry.trainer, recent_form: entry.recent_form ?? 5, jockey_win_rate: entry.jockey_win_rate ?? 10, trainer_win_rate: entry.trainer_win_rate ?? 10, track_affinity: entry.track_affinity ?? 5, odds: entry.odds ?? 10 },
            created_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, raceId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "predict") {
        const { race_id, horse_name, bet_type, stake, confidence } = body;
        if (!race_id || !horse_name) {
          return new Response(JSON.stringify({ success: false, error: "race_id and horse_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const predId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "race_prediction",
          metadata: { prediction_id: predId, race_id, horse_name, bet_type: bet_type ?? "単勝", stake: stake ?? 100, confidence: confidence ?? 50, result: "pending", payout: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, predictionId: predId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_result") {
        const { prediction_id, result, payout } = body;
        if (!prediction_id || !result) {
          return new Response(JSON.stringify({ success: false, error: "prediction_id and result required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "race_prediction").eq("metadata->>prediction_id", prediction_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Prediction not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({
          metadata: { ...(existing.metadata as Record<string, unknown>), result, payout: payout ?? 0 },
        }).eq("user_id", user.id).eq("source", "race_prediction").eq("metadata->>prediction_id", prediction_id);
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
