// growth-acquisition — Signal 記録 + レポート生成 (統合EF)
//
// 旧: growth-acquisition-signal + growth-acquisition-report を action パラメーター分岐で統合
// Tier 1 スロット: 2本 → 1本 (PowerShell版が deploy-prod.yml を更新して正式移行)
//
// POST { action: "signal", signalKey, dateKey? }
//   → タッチポイント/コンバージョンシグナルを app_analytics に記録
//
// GET ?action=report&windowDays=30
// POST { action: "report", windowDays? }
//   → windowDays (7-90, default 30) 分のグロース獲得レポートを返す
//
// 対応シグナルキー:
//   touch_landing / touch_import / touch_public_memo / touch_referral
//   import_preview_notion / import_preview_evernote / import_preview_markdown
//   import_signup_cta / public_memo_signup_cta
//   signup_submit_landing / signup_submit_import / signup_submit_public_memo
//   signup_submit_referral

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SUPPORTED_SIGNALS = new Set([
  "touch_landing",
  "touch_import",
  "touch_public_memo",
  "touch_referral",
  "import_preview_notion",
  "import_preview_evernote",
  "import_preview_markdown",
  "import_signup_cta",
  "public_memo_signup_cta",
  "signup_submit_landing",
  "signup_submit_import",
  "signup_submit_public_memo",
  "signup_submit_referral",
]);

const TOUCHPOINT_DEFS = [
  { id: "landing", label: "Landing", touchSignal: "touch_landing", signupSignal: "signup_submit_landing" },
  { id: "import", label: "Import", touchSignal: "touch_import", signupSignal: "signup_submit_import" },
  { id: "public_memo", label: "Public memo", touchSignal: "touch_public_memo", signupSignal: "signup_submit_public_memo" },
  { id: "referral", label: "Referral", touchSignal: "touch_referral", signupSignal: "signup_submit_referral" },
  { id: "comparison", label: "Comparison page", touchSignal: "touch_comparison", signupSignal: "signup_submit_comparison" },
  { id: "guitar", label: "Guitar gallery", touchSignal: "touch_guitar_gallery", signupSignal: "signup_submit_guitar" },
] as const;

const IMPORT_PREVIEW_DEFS = [
  { id: "notion", label: "Notion previews", signalKey: "import_preview_notion" },
  { id: "evernote", label: "Evernote previews", signalKey: "import_preview_evernote" },
  { id: "markdown", label: "Markdown previews", signalKey: "import_preview_markdown" },
] as const;

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeDateKey(value: string | undefined): string {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  }
  return value;
}

function normalizeWindowDays(value: number | undefined): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(7, Math.min(90, Math.trunc(value)));
  }
  return 30;
}

function buildDateRange(windowDays: number) {
  const endDate = new Date();
  endDate.setHours(0, 0, 0, 0);
  const startDate = new Date(endDate);
  startDate.setDate(startDate.getDate() - (windowDays - 1));
  const fmt = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  return { startDate: fmt(startDate), endDate: fmt(endDate) };
}

function toMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function normalizeSourceDetails(value: unknown): Record<string, number> {
  const raw = toMap(value);
  const result: Record<string, number> = {};
  for (const [key, v] of Object.entries(raw)) {
    const n = toNumber(v);
    if (n > 0) result[key] = n;
  }
  return result;
}

function aggregateSourceCounts(rows: Array<Record<string, unknown>>): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) {
    for (const [key, rawValue] of Object.entries(toMap(row.source_details))) {
      const value = toNumber(rawValue);
      if (value > 0) counts[key] = (counts[key] ?? 0) + value;
    }
  }
  return counts;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
    return jsonResponse({ success: false, error: "misconfigured" }, 500);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // deno-lint-ignore no-explicit-any
  let body: any = {};
  let action: string | null = null;

  if (req.method === "GET") {
    const url = new URL(req.url);
    action = url.searchParams.get("action") ?? "report";
    body = { windowDays: url.searchParams.get("windowDays") ? Number(url.searchParams.get("windowDays")) : undefined };
  } else if (req.method === "POST") {
    body = await req.json().catch(() => ({}));
    action = body.action ?? null;
  } else {
    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  }

  // ── action: signal ────────────────────────────────────────────────────────
  if (action === "signal") {
    const signalKey = String(body.signalKey ?? "").trim();
    const dateKey = normalizeDateKey(body.dateKey);

    if (!signalKey || !SUPPORTED_SIGNALS.has(signalKey)) {
      return jsonResponse({ success: false, error: "signalKey is required and must be supported." }, 400);
    }

    try {
      const { data: existing, error: fetchErr } = await admin
        .from("app_analytics")
        .select("date, source_details")
        .eq("date", dateKey)
        .maybeSingle();

      if (fetchErr) throw fetchErr;

      if (!existing) {
        const { error: upsertErr } = await admin.from("app_analytics").upsert({
          date: dateKey,
          landing_views: 0,
          conversions: 0,
          share_count: 0,
          source_details: { [signalKey]: 1 },
        });
        if (upsertErr) throw upsertErr;
      } else {
        const sourceDetails = normalizeSourceDetails(existing.source_details);
        sourceDetails[signalKey] = (sourceDetails[signalKey] ?? 0) + 1;
        const { error: updateErr } = await admin
          .from("app_analytics")
          .update({ source_details: sourceDetails })
          .eq("date", dateKey);
        if (updateErr) throw updateErr;
      }

      return jsonResponse({ success: true, signalKey, dateKey });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return jsonResponse({ success: false, error: message }, 400);
    }
  }

  // ── action: report (default) ──────────────────────────────────────────────
  if (action === "report" || action === null) {
    const windowDays = normalizeWindowDays(body.windowDays);
    const dateRange = buildDateRange(windowDays);

    try {
      const { data, error } = await admin
        .from("app_analytics")
        .select("date, source_details")
        .gte("date", dateRange.startDate)
        .lte("date", dateRange.endDate)
        .order("date", { ascending: true });

      if (error) throw error;

      const sourceCounts = aggregateSourceCounts(data ?? []);

      const touchpoints = TOUCHPOINT_DEFS.map((def) => ({
        id: def.id,
        label: def.label,
        touchCount: sourceCounts[def.touchSignal] ?? 0,
        signupSubmitCount: sourceCounts[def.signupSignal] ?? 0,
      }));

      const importPreviews = IMPORT_PREVIEW_DEFS.map((def) => ({
        id: def.id,
        label: def.label,
        previewCount: sourceCounts[def.signalKey] ?? 0,
      }));

      return jsonResponse({
        success: true,
        report: {
          windowDays,
          startDate: dateRange.startDate,
          endDate: dateRange.endDate,
          touchpoints,
          importPreviews,
          importSignupCtaCount: sourceCounts["import_signup_cta"] ?? 0,
          publicMemoSignupCtaCount: sourceCounts["public_memo_signup_cta"] ?? 0,
        },
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return jsonResponse({ success: false, error: message }, 400);
    }
  }

  return jsonResponse({ success: false, error: `Unknown action: ${action}` }, 400);
});
