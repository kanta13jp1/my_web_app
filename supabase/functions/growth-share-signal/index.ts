import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

const supportedSignals = new Set([
  "public_memo_share",
  "public_memo_copy",
]);

interface GrowthShareSignalRequest {
  signalKey?: string;
  memoId?: number;
  dateKey?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as GrowthShareSignalRequest;
    const signalKey = body.signalKey?.trim();
    const memoId = toNumber(body.memoId);
    const dateKey = normalizeDateKey(body.dateKey);

    if (!signalKey || !supportedSignals.has(signalKey)) {
      throw new Error("signalKey is required and must be supported.");
    }

    const supabaseAdmin = createClient(
      SUPABASE_URL,
      SERVICE_ROLE_KEY,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const existing = await supabaseAdmin
      .from("app_analytics")
      .select("date, landing_views, conversions, share_count, source_details")
      .eq("date", dateKey)
      .maybeSingle();

    if (existing.error) {
      throw existing.error;
    }

    if (!existing.data) {
      const insertResult = await supabaseAdmin.from("app_analytics").upsert({
        date: dateKey,
        landing_views: 0,
        conversions: 0,
        share_count: 1,
        source_details: {
          [signalKey]: 1,
        },
      });
      if (insertResult.error) {
        throw insertResult.error;
      }
    } else {
      const row = toMap(existing.data);
      const sourceDetails = normalizeSourceDetails(row["source_details"]);
      sourceDetails[signalKey] = (sourceDetails[signalKey] ?? 0) + 1;

      const updateResult = await supabaseAdmin
        .from("app_analytics")
        .update({
          share_count: toNumber(row["share_count"]) + 1,
          source_details: sourceDetails,
        })
        .eq("date", dateKey);

      if (updateResult.error) {
        throw updateResult.error;
      }
    }

    return jsonResponse({
      success: true,
      signalKey,
      memoId,
      dateKey,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse(
      {
        success: false,
        error: message,
      },
      400,
    );
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeDateKey(value: string | undefined): string {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const now = new Date();
    return `${now.getFullYear()}-${
      String(now.getMonth() + 1).padStart(2, "0")
    }-${String(now.getDate()).padStart(2, "0")}`;
  }
  return value;
}

function toMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function normalizeSourceDetails(value: unknown): Record<string, number> {
  const raw = toMap(value);
  const normalized: Record<string, number> = {};
  for (const [key, entryValue] of Object.entries(raw)) {
    const count = toNumber(entryValue);
    if (count > 0) {
      normalized[key] = count;
    }
  }
  return normalized;
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}
