import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const memoId = Number.parseInt(url.searchParams.get("id") ?? "", 10);

    if (!Number.isFinite(memoId) || memoId <= 0) {
      return jsonResponse({ success: false, error: "Invalid memo id." }, 400);
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      return jsonResponse({ success: false, error: "Missing runtime env." }, 500);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data, error } = await admin
      .from("public_memos")
      .select("id, title, content, category, metadata")
      .eq("id", memoId)
      .eq("is_public", true)
      .maybeSingle();

    if (error) {
      throw error;
    }
    if (!data) {
      return jsonResponse({ success: false, error: "Memo not found." }, 404);
    }

    const title = data["title"]?.toString() ?? "Public memo";
    const content = data["content"]?.toString() ?? "";
    const category = data["category"]?.toString() ?? "";
    const metadata = asMap(data["metadata"]);
    const svg = metadata["type"] === "local_election_snapshot"
      ? buildElectionSvg({ title, category, metadata })
      : buildGenericSvg({ title, category, content });

    return new Response(new TextEncoder().encode(svg), {
      headers: {
        ...corsHeaders,
        "Content-Type": "image/svg+xml; charset=utf-8",
        "Cache-Control": "public, max-age=600",
      },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 500);
  }
});

function buildElectionSvg(args: {
  title: string;
  category: string;
  metadata: Record<string, unknown>;
}): string {
  const snapshotDate = args.metadata["snapshotDate"]?.toString() ?? "";
  const currentMembers = toInt(args.metadata["officialCurrentLocalMembers"]);
  const remaining = toInt(args.metadata["actualNetIncreaseRequired"]);
  const activePrefectures = toInt(args.metadata["activePrefectureCount"]);
  const missingCount = toInt(args.metadata["missingPrefectureCount"]);
  const lowCount = toInt(args.metadata["lowPresencePrefectureCount"]);
  const rosterCount = toInt(args.metadata["rosterCount"]);
  const topPrefectures = toArray(args.metadata["topPrefectures"])
    .slice(0, 4)
    .map((item) => asMap(item))
    .map((item) => {
      const prefecture = item["prefecture"]?.toString() ?? "";
      const count = toInt(item["currentMembers"]);
      return `${prefecture} ${count}`;
    });

  const topRows = topPrefectures.length > 0
    ? topPrefectures.map((row, index) =>
      `<text x="72" y="${438 + (index * 40)}" font-size="28" fill="#F8FAFC">${escapeXml(row)}</text>`)
      .join("\n")
    : `<text x="72" y="438" font-size="28" fill="#F8FAFC">No prefecture summary available</text>`;

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0F172A" />
      <stop offset="55%" stop-color="#0B3B60" />
      <stop offset="100%" stop-color="#14532D" />
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)" rx="32" />
  <rect x="48" y="42" width="1104" height="546" rx="28" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.14)" />
  <text x="72" y="102" font-size="24" fill="#BAE6FD" font-weight="700">${escapeXml(args.category || "Election memo")}</text>
  <text x="72" y="154" font-size="44" fill="#F8FAFC" font-weight="800">${escapeXml(limit(args.title, 32))}</text>
  <text x="72" y="194" font-size="22" fill="#CBD5E1">Snapshot ${escapeXml(snapshotDate)} / roster ${rosterCount}</text>

  <rect x="72" y="232" width="250" height="120" rx="22" fill="rgba(34,197,94,0.18)" stroke="rgba(34,197,94,0.32)" />
  <text x="96" y="274" font-size="22" fill="#BBF7D0">Local members</text>
  <text x="96" y="330" font-size="52" fill="#F0FDF4" font-weight="800">${currentMembers}</text>

  <rect x="348" y="232" width="250" height="120" rx="22" fill="rgba(248,113,113,0.18)" stroke="rgba(248,113,113,0.32)" />
  <text x="372" y="274" font-size="22" fill="#FECACA">Remaining to 700</text>
  <text x="372" y="330" font-size="52" fill="#FFF1F2" font-weight="800">${remaining}</text>

  <rect x="624" y="232" width="222" height="120" rx="22" fill="rgba(56,189,248,0.16)" stroke="rgba(56,189,248,0.32)" />
  <text x="648" y="274" font-size="22" fill="#BFDBFE">Active prefectures</text>
  <text x="648" y="330" font-size="52" fill="#EFF6FF" font-weight="800">${activePrefectures}</text>

  <rect x="872" y="232" width="248" height="120" rx="22" fill="rgba(250,204,21,0.16)" stroke="rgba(250,204,21,0.32)" />
  <text x="896" y="274" font-size="22" fill="#FEF08A">Risk prefectures</text>
  <text x="896" y="318" font-size="34" fill="#FEFCE8" font-weight="800">none ${missingCount} / low ${lowCount}</text>

  <text x="72" y="400" font-size="24" fill="#E2E8F0" font-weight="700">Top prefectures</text>
  ${topRows}

  <text x="72" y="590" font-size="20" fill="#94A3B8">Official prefecture counts and current roster snapshot</text>
</svg>`;
}

function buildGenericSvg(args: {
  title: string;
  category: string;
  content: string;
}): string {
  const plainText = args.content
    .replace(/#{1,6}\s+/g, "")
    .replace(/\*{1,2}(.+?)\*{1,2}/g, "$1")
    .replace(/`{1,3}[^`]*`{1,3}/g, "")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/\n+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  const titleLines = wrapText(limit(args.title, 56), 18, 2);
  const excerptLines = wrapText(
    limit(plainText || "Read the full public memo on Jibun Inc.", 180),
    30,
    5,
  );
  const titleSvg = titleLines
    .map((line, index) =>
      `<text x="88" y="${186 + (index * 62)}" font-size="54" fill="#F8FAFC" font-weight="800">${escapeXml(line)}</text>`)
    .join("\n");
  const excerptStartY = 328 + (Math.max(titleLines.length - 1, 0) * 52);
  const excerptSvg = excerptLines
    .map((line, index) =>
      `<text x="88" y="${excerptStartY + (index * 42)}" font-size="28" fill="#E5E7EB">${escapeXml(line)}</text>`)
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#111827" />
      <stop offset="100%" stop-color="#1D4ED8" />
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)" />
  <rect x="56" y="56" width="1088" height="518" rx="28" fill="rgba(255,255,255,0.08)" stroke="rgba(255,255,255,0.18)" />
  <text x="88" y="120" font-size="24" fill="#BFDBFE" font-weight="700">${escapeXml(args.category || "Public memo")}</text>
  ${titleSvg}
  ${excerptSvg}
  <text x="88" y="556" font-size="22" fill="#93C5FD">Jibun Inc. Public Memo</text>
</svg>`;
}

function asMap(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function toArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function toInt(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function limit(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }
  return `${value.slice(0, maxLength - 3)}...`;
}

function wrapText(
  value: string,
  maxCharsPerLine: number,
  maxLines: number,
): string[] {
  const words = value.split(/\s+/).filter((word) => word.trim().length > 0);
  if (words.length === 0) {
    return [""];
  }

  const lines: string[] = [];
  let currentLine = "";

  for (const word of words) {
    const nextLine = currentLine === "" ? word : `${currentLine} ${word}`;
    if (nextLine.length <= maxCharsPerLine) {
      currentLine = nextLine;
      continue;
    }

    if (currentLine !== "") {
      lines.push(currentLine);
    }
    currentLine = word;

    if (lines.length >= maxLines - 1) {
      break;
    }
  }

  if (lines.length < maxLines && currentLine !== "") {
    lines.push(currentLine);
  }

  return lines.slice(0, maxLines);
}

function escapeXml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
