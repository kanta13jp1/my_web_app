import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const touchpointDefinitions = [
  {
    id: "landing",
    label: "Landing",
    touchSignal: "touch_landing",
    signupSignal: "signup_submit_landing",
  },
  {
    id: "import",
    label: "Import",
    touchSignal: "touch_import",
    signupSignal: "signup_submit_import",
  },
  {
    id: "public_memo",
    label: "Public memo",
    touchSignal: "touch_public_memo",
    signupSignal: "signup_submit_public_memo",
  },
  {
    id: "referral",
    label: "Referral",
    touchSignal: "touch_referral",
    signupSignal: "signup_submit_referral",
  },
  {
    id: "comparison",
    label: "Comparison page",
    touchSignal: "touch_comparison",
    signupSignal: "signup_submit_comparison",
  },
  {
    id: "guitar",
    label: "Guitar gallery",
    touchSignal: "touch_guitar_gallery",
    signupSignal: "signup_submit_guitar",
  },
] as const;

const importPreviewDefinitions = [
  {
    id: "notion",
    label: "Notion previews",
    signalKey: "import_preview_notion",
  },
  {
    id: "evernote",
    label: "Evernote previews",
    signalKey: "import_preview_evernote",
  },
  {
    id: "markdown",
    label: "Markdown previews",
    signalKey: "import_preview_markdown",
  },
] as const;

interface GrowthAcquisitionReportRequest {
  windowDays?: number;
}

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
        windowDays: url.searchParams.get("windowDays")
          ? Number(url.searchParams.get("windowDays"))
          : undefined,
      } as GrowthAcquisitionReportRequest)
      : (await req.json().catch(() => ({}))) as GrowthAcquisitionReportRequest;
    const windowDays = normalizeWindowDays(body.windowDays);
    const dateRange = buildDateRange(windowDays);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const analyticsRows = await admin
      .from("app_analytics")
      .select("date, source_details")
      .gte("date", dateRange.startDate)
      .lte("date", dateRange.endDate)
      .order("date", { ascending: true });
    if (analyticsRows.error) {
      throw analyticsRows.error;
    }

    const sourceCounts = aggregateSourceCounts(analyticsRows.data ?? []);

    const touchpoints = touchpointDefinitions.map((definition) => ({
      id: definition.id,
      label: definition.label,
      touchCount: sourceCounts[definition.touchSignal] ?? 0,
      signupSubmitCount: sourceCounts[definition.signupSignal] ?? 0,
    }));

    const importPreviews = importPreviewDefinitions.map((definition) => ({
      id: definition.id,
      label: definition.label,
      previewCount: sourceCounts[definition.signalKey] ?? 0,
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
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

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

  return {
    startDate: formatDateKey(startDate),
    endDate: formatDateKey(endDate),
  };
}

function formatDateKey(date: Date): string {
  const year = String(date.getFullYear()).padStart(4, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function aggregateSourceCounts(
  rows: Array<Record<string, unknown>>,
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) {
    const sourceDetails = toMap(row.source_details);
    for (const [key, rawValue] of Object.entries(sourceDetails)) {
      const value = toNumber(rawValue);
      if (value <= 0) {
        continue;
      }
      counts[key] = (counts[key] ?? 0) + value;
    }
  }
  return counts;
}

function toMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
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

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
