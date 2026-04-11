/**
 * ai-university-streaks — AI大学 連続学習ストリーク管理EF
 *
 * `update_ai_university_streak` RPC の薄いラッパー。
 * - 当日既に学習済みならスキップ
 * - 昨日学習していれば streak+1
 * - 2日以上空いていれば streak=1 にリセット
 *
 * POST { action: "update" }
 *   → 認証ユーザーのストリークを更新 (学習完了ボタン押下時に呼ぶ)
 *   返り値: { success, current_streak, longest_streak, is_new_streak_day }
 *
 * POST { action: "get" } / GET ?action=get
 *   → 認証ユーザーの現在のストリーク状態を取得
 *   返り値: { success, current_streak, longest_streak, last_studied_date }
 *
 * POST { action: "leaderboard", limit? } / GET ?action=leaderboard&limit=10
 *   → current_streak 降順 TOP N (公開ランキング / is_public 判定なし)
 *
 * 認証: 全 action で Supabase JWT (ANON_KEY + Authorization) 必須。
 * RLS: ai_university_streaks テーブルは auth.uid() = user_id の行のみ参照可能。
 * leaderboard は service_role で読み出し (auth.users.email は除外)。
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  if (SUPABASE_URL === "" || SUPABASE_ANON_KEY === "") {
    return json({ success: false, error: "misconfigured" }, 500);
  }

  // ── Parse action + params ────────────────────────────────────────────────
  let action = "";
  let params: Record<string, unknown> = {};

  if (req.method === "GET") {
    const url = new URL(req.url);
    action = url.searchParams.get("action") ?? "get";
    params = {
      limit: url.searchParams.get("limit") ?? undefined,
    };
  } else if (req.method === "POST") {
    try {
      params = await req.json();
    } catch {
      params = {};
    }
    action = asString(params.action) || "update";
  } else {
    return json({ success: false, error: "Method not allowed" }, 405);
  }

  // ── leaderboard: public read via service-role ────────────────────────────
  if (action === "leaderboard") {
    if (SERVICE_ROLE_KEY === "") {
      return json(
        { success: false, error: "leaderboard unavailable: service_role missing" },
        500,
      );
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const limit = Math.max(1, Math.min(100, asNumber(params.limit, 10)));

    try {
      const { data, error } = await admin
        .from("ai_university_streaks")
        .select("user_id, current_streak, longest_streak, last_studied_date")
        .order("current_streak", { ascending: false })
        .order("longest_streak", { ascending: false })
        .limit(limit);
      if (error) throw error;

      return json({
        success: true,
        leaderboard: (data ?? []).map((row, idx) => ({
          rank: idx + 1,
          user_id: (row as { user_id: string }).user_id,
          current_streak: (row as { current_streak: number }).current_streak,
          longest_streak: (row as { longest_streak: number }).longest_streak,
          last_studied_date:
            (row as { last_studied_date: string | null }).last_studied_date,
        })),
        count: (data ?? []).length,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return json({ success: false, error: message }, 500);
    }
  }

  // ── update / get: user-scoped with JWT ───────────────────────────────────
  const authHeader = req.headers.get("authorization") ?? "";
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: { user }, error: authError } = await client.auth.getUser();
  if (authError || !user) {
    return json({ success: false, error: "unauthorized" }, 401);
  }
  const userId = user.id;

  try {
    // ── action: update ───────────────────────────────────────────────────
    if (action === "update") {
      // SECURITY DEFINER RPC なので RLS をバイパスして確実に更新できる
      const { data, error } = await client.rpc("update_ai_university_streak", {
        p_user_id: userId,
      });
      if (error) throw error;

      // RPC は TABLE を返すので配列形式
      const row = Array.isArray(data) && data.length > 0
        ? (data[0] as Record<string, unknown>)
        : null;

      if (!row) {
        return json({
          success: true,
          current_streak: 1,
          longest_streak: 1,
          is_new_streak_day: true,
        });
      }

      return json({
        success: true,
        current_streak: asNumber(row.current_streak, 0),
        longest_streak: asNumber(row.longest_streak, 0),
        is_new_streak_day: Boolean(row.is_new_streak_day),
      });
    }

    // ── action: get ──────────────────────────────────────────────────────
    if (action === "get") {
      const { data, error } = await client
        .from("ai_university_streaks")
        .select("current_streak, longest_streak, last_studied_date, streak_updated_at")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw error;

      if (!data) {
        return json({
          success: true,
          current_streak: 0,
          longest_streak: 0,
          last_studied_date: null,
          streak_updated_at: null,
        });
      }

      const row = data as Record<string, unknown>;
      return json({
        success: true,
        current_streak: asNumber(row.current_streak, 0),
        longest_streak: asNumber(row.longest_streak, 0),
        last_studied_date: row.last_studied_date ?? null,
        streak_updated_at: row.streak_updated_at ?? null,
      });
    }

    return json(
      { success: false, error: `Unknown action: ${action}` },
      400,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ai-university-streaks error:", err);
    return json({ success: false, error: message }, 500);
  }
});
