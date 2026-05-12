import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

// -----------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------

interface WeeklyDigestRequest {
  /** ISO date string for the END of the current week window (inclusive).
   *  Defaults to today. */
  endDate?: string;
}

interface ChannelMetrics {
  id: string;
  label: string;
  touches: number;
  signupSubmits: number;
  cvr: number; // 0-100 percent
  touchesDelta: number; // vs prior week (positive = up)
  signupSubmitsDelta: number;
}

interface WeeklyDigest {
  currentWeek: { startDate: string; endDate: string };
  priorWeek: { startDate: string; endDate: string };
  channels: ChannelMetrics[];
  importPreviews: { id: string; label: string; count: number; delta: number }[];
  signupSubmitTotal: number;
  signupSubmitDelta: number;
  referralsCompleted: number;
  referralsDelta: number;
  importCtaClicks: number;
  publicMemoCtaClicks: number;
  brief: string;
}

// -----------------------------------------------------------------------
// Serve
// -----------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST" && req.method !== "GET") {
      throw new Error("Method not allowed. Use GET or POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const url = new URL(req.url);
    const body = req.method === "GET"
      ? ({
        endDate: url.searchParams.get("endDate") ?? undefined,
      } as WeeklyDigestRequest)
      : (await req.json().catch(() => ({}))) as WeeklyDigestRequest;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { currentWeek, priorWeek } = buildWeekRanges(body.endDate);

    // ---- Fetch analytics rows for both windows -------------------------
    const [currentRows, priorRows, referralCurrent, referralPrior] =
      await Promise.all([
        fetchAnalyticsRows(admin, currentWeek.startDate, currentWeek.endDate),
        fetchAnalyticsRows(admin, priorWeek.startDate, priorWeek.endDate),
        fetchReferralCount(admin, currentWeek.startDate, currentWeek.endDate),
        fetchReferralCount(admin, priorWeek.startDate, priorWeek.endDate),
      ]);

    const currentCounts = aggregateSourceCounts(currentRows);
    const priorCounts = aggregateSourceCounts(priorRows);

    // ---- Channel metrics -----------------------------------------------
    const channelDefs = [
      {
        id: "landing",
        label: "ランディングページ",
        touch: "touch_landing",
        signup: "signup_submit_landing",
      },
      {
        id: "import",
        label: "インポート",
        touch: "touch_import",
        signup: "signup_submit_import",
      },
      {
        id: "public_memo",
        label: "公開メモ",
        touch: "touch_public_memo",
        signup: "signup_submit_public_memo",
      },
      {
        id: "referral",
        label: "紹介",
        touch: "touch_referral",
        signup: "signup_submit_referral",
      },
      {
        id: "comparison",
        label: "競合比較ページ",
        touch: "touch_comparison",
        signup: "signup_submit_comparison",
      },
      {
        id: "guitar",
        label: "ギタースタジオ",
        touch: "touch_guitar_gallery",
        signup: "signup_submit_guitar",
      },
    ];

    const channels: ChannelMetrics[] = channelDefs.map((def) => {
      const touches = currentCounts[def.touch] ?? 0;
      const signupSubmits = currentCounts[def.signup] ?? 0;
      const priorTouches = priorCounts[def.touch] ?? 0;
      const priorSignups = priorCounts[def.signup] ?? 0;
      return {
        id: def.id,
        label: def.label,
        touches,
        signupSubmits,
        cvr: touches > 0 ? Math.round((signupSubmits / touches) * 100) : 0,
        touchesDelta: touches - priorTouches,
        signupSubmitsDelta: signupSubmits - priorSignups,
      };
    });

    // ---- Import preview breakdown --------------------------------------
    const importPreviewDefs = [
      { id: "notion", label: "Notion", key: "import_preview_notion" },
      { id: "evernote", label: "Evernote", key: "import_preview_evernote" },
      { id: "markdown", label: "Markdown", key: "import_preview_markdown" },
    ];
    const importPreviews = importPreviewDefs.map((def) => ({
      id: def.id,
      label: def.label,
      count: currentCounts[def.key] ?? 0,
      delta: (currentCounts[def.key] ?? 0) - (priorCounts[def.key] ?? 0),
    }));

    // ---- Totals --------------------------------------------------------
    const signupSubmitTotal = channels.reduce(
      (sum, c) => sum + c.signupSubmits,
      0,
    );
    const priorSignupTotal = channelDefs.reduce(
      (sum, def) => sum + (priorCounts[def.signup] ?? 0),
      0,
    );

    const digest: WeeklyDigest = {
      currentWeek,
      priorWeek,
      channels,
      importPreviews,
      signupSubmitTotal,
      signupSubmitDelta: signupSubmitTotal - priorSignupTotal,
      referralsCompleted: referralCurrent,
      referralsDelta: referralCurrent - referralPrior,
      importCtaClicks: currentCounts["import_signup_cta"] ?? 0,
      publicMemoCtaClicks: currentCounts["public_memo_signup_cta"] ?? 0,
      brief: buildBrief({
        currentWeek,
        channels,
        importPreviews,
        signupSubmitTotal,
        signupSubmitDelta: signupSubmitTotal - priorSignupTotal,
        referralsCompleted: referralCurrent,
        referralsDelta: referralCurrent - referralPrior,
      }),
    };

    return jsonResponse({ success: true, digest });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

function buildWeekRanges(endDateInput: string | undefined) {
  const end = endDateInput ? new Date(endDateInput) : (() => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  })();

  const currentStart = new Date(end);
  currentStart.setDate(end.getDate() - 6);

  const priorEnd = new Date(currentStart);
  priorEnd.setDate(currentStart.getDate() - 1);

  const priorStart = new Date(priorEnd);
  priorStart.setDate(priorEnd.getDate() - 6);

  return {
    currentWeek: {
      startDate: fmt(currentStart),
      endDate: fmt(end),
    },
    priorWeek: {
      startDate: fmt(priorStart),
      endDate: fmt(priorEnd),
    },
  };
}

async function fetchAnalyticsRows(
  admin: AdminClient,
  startDate: string,
  endDate: string,
): Promise<Array<Record<string, unknown>>> {
  const result = await admin
    .from("app_analytics")
    .select("date, source_details")
    .gte("date", startDate)
    .lte("date", endDate);
  if (result.error) {
    throw result.error;
  }
  return result.data ?? [];
}

async function fetchReferralCount(
  admin: AdminClient,
  startDate: string,
  endDate: string,
): Promise<number> {
  const result = await admin
    .from("referrals")
    .select("id", { count: "exact", head: true })
    .eq("status", "completed")
    .gte("completed_at", `${startDate}T00:00:00.000Z`)
    .lte("completed_at", `${endDate}T23:59:59.999Z`);
  if (result.error) {
    // Referrals table may not exist in all environments; treat as 0.
    return 0;
  }
  return result.count ?? 0;
}

function aggregateSourceCounts(
  rows: Array<Record<string, unknown>>,
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) {
    const sourceDetails = toMap(row["source_details"]);
    for (const [key, rawValue] of Object.entries(sourceDetails)) {
      const value = toNumber(rawValue);
      if (value <= 0) continue;
      counts[key] = (counts[key] ?? 0) + value;
    }
  }
  return counts;
}

function buildBrief({
  currentWeek,
  channels,
  importPreviews,
  signupSubmitTotal,
  signupSubmitDelta,
  referralsCompleted,
  referralsDelta,
}: {
  currentWeek: { startDate: string; endDate: string };
  channels: ChannelMetrics[];
  importPreviews: { id: string; label: string; count: number; delta: number }[];
  signupSubmitTotal: number;
  signupSubmitDelta: number;
  referralsCompleted: number;
  referralsDelta: number;
}): string {
  const arrow = (n: number) =>
    n > 0 ? `↑${n}` : n < 0 ? `↓${Math.abs(n)}` : "→";
  const lines: string[] = [
    `## 自分株式会社 週次 Growth Digest`,
    `期間: ${currentWeek.startDate} ～ ${currentWeek.endDate}`,
    ``,
    `### サインアップ CTA クリック 合計: ${signupSubmitTotal} ${
      arrow(signupSubmitDelta)
    }`,
    ``,
    `### チャネル別`,
  ];

  for (const ch of channels) {
    lines.push(
      `- **${ch.label}**: タッチ ${ch.touches}${
        arrow(ch.touchesDelta)
      } / CTA ${ch.signupSubmits}${
        arrow(ch.signupSubmitsDelta)
      } / CVR ${ch.cvr}%`,
    );
  }

  lines.push(``);
  lines.push(`### インポートプレビュー`);
  for (const ip of importPreviews) {
    lines.push(`- ${ip.label}: ${ip.count} ${arrow(ip.delta)}`);
  }

  lines.push(``);
  lines.push(
    `### リファラル成立: ${referralsCompleted} ${arrow(referralsDelta)}`,
  );

  lines.push(``);
  lines.push(
    `> 前週比: CTA ${arrow(signupSubmitDelta)} / referral ${
      arrow(referralsDelta)
    }`,
  );

  return lines.join("\n");
}

function fmt(date: Date): string {
  const y = String(date.getFullYear()).padStart(4, "0");
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
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

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
