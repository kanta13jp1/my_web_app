import {
  AI_INVESTMENT_TREND_SOURCE,
  normalizeInvestmentBatch,
  parseRssOrAtomFeed,
  sanitizeHttpUrl,
  VERIFICATION_LABELS,
  VERIFICATION_STATUSES,
  type NormalizedInvestmentRecord,
  type VerificationStatus,
} from "./ai_investment_ingestor.ts";

const MAX_INGEST_BATCH = 50;
const MAX_NOTE_LEN = 500;
const DEFAULT_LIMIT = 50;

export class AiInvestmentError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "AiInvestmentError";
    this.status = status;
  }
}

export interface HubDataRow {
  id: string;
  metadata: Record<string, unknown> | null;
  created_at?: string;
}

type DbError = {
  code?: string;
  message?: string;
};

type DbResult<T> = {
  data: T | null;
  error?: DbError | null;
};

export type HubQuery<T = unknown> = PromiseLike<DbResult<T>> & {
  select(columns: string): HubQuery<T>;
  insert(values: Record<string, unknown>): HubQuery<T>;
  update(values: Record<string, unknown>): HubQuery<T>;
  eq(column: string, value: unknown): HubQuery<T>;
  filter(column: string, operator: string, value: unknown): HubQuery<T>;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): HubQuery<T>;
  limit(count: number): HubQuery<T>;
  single(): PromiseLike<DbResult<T>>;
  maybeSingle(): PromiseLike<DbResult<T | null>>;
};

export interface AiInvestmentDb {
  from(table: string): unknown;
}

export interface FormattedInvestmentRecord {
  id: string;
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
  raw_format: string;
  dedup_key: string;
  verification_status: VerificationStatus;
  verification_label: string;
  requires_manual_verification: boolean;
  verified_at: string | null;
  verified_by: string | null;
  verification_note: string;
  is_sample_template: boolean;
  ingested_at: string;
  created_at: string;
  updated_at: string;
}

export interface InvestmentSummaryStats {
  total: number;
  needs_verification: number;
  verified: number;
  rejected: number;
  quarters: string[];
}

function asHubTable(admin: AiInvestmentDb): HubQuery<unknown> {
  return admin.from("hub_data") as HubQuery<unknown>;
}

function normalizeStatus(raw: unknown): VerificationStatus {
  const s = String(raw ?? "").trim();
  if ((VERIFICATION_STATUSES as readonly string[]).includes(s)) {
    return s as VerificationStatus;
  }
  return "needs_verification";
}

function formatRow(row: HubDataRow): FormattedInvestmentRecord {
  const meta = (row.metadata ?? {}) as Record<string, unknown>;
  const status = normalizeStatus(meta.verification_status);
  const rawInvestors = Array.isArray(meta.investors) ? meta.investors : [];
  const investors = rawInvestors
    .filter((v): v is string => typeof v === "string" && v.trim().length > 0)
    .map((v) => v.trim());
  const rawMillions = meta.amount_usd_millions;
  const amountUsdMillions =
    typeof rawMillions === "number" && Number.isFinite(rawMillions)
      ? rawMillions
      : null;

  return {
    id: row.id,
    company_name: String(meta.company_name ?? ""),
    quarter: String(meta.quarter ?? "unspecified"),
    round_stage: String(meta.round_stage ?? "未分類"),
    amount_display: String(meta.amount_display ?? "金額未記載（要確認）"),
    amount_usd_millions: amountUsdMillions,
    currency: String(meta.currency ?? "USD"),
    announced_at: String(meta.announced_at ?? ""),
    source_name: String(meta.source_name ?? ""),
    source_url: String(meta.source_url ?? ""),
    investors,
    summary: String(meta.summary ?? ""),
    target_provider_category: String(
      meta.target_provider_category ?? "LLM / AIインフラ",
    ),
    raw_format: String(meta.raw_format ?? "normalized_fallback"),
    dedup_key: String(meta.dedup_key ?? row.id),
    verification_status: status,
    verification_label: VERIFICATION_LABELS[status],
    requires_manual_verification: status === "needs_verification",
    verified_at: typeof meta.verified_at === "string" ? meta.verified_at : null,
    verified_by: typeof meta.verified_by === "string" ? meta.verified_by : null,
    verification_note: String(meta.verification_note ?? ""),
    is_sample_template: Boolean(meta.is_sample_template ?? false),
    ingested_at: String(meta.ingested_at ?? row.created_at ?? ""),
    created_at: row.created_at ?? "",
    updated_at: String(meta.updated_at ?? row.created_at ?? ""),
  };
}

function buildSummary(
  records: readonly FormattedInvestmentRecord[],
): InvestmentSummaryStats {
  let needsVerification = 0;
  let verified = 0;
  let rejected = 0;
  const quarterSet = new Set<string>();

  for (const rec of records) {
    if (rec.verification_status === "verified") {
      verified += 1;
    } else if (rec.verification_status === "rejected") {
      rejected += 1;
    } else {
      needsVerification += 1;
    }
    if (rec.quarter && rec.quarter !== "unspecified") {
      quarterSet.add(rec.quarter);
    }
  }

  return {
    total: records.length,
    needs_verification: needsVerification,
    verified,
    rejected,
    quarters: Array.from(quarterSet).sort().reverse(),
  };
}

async function fetchAllUserRecords(
  admin: AiInvestmentDb,
  userId: string,
  limit = DEFAULT_LIMIT,
): Promise<FormattedInvestmentRecord[]> {
  const safeLimit = Math.min(200, Math.max(1, Math.floor(limit)));
  const { data, error } = await asHubTable(admin)
    .select("id, metadata, created_at")
    .eq("source", AI_INVESTMENT_TREND_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(safeLimit);
  if (error) {
    throw new AiInvestmentError(
      error.message ?? "Failed to load AI investment records",
      500,
    );
  }
  const rows = (Array.isArray(data) ? data : []) as HubDataRow[];
  const formatted = rows.map(formatRow);
  formatted.sort((a, b) => {
    const keyA = a.announced_at || a.created_at;
    const keyB = b.announced_at || b.created_at;
    return keyB.localeCompare(keyA);
  });
  return formatted;
}

function buildTemplateStarters(nowIso: string): Array<Record<string, unknown>> {
  return [
    {
      company_name: "テンプレート例A: フロンティアLLM基盤企業",
      quarter: "2026-Q2",
      round_stage: "Late Stage (要確認)",
      amount_display: "要確認（一次公式発表未入力）",
      announced_at: "2026-04-15T00:00:00.000Z",
      source_name: "テンプレート初期項目（要一次情報照合）",
      source_url: "",
      investors: ["要確認"],
      summary:
        "2026Q2 LLMプロバイダー投資評価テンプレート。公式IR・一次報道を確認後に入力・承認してください。",
      target_provider_category: "フロンティアLLM",
      is_sample_template: true,
      ingested_at: nowIso,
    },
    {
      company_name: "テンプレート例B: 推論チップ・クラウド最適化企業",
      quarter: "2026-Q2",
      round_stage: "Series B (要確認)",
      amount_display: "要確認（一次公式発表未入力）",
      announced_at: "2026-05-08T00:00:00.000Z",
      source_name: "テンプレート初期項目（要一次情報照合）",
      source_url: "",
      investors: ["要確認"],
      summary:
        "推論コスト・GPU供給リスク評価テンプレート。財務数値は公式発表確認後に検証ステータスを更新します。",
      target_provider_category: "AI推論インフラ",
      is_sample_template: true,
      ingested_at: nowIso,
    },
    {
      company_name: "テンプレート例C: オープンウェイト・ローカルLLM企業",
      quarter: "2026-Q2",
      round_stage: "Strategic (要確認)",
      amount_display: "要確認（一次公式発表未入力）",
      announced_at: "2026-06-03T00:00:00.000Z",
      source_name: "テンプレート初期項目（要一次情報照合）",
      source_url: "",
      investors: ["要確認"],
      summary:
        "オープンモデル開発元の提携・資金調達監視テンプレート。一次出典URLを添えて検証してください。",
      target_provider_category: "オープンモデル / Edge AI",
      is_sample_template: true,
      ingested_at: nowIso,
    },
  ];
}

function extractRawItems(body: Record<string, unknown>): {
  rssRecords: NormalizedInvestmentRecord[];
  jsonItems: unknown[];
} {
  if (Array.isArray(body.items)) {
    return { rssRecords: [], jsonItems: body.items };
  }
  const rawPayload = body.raw_payload;
  if (typeof rawPayload === "string" && rawPayload.trim().length > 0) {
    const trimmed = rawPayload.trim();
    if (trimmed.startsWith("<") && /<(?:item|entry)\b/i.test(trimmed)) {
      const sourceName = typeof body.source_name === "string" &&
          body.source_name.trim()
        ? body.source_name.trim()
        : "手動取込 RSS/Atom";
      return {
        rssRecords: parseRssOrAtomFeed(trimmed, {
          sourceName,
          filterInvestmentRelevant: false,
          maxItems: MAX_INGEST_BATCH,
        }),
        jsonItems: [],
      };
    }
    try {
      const parsed = JSON.parse(trimmed) as unknown;
      if (Array.isArray(parsed)) {
        return { rssRecords: [], jsonItems: parsed };
      }
      if (typeof parsed === "object" && parsed !== null) {
        const obj = parsed as Record<string, unknown>;
        if (Array.isArray(obj.items)) {
          return { rssRecords: [], jsonItems: obj.items };
        }
        return { rssRecords: [], jsonItems: [obj] };
      }
    } catch {
      throw new AiInvestmentError("raw_payload must be valid JSON or RSS/Atom");
    }
  }
  if (typeof rawPayload === "object" && rawPayload !== null) {
    return { rssRecords: [], jsonItems: [rawPayload] };
  }
  if (
    typeof body.company_name === "string" ||
    typeof body.company === "string" ||
    typeof body.title === "string"
  ) {
    return { rssRecords: [], jsonItems: [body] };
  }
  throw new AiInvestmentError(
    "Provide items array, raw_payload, or company_name/title",
  );
}

async function insertNormalizedRecords(
  admin: AiInvestmentDb,
  userId: string,
  candidates: readonly NormalizedInvestmentRecord[],
  existingKeys: Set<string>,
): Promise<{
  inserted: FormattedInvestmentRecord[];
  skippedDuplicates: number;
}> {
  const inserted: FormattedInvestmentRecord[] = [];
  let skippedDuplicates = 0;

  for (const record of candidates) {
    if (existingKeys.has(record.dedup_key)) {
      skippedDuplicates += 1;
      continue;
    }
    existingKeys.add(record.dedup_key);
    const meta: Record<string, unknown> = {
      ...record,
      // Enforce initial needs_verification at persistence boundary as well.
      verification_status: "needs_verification",
      verification_label: VERIFICATION_LABELS.needs_verification,
      requires_manual_verification: true,
      verified_at: null,
      verified_by: null,
      user_id: userId,
    };
    const { data, error } = await asHubTable(admin)
      .insert({
        source: AI_INVESTMENT_TREND_SOURCE,
        metadata: meta,
      })
      .select("id, metadata, created_at")
      .single();
    if (error || !data) {
      throw new AiInvestmentError(
        error?.message ?? "Failed to store investment record",
        500,
      );
    }
    inserted.push(formatRow(data as HubDataRow));
  }

  return { inserted, skippedDuplicates };
}

export async function handleAiInvestmentAction(params: {
  action: string;
  admin: AiInvestmentDb;
  body: Record<string, unknown>;
  userId: string;
}): Promise<Record<string, unknown>> {
  const { action, admin, body, userId } = params;
  if (!userId) {
    throw new AiInvestmentError("Unauthorized", 401);
  }

  switch (action) {
    case "ai_investment.list": {
      const limit = Number(body.limit ?? DEFAULT_LIMIT);
      const allRecords = await fetchAllUserRecords(
        admin,
        userId,
        Number.isFinite(limit) ? limit : DEFAULT_LIMIT,
      );
      const quarterFilter = typeof body.quarter === "string"
        ? body.quarter.trim().toUpperCase()
        : "";
      const statusFilter = typeof body.verification_status === "string"
        ? body.verification_status.trim()
        : "";
      const query = typeof body.query === "string"
        ? body.query.trim().toLowerCase()
        : "";

      const filtered = allRecords.filter((rec) => {
        if (quarterFilter && rec.quarter.toUpperCase() !== quarterFilter) {
          return false;
        }
        if (
          statusFilter &&
          statusFilter !== "all" &&
          rec.verification_status !== statusFilter
        ) {
          return false;
        }
        if (query) {
          const hay = [
            rec.company_name,
            rec.round_stage,
            rec.source_name,
            rec.summary,
            rec.target_provider_category,
            ...rec.investors,
          ].join(" ").toLowerCase();
          if (!hay.includes(query)) return false;
        }
        return true;
      });

      return {
        records: filtered,
        summary: buildSummary(allRecords),
      };
    }

    case "ai_investment.seed_defaults": {
      const existing = await fetchAllUserRecords(admin, userId, 100);
      if (existing.length > 0) {
        return {
          already_seeded: true,
          seeded_count: 0,
          records: existing,
          summary: buildSummary(existing),
        };
      }
      const nowIso = new Date().toISOString();
      const starters = buildTemplateStarters(nowIso);
      const { records } = normalizeInvestmentBatch(starters, {
        defaultQuarter: "2026-Q2",
        ingestedAt: nowIso,
        isSampleTemplate: true,
      });
      const existingKeys = new Set<string>();
      const { inserted } = await insertNormalizedRecords(
        admin,
        userId,
        records,
        existingKeys,
      );
      const all = await fetchAllUserRecords(admin, userId, 100);
      return {
        already_seeded: false,
        seeded_count: inserted.length,
        records: all,
        summary: buildSummary(all),
      };
    }

    case "ai_investment.ingest": {
      const extracted = extractRawItems(body);
      const rawCount = extracted.rssRecords.length + extracted.jsonItems.length;
      if (rawCount === 0) {
        throw new AiInvestmentError("No investment items found in payload");
      }
      if (rawCount > MAX_INGEST_BATCH) {
        throw new AiInvestmentError(
          `Batch exceeds maximum of ${MAX_INGEST_BATCH} items`,
        );
      }

      const nowIso = new Date().toISOString();
      const batch = extracted.jsonItems.length > 0
        ? normalizeInvestmentBatch(extracted.jsonItems, {
          defaultQuarter: typeof body.default_quarter === "string"
            ? body.default_quarter
            : "2026-Q2",
          defaultSourceName: typeof body.source_name === "string"
            ? body.source_name
            : undefined,
          ingestedAt: nowIso,
        })
        : { records: [], errors: [] };

      const candidates = [...extracted.rssRecords, ...batch.records];
      const existing = await fetchAllUserRecords(admin, userId, 200);
      const existingKeys = new Set(existing.map((r) => r.dedup_key));
      const { inserted, skippedDuplicates } = await insertNormalizedRecords(
        admin,
        userId,
        candidates,
        existingKeys,
      );
      const all = await fetchAllUserRecords(admin, userId, 100);

      return {
        ingested_count: inserted.length,
        skipped_duplicates: skippedDuplicates,
        rejected_count: batch.errors.length,
        errors: batch.errors,
        ingested_records: inserted,
        records: all,
        summary: buildSummary(all),
      };
    }

    case "ai_investment.verify_entry": {
      const id = typeof body.id === "string" ? body.id.trim() : "";
      if (!id) {
        throw new AiInvestmentError("id is required");
      }
      const rawDecision = typeof body.decision === "string"
        ? body.decision.trim()
        : "";
      if (
        !(VERIFICATION_STATUSES as readonly string[]).includes(rawDecision)
      ) {
        throw new AiInvestmentError(
          "decision must be needs_verification, verified, or rejected",
        );
      }
      const decision = rawDecision as VerificationStatus;
      const note = typeof body.verification_note === "string"
        ? body.verification_note.trim().slice(0, MAX_NOTE_LEN)
        : "";

      const { data: existing, error: readErr } = await asHubTable(admin)
        .select("id, metadata, created_at")
        .eq("id", id)
        .eq("source", AI_INVESTMENT_TREND_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (readErr) {
        throw new AiInvestmentError(
          readErr.message ?? "Failed to read target record",
          500,
        );
      }
      if (!existing) {
        throw new AiInvestmentError("Investment record not found", 404);
      }

      const prevRow = existing as HubDataRow;
      const prevMeta = (prevRow.metadata ?? {}) as Record<string, unknown>;
      const nowIso = new Date().toISOString();

      let nextSourceUrl = String(prevMeta.source_url ?? "");
      if (typeof body.source_url === "string" && body.source_url.trim()) {
        const sanitized = sanitizeHttpUrl(body.source_url);
        if (!sanitized) {
          throw new AiInvestmentError(
            "source_url must be a valid HTTP/HTTPS URL",
          );
        }
        nextSourceUrl = sanitized;
      }

      const nextMeta: Record<string, unknown> = {
        ...prevMeta,
        source_url: nextSourceUrl,
        verification_status: decision,
        verification_label: VERIFICATION_LABELS[decision],
        requires_manual_verification: decision === "needs_verification",
        verification_note: note,
        verified_by: decision === "needs_verification" ? null : userId,
        verified_at: decision === "needs_verification" ? null : nowIso,
        updated_at: nowIso,
        user_id: userId,
      };

      const { data: updated, error: updateErr } = await asHubTable(admin)
        .update({ metadata: nextMeta })
        .eq("id", id)
        .eq("source", AI_INVESTMENT_TREND_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .maybeSingle();
      if (updateErr || !updated) {
        throw new AiInvestmentError(
          updateErr?.message ?? "Failed to update verification status",
          500,
        );
      }

      const all = await fetchAllUserRecords(admin, userId, 100);
      return {
        record: formatRow(updated as HubDataRow),
        summary: buildSummary(all),
      };
    }

    default:
      throw new AiInvestmentError(`Unsupported action: ${action}`, 400);
  }
}
