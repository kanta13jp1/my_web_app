export const AI_INVESTMENT_TREND_SOURCE = "ai_investment_trend";

export const VERIFICATION_STATUSES = [
  "needs_verification",
  "verified",
  "rejected",
] as const;

export type VerificationStatus = (typeof VERIFICATION_STATUSES)[number];

export const VERIFICATION_LABELS: Record<VerificationStatus, string> = {
  needs_verification: "要検証",
  verified: "確認済み",
  rejected: "却下",
};

export type RawFeedFormat =
  | "rss_item"
  | "structured_json"
  | "normalized_fallback";

export interface NormalizedInvestmentRecord {
  company_name: string;
  quarter: string;
  round_stage: string;
  amount_display: string;
  amount_usd_millions: number | null;
  currency: string;
  announced_at: string;
  source_name: string;
  source_url: string;
  investors: string[];
  summary: string;
  target_provider_category: string;
  raw_format: RawFeedFormat;
  dedup_key: string;
  verification_status: "needs_verification";
  verification_label: "要検証";
  requires_manual_verification: true;
  verified_at: null;
  verified_by: null;
  verification_note: string;
  is_sample_template: boolean;
  ingested_at: string;
}

export interface NormalizeRecordOptions {
  defaultQuarter?: string;
  defaultSourceName?: string;
  ingestedAt?: string;
  isSampleTemplate?: boolean;
  rawFormatHint?: RawFeedFormat;
}

export interface NormalizeBatchResult {
  records: NormalizedInvestmentRecord[];
  errors: Array<{ index: number; reason: string }>;
}

export interface PublicInvestmentFeedSpec {
  id: string;
  sourceName: string;
  url: string;
}

export interface FeedCollectionStatus {
  id: string;
  source_name: string;
  url: string;
  status: "fetched" | "unavailable";
  item_count: number;
  error?: string;
}

export interface FeedCollectionReport {
  collected_at: string;
  quarter_focus: string;
  feed_statuses: FeedCollectionStatus[];
  records: NormalizedInvestmentRecord[];
}

const MAX_COMPANY_LEN = 120;
const MAX_STAGE_LEN = 64;
const MAX_AMOUNT_DISPLAY_LEN = 64;
const MAX_SOURCE_NAME_LEN = 120;
const MAX_URL_LEN = 500;
const MAX_SUMMARY_LEN = 1000;
const MAX_INVESTORS = 12;

export const DEFAULT_AI_INVESTMENT_FEEDS: readonly PublicInvestmentFeedSpec[] =
  [
    {
      id: "openai-news",
      sourceName: "OpenAI News RSS",
      url: "https://openai.com/news/rss.xml",
    },
    {
      id: "google-ai-blog",
      sourceName: "Google AI Blog RSS",
      url: "https://blog.google/technology/ai/rss/",
    },
    {
      id: "huggingface-blog",
      sourceName: "Hugging Face Blog RSS",
      url: "https://huggingface.co/blog/feed.xml",
    },
  ];

function asRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function pickString(
  obj: Record<string, unknown>,
  keys: readonly string[],
  maxLen: number,
): string {
  for (const key of keys) {
    const val = obj[key];
    if (typeof val === "string" && val.trim().length > 0) {
      return val.trim().slice(0, maxLen);
    }
  }
  return "";
}

export function sanitizeHttpUrl(raw: unknown): string {
  if (typeof raw !== "string") return "";
  const trimmed = raw.trim().slice(0, MAX_URL_LEN);
  if (!trimmed) return "";
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return "";
    }
    return parsed.toString();
  } catch {
    return "";
  }
}

function normalizeDateIso(raw: unknown): string {
  if (typeof raw !== "string" || raw.trim().length === 0) return "";
  const parsed = new Date(raw.trim());
  if (Number.isNaN(parsed.getTime())) return "";
  return parsed.toISOString();
}

export function inferQuarterFromIso(isoDate: string): string {
  if (!isoDate) return "";
  const parsed = new Date(isoDate);
  if (Number.isNaN(parsed.getTime())) return "";
  const year = parsed.getUTCFullYear();
  const month = parsed.getUTCMonth() + 1;
  const q = Math.floor((month - 1) / 3) + 1;
  return `${year}-Q${q}`;
}

function normalizeQuarter(raw: unknown, announcedIso: string): string {
  if (typeof raw === "string") {
    const cleaned = raw.trim().toUpperCase().replace(/\s+/g, "");
    const m = /^(\d{4})-?Q([1-4])$/.exec(cleaned);
    if (m) return `${m[1]}-Q${m[2]}`;
  }
  const fromDate = inferQuarterFromIso(announcedIso);
  if (fromDate) return fromDate;
  return "unspecified";
}

function parseFiniteMillions(obj: Record<string, unknown>): number | null {
  const rawM = obj.amount_usd_millions ?? obj.amountMillionsUsd;
  if (typeof rawM === "number" && Number.isFinite(rawM) && rawM >= 0) {
    return Math.round(rawM * 100) / 100;
  }
  if (typeof rawM === "string" && /^\d+(?:\.\d+)?$/.test(rawM.trim())) {
    const parsed = Number(rawM.trim());
    if (Number.isFinite(parsed) && parsed >= 0) {
      return Math.round(parsed * 100) / 100;
    }
  }
  const rawUsd = obj.amount_usd ?? obj.amountUsd;
  if (typeof rawUsd === "number" && Number.isFinite(rawUsd) && rawUsd >= 0) {
    return Math.round((rawUsd / 1_000_000) * 100) / 100;
  }
  return null;
}

function parseInvestors(raw: unknown): string[] {
  const items: string[] = [];
  if (Array.isArray(raw)) {
    for (const entry of raw) {
      if (typeof entry === "string" && entry.trim()) {
        items.push(entry.trim().slice(0, 80));
      } else {
        const obj = asRecord(entry);
        const name = obj ? pickString(obj, ["name", "firm", "label"], 80) : "";
        if (name) items.push(name);
      }
    }
  } else if (typeof raw === "string" && raw.trim()) {
    for (const part of raw.split(/[,、;]/)) {
      const cleaned = part.trim().slice(0, 80);
      if (cleaned) items.push(cleaned);
    }
  }
  return Array.from(new Set(items)).slice(0, MAX_INVESTORS);
}

function inferCompanyFromTitle(title: string): string {
  const cleaned = title.trim();
  if (!cleaned) return "";
  const fundingVerb =
    /^(.{2,60}?)\s+(?:raises|secures|announces|closes|lands|bags)\b/i.exec(
      cleaned,
    );
  if (fundingVerb) return fundingVerb[1].trim().slice(0, MAX_COMPANY_LEN);
  const colonIdx = cleaned.indexOf(":");
  if (colonIdx > 1 && colonIdx <= 60) {
    return cleaned.slice(0, colonIdx).trim().slice(0, MAX_COMPANY_LEN);
  }
  return cleaned.slice(0, MAX_COMPANY_LEN);
}

function inferStageFromText(text: string): string {
  const patterns: readonly [RegExp, string][] = [
    [/\bseries\s+[a-f]\+?\b/i, "Series"],
    [/\bseed\b/i, "Seed"],
    [/\bstrategic\b/i, "Strategic"],
    [/\bacquisition\b|\bm&a\b/i, "M&A"],
    [/\bipo\b/i, "IPO"],
    [/\bpartnership\b/i, "Partnership"],
  ];
  for (const [regex, label] of patterns) {
    const match = regex.exec(text);
    if (match) {
      return label === "Series"
        ? match[0].replace(/\s+/g, " ").trim()
        : label;
    }
  }
  return "未分類";
}

function detectFormat(
  obj: Record<string, unknown>,
  hint?: RawFeedFormat,
): RawFeedFormat {
  if (hint) return hint;
  if ("pubDate" in obj || "isoDate" in obj || "link" in obj) {
    return "rss_item";
  }
  if ("company_name" in obj && ("round_stage" in obj || "amount_usd" in obj)) {
    return "structured_json";
  }
  return "normalized_fallback";
}

export function buildDedupKey(
  companyName: string,
  quarter: string,
  roundStage: string,
  sourceUrl: string,
): string {
  const slug = (v: string) =>
    v.trim().toLowerCase().replace(/[^a-z0-9\u3040-\u30ff\u4e00-\u9faf]+/g, "-")
      .replace(/^-+|-+$/g, "");
  const parts = [
    slug(companyName) || "unknown",
    slug(quarter) || "unspecified",
    slug(roundStage) || "unclassified",
  ];
  if (sourceUrl) {
    parts.push(slug(sourceUrl).slice(-40));
  }
  return parts.join("::");
}

/**
 * Normalizes heterogeneous investment feed entries into a unified schema and
 * unconditionally forces `verification_status: "needs_verification"` (`要検証`).
 */
export function normalizeInvestmentRecord(
  raw: unknown,
  opts: NormalizeRecordOptions = {},
): NormalizedInvestmentRecord {
  const obj = asRecord(raw);
  if (!obj) {
    throw new Error("Investment entry must be a JSON object");
  }

  const title = pickString(obj, ["title", "headline"], 200);
  const explicitCompany = pickString(
    obj,
    ["company_name", "company", "organization", "org", "startup", "vendor"],
    MAX_COMPANY_LEN,
  );
  const companyName = explicitCompany || inferCompanyFromTitle(title);
  if (!companyName) {
    throw new Error("company_name or title is required");
  }

  const announcedAt = normalizeDateIso(
    obj.announced_at ??
      obj.announcement_date ??
      obj.published_at ??
      obj.pubDate ??
      obj.isoDate ??
      obj.updated ??
      obj.date,
  );

  const quarter = normalizeQuarter(
    obj.quarter ?? opts.defaultQuarter,
    announcedAt,
  );

  const summary = pickString(
    obj,
    ["summary", "description", "notes", "contentSnippet", "content"],
    MAX_SUMMARY_LEN,
  ) || title;

  const roundStage = pickString(
    obj,
    ["round_stage", "round", "stage", "funding_round", "deal_type"],
    MAX_STAGE_LEN,
  ) || inferStageFromText(`${title} ${summary}`);

  const amountUsdMillions = parseFiniteMillions(obj);
  const rawAmountDisplay = pickString(
    obj,
    ["amount_display", "amount_text", "amount", "funding_amount"],
    MAX_AMOUNT_DISPLAY_LEN,
  );
  const amountDisplay = rawAmountDisplay ||
    (amountUsdMillions !== null
      ? `$${amountUsdMillions}M`
      : "金額未記載（要確認）");

  const currency = pickString(obj, ["currency"], 12).toUpperCase() || "USD";
  const sourceName = pickString(
    obj,
    ["source_name", "source", "publisher", "feed_title"],
    MAX_SOURCE_NAME_LEN,
  ) || (opts.defaultSourceName ?? "不明ソース");
  const sourceUrl = sanitizeHttpUrl(
    obj.source_url ?? obj.url ?? obj.link ?? obj.href,
  );
  const investors = parseInvestors(
    obj.investors ?? obj.lead_investors ?? obj.backers,
  );
  const targetCategory = pickString(
    obj,
    ["target_provider_category", "provider_category", "sector", "category"],
    64,
  ) || "LLM / AIインフラ";

  const rawFormat = detectFormat(obj, opts.rawFormatHint);
  const ingestedAt = opts.ingestedAt ?? new Date().toISOString();
  const isSampleTemplate = Boolean(
    opts.isSampleTemplate ?? obj.is_sample_template ?? false,
  );
  const dedupKey = buildDedupKey(companyName, quarter, roundStage, sourceUrl);

  // Financial/investment entries must always enter in "needs_verification"
  // regardless of any status flags injected in upstream payloads.
  return {
    company_name: companyName,
    quarter,
    round_stage: roundStage,
    amount_display: amountDisplay,
    amount_usd_millions: amountUsdMillions,
    currency,
    announced_at: announcedAt,
    source_name: sourceName,
    source_url: sourceUrl,
    investors,
    summary,
    target_provider_category: targetCategory,
    raw_format: rawFormat,
    dedup_key: dedupKey,
    verification_status: "needs_verification",
    verification_label: VERIFICATION_LABELS.needs_verification,
    requires_manual_verification: true,
    verified_at: null,
    verified_by: null,
    verification_note: "",
    is_sample_template: isSampleTemplate,
    ingested_at: ingestedAt,
  };
}

export function normalizeInvestmentBatch(
  rawItems: readonly unknown[],
  opts: NormalizeRecordOptions = {},
): NormalizeBatchResult {
  const records: NormalizedInvestmentRecord[] = [];
  const errors: Array<{ index: number; reason: string }> = [];
  for (let i = 0; i < rawItems.length; i += 1) {
    try {
      records.push(normalizeInvestmentRecord(rawItems[i], opts));
    } catch (err) {
      errors.push({
        index: i,
        reason: err instanceof Error ? err.message : String(err),
      });
    }
  }
  return { records, errors };
}

function decodeXmlEntities(text: string): string {
  return text
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function extractTag(block: string, tagName: string): string {
  const re = new RegExp(
    `<${tagName}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tagName}>`,
    "i",
  );
  const match = re.exec(block);
  return match ? decodeXmlEntities(match[1]) : "";
}

function extractAtomLink(block: string): string {
  const linkTag =
    /<link\b[^>]*\bhref=["']([^"']+)["'][^>]*\/?>/i.exec(block);
  if (linkTag) return linkTag[1].trim();
  return extractTag(block, "link");
}

const INVESTMENT_TERMS = [
  String.raw`rais(?:e|es|ed|ing)`,
  String.raw`fund(?:s|ed|ing)`,
  String.raw`invest(?:s|ed|ing|ment)`,
  String.raw`series\s+[a-f]`,
  String.raw`seed\s+round`,
  "valuation",
  String.raw`acquir(?:e|es|ed)`,
  "venture",
  "capital",
  "billion",
  "million",
].join("|");

const INVESTMENT_KEYWORDS = new RegExp(
  `(?:\\b(?:${INVESTMENT_TERMS})\\b|\\$\\d+|資金調達|出資|投資|評価額)`,
  "i",
);

export function parseRssOrAtomFeed(
  xmlText: string,
  opts: {
    sourceName: string;
    filterInvestmentRelevant?: boolean;
    ingestedAt?: string;
    maxItems?: number;
  },
): NormalizedInvestmentRecord[] {
  const blocks: string[] = [];
  const itemRe = /<(?:item|entry)\b[^>]*>([\s\S]*?)<\/(?:item|entry)>/gi;
  let match: RegExpExecArray | null;
  while ((match = itemRe.exec(xmlText)) !== null) {
    blocks.push(match[1]);
    if (blocks.length >= (opts.maxItems ?? 30)) break;
  }

  const results: NormalizedInvestmentRecord[] = [];
  for (const block of blocks) {
    const title = extractTag(block, "title");
    const summary = extractTag(block, "description") ||
      extractTag(block, "summary") ||
      extractTag(block, "content");
    if (
      opts.filterInvestmentRelevant &&
      !INVESTMENT_KEYWORDS.test(`${title} ${summary}`)
    ) {
      continue;
    }
    const link = extractAtomLink(block);
    const pubDate = extractTag(block, "pubDate") ||
      extractTag(block, "published") ||
      extractTag(block, "updated");
    if (!title && !summary) continue;

    results.push(
      normalizeInvestmentRecord(
        {
          title,
          summary,
          link,
          pubDate,
          source_name: opts.sourceName,
        },
        {
          defaultSourceName: opts.sourceName,
          ingestedAt: opts.ingestedAt,
          rawFormatHint: "rss_item",
        },
      ),
    );
  }
  return results;
}

export async function collectPublicInvestmentFeeds(
  feeds: readonly PublicInvestmentFeedSpec[] = DEFAULT_AI_INVESTMENT_FEEDS,
  fetcher: typeof fetch = fetch,
  nowIso: string = new Date().toISOString(),
): Promise<FeedCollectionReport> {
  const feedStatuses: FeedCollectionStatus[] = [];
  const records: NormalizedInvestmentRecord[] = [];
  const seenKeys = new Set<string>();

  for (const feed of feeds) {
    try {
      const resp = await fetcher(feed.url, {
        headers: {
          Accept: "application/rss+xml, application/atom+xml, application/xml",
          "User-Agent": "my-web-app-ai-investment-collector/1.0",
        },
      });
      if (!resp.ok) {
        feedStatuses.push({
          id: feed.id,
          source_name: feed.sourceName,
          url: feed.url,
          status: "unavailable",
          item_count: 0,
          error: `HTTP ${resp.status}`,
        });
        continue;
      }
      const body = await resp.text();
      const parsed = parseRssOrAtomFeed(body, {
        sourceName: feed.sourceName,
        filterInvestmentRelevant: true,
        ingestedAt: nowIso,
      });
      let added = 0;
      for (const rec of parsed) {
        if (seenKeys.has(rec.dedup_key)) continue;
        seenKeys.add(rec.dedup_key);
        records.push(rec);
        added += 1;
      }
      feedStatuses.push({
        id: feed.id,
        source_name: feed.sourceName,
        url: feed.url,
        status: "fetched",
        item_count: added,
      });
    } catch (err) {
      feedStatuses.push({
        id: feed.id,
        source_name: feed.sourceName,
        url: feed.url,
        status: "unavailable",
        item_count: 0,
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  return {
    collected_at: nowIso,
    quarter_focus: "2026-Q2",
    feed_statuses: feedStatuses,
    records,
  };
}

export function renderCollectionMarkdown(report: FeedCollectionReport): string {
  const lines = [
    "# 2026Q2 AI企業投資動向 収集レポート",
    "",
    `- 収集時刻 (UTC): ${report.collected_at}`,
    `- 対象四半期フォーカス: ${report.quarter_focus}`,
    `- 正規化レコード数: ${report.records.length} (全件初期ステータス: 要検証 / needs_verification)`,
    "",
    "## フィード取得状況",
    "",
    "| ソース | 状態 | 抽出件数 | 備考 |",
    "|--------|------|----------|------|",
  ];
  for (const st of report.feed_statuses) {
    const icon = st.status === "fetched" ? "OK" : "unavailable";
    lines.push(
      `| ${st.source_name} | ${icon} | ${st.item_count} | ${st.error ?? "-"} |`,
    );
  }
  if (report.records.length > 0) {
    lines.push(
      "",
      "## 抽出候補一覧（全件 要検証）",
      "",
      "| 企業/見出し | 四半期 | ラウンド | 金額表示 | ステータス |",
      "|------------|--------|----------|----------|------------|",
    );
    for (const rec of report.records.slice(0, 20)) {
      const safeCo = rec.company_name.replace(/\|/g, "/");
      const safeAmt = rec.amount_display.replace(/\|/g, "/");
      lines.push(
        `| ${safeCo} | ${rec.quarter} | ${rec.round_stage} | ${safeAmt} | ${rec.verification_label} |`,
      );
    }
  }
  return `${lines.join("\n")}\n`;
}

if (import.meta.main) {
  let outJson = "";
  let outMd = "";
  for (let i = 0; i < Deno.args.length; i += 1) {
    if (Deno.args[i] === "--out-json" && Deno.args[i + 1]) {
      outJson = Deno.args[i + 1];
      i += 1;
    } else if (Deno.args[i] === "--out-md" && Deno.args[i + 1]) {
      outMd = Deno.args[i + 1];
      i += 1;
    }
  }
  const report = await collectPublicInvestmentFeeds();
  const md = renderCollectionMarkdown(report);
  if (outJson) {
    const idx = outJson.lastIndexOf("/");
    if (idx > 0) {
      await Deno.mkdir(outJson.slice(0, idx), { recursive: true });
    }
    await Deno.writeTextFile(outJson, JSON.stringify(report, null, 2));
  }
  if (outMd) {
    const idx = outMd.lastIndexOf("/");
    if (idx > 0) {
      await Deno.mkdir(outMd.slice(0, idx), { recursive: true });
    }
    await Deno.writeTextFile(outMd, md);
  }
  console.log(md);
}
