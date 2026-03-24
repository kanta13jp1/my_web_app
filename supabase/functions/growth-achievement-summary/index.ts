import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

type AdminClient = any;

interface AchievementSummaryResponse {
  success: boolean;
  since: string;
  label: string;
  newUsers: number;
  acquisitionSignals: number;
  referralsCompleted: number;
  importPreviews: number;
  totalUsersEver: number;
  error?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new Error("Method not allowed.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const body = (await req.json().catch(() => ({}))) as {
      since?: string;
      label?: string;
    };

    // `since` は ISO 8601 文字列。省略時は全期間 (2020-01-01)
    const sinceStr = body.since ?? "2020-01-01T00:00:00Z";
    const label = body.label ?? "すべて";

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 並列クエリで各指標を集計
    const [
      usersResult,
      totalUsersResult,
      signalsResult,
      referralsResult,
      importsResult,
    ] = await Promise.all([
      // 期間内の新規ユーザー (user_profiles.created_at)
      admin
        .from("user_profiles")
        .select("user_id", { count: "exact", head: true })
        .gte("created_at", sinceStr),

      // 全期間ユーザー数 (累計)
      admin
        .from("user_profiles")
        .select("user_id", { count: "exact", head: true }),

      // 期間内の成長シグナル (app_analytics.created_at)
      admin
        .from("app_analytics")
        .select("id", { count: "exact", head: true })
        .gte("created_at", sinceStr),

      // 期間内の紹介成立
      admin
        .from("referrals")
        .select("id", { count: "exact", head: true })
        .gte("completed_at", sinceStr)
        .eq("status", "completed"),

      // 期間内のインポートプレビュー
      admin
        .from("app_analytics")
        .select("id", { count: "exact", head: true })
        .gte("created_at", sinceStr)
        .eq("source", "import_preview"),
    ]);

    const payload: AchievementSummaryResponse = {
      success: true,
      since: sinceStr,
      label,
      newUsers: usersResult.count ?? 0,
      acquisitionSignals: signalsResult.count ?? 0,
      referralsCompleted: referralsResult.count ?? 0,
      importPreviews: importsResult.count ?? 0,
      totalUsersEver: totalUsersResult.count ?? 0,
    };

    return jsonResponse(payload);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
