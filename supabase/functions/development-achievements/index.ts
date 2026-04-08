import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

/** 期間文字列から since (ISO 8601) を計算して返す。全期間は null */
function calcSince(period: string): string | null {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  switch (period) {
    case "今日の実績": {
      return today.toISOString();
    }
    case "今週の実績": {
      const day = today.getDay(); // 0=Sun
      const diff = day === 0 ? 6 : day - 1; // Mon start
      const mon = new Date(today);
      mon.setDate(today.getDate() - diff);
      return mon.toISOString();
    }
    case "直近2週間の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 14);
      return d.toISOString();
    }
    case "今月の実績": {
      return new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
    }
    case "直近2ヶ月の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 60);
      return d.toISOString();
    }
    case "直近3ヶ月の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 90);
      return d.toISOString();
    }
    case "直近半年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 180);
      return d.toISOString();
    }
    case "直近1年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 365);
      return d.toISOString();
    }
    case "直近2年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 730);
      return d.toISOString();
    }
    case "直近3年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 1095);
      return d.toISOString();
    }
    case "直近5年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 1825);
      return d.toISOString();
    }
    case "直近10年の実績": {
      const d = new Date(today);
      d.setDate(d.getDate() - 3650);
      return d.toISOString();
    }
    default:
      return null; // すべての実績
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Support both GET query params and POST JSON body
    const url = new URL(req.url);
    const isGet = req.method === "GET";
    const body = isGet
      ? ({} as Record<string, unknown>)
      : (await req.json().catch(() => ({}))) as Record<string, unknown>;

    const getParam = (key: string): string | undefined =>
      isGet ? (url.searchParams.get(key) ?? undefined) : undefined;

    const action = (body.action as string | undefined) ?? getParam("action") ?? "get";
    const periodParam = (body.period as string | undefined) ?? getParam("period");
    const limitParam = Number((body.limit as number | undefined) ?? getParam("limit") ?? 200);
    const offsetParam = Number((body.offset as number | undefined) ?? getParam("offset") ?? 0);

    // ---- ADD ----
    if (action === "add") {
      const title = String(body.title ?? "").trim();
      if (!title) {
        return jsonResponse({ error: "title is required" }, 400);
      }
      // Allow caller to specify a custom completed_at date (e.g. seed scripts)
      const completedAt = body.completed_at
        ? new Date(body.completed_at as string).toISOString()
        : new Date().toISOString();
      const description = String(body.description ?? "").trim() || null;
      const { error } = await admin
        .from("development_achievements")
        .insert({ title, description, completed_at: completedAt });
      if (error) throw new Error(error.message);
      return jsonResponse({ success: true, title, description, completed_at: completedAt });
    }

    // ---- GET ----
    const period = periodParam ?? "すべての実績";
    const since = calcSince(period);
    const limitVal = Math.min(limitParam, 500);
    const offsetVal = offsetParam;

    let query = admin
      .from("development_achievements")
      .select("title, description, completed_at")
      .order("completed_at", { ascending: false })
      .range(offsetVal, offsetVal + limitVal - 1);

    if (since !== null) {
      query = query.gte("completed_at", since);
    }

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    return jsonResponse({ achievements: data ?? [], period, offset: offsetVal, limit: limitVal });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: message, achievements: [] }, 500);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
