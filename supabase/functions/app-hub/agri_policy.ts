export const AGRI_POLICY_SOURCE = "agri_policy_event";

export type PolicyPhase = "past" | "current" | "planned";
export type FactCheckStatus =
  | "verified"
  | "needs_review"
  | "disputed"
  | "unverified";

const VALID_PHASES = new Set<PolicyPhase>(["past", "current", "planned"]);
const VALID_FACT_STATUSES = new Set<FactCheckStatus>([
  "verified",
  "needs_review",
  "disputed",
  "unverified",
]);

export class AgriPolicyActionError extends Error {
  status: number;
  payload: Record<string, unknown>;

  constructor(
    message: string,
    status = 400,
    payload: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = "AgriPolicyActionError";
    this.status = status;
    this.payload = payload;
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

export interface AgriPolicyDb {
  from(table: string): unknown;
}

export interface AgriPolicyEvent {
  id: string;
  slug: string;
  event_date: string;
  fiscal_year: number;
  phase: PolicyPhase;
  title: string;
  summary: string;
  tags: string[];
  related_nodes: string[];
  fact_check_status: FactCheckStatus;
  source_citation: string;
  verified_at: string | null;
  policy_impact_notes: string;
  updated_at: string;
  created_at: string;
}

export interface KnowledgeGraphEdge {
  from_event_id: string;
  to_event_id: string;
  shared_terms: string[];
}

interface SeedPolicyEvent {
  slug: string;
  event_date: string;
  fiscal_year: number;
  phase: PolicyPhase;
  title: string;
  summary: string;
  tags: string[];
  related_nodes: string[];
  fact_check_status: FactCheckStatus;
  source_citation: string;
  verified_at: string | null;
  policy_impact_notes: string;
}

export const DEFAULT_AGRI_POLICY_EVENTS: readonly SeedPolicyEvent[] = [
  {
    slug: "fy2018-production-target-abolition",
    event_date: "2018-04-01",
    fiscal_year: 2018,
    phase: "past",
    title: "行政による生産数量目標の配分廃止（いわゆる減反廃止）",
    summary:
      "国が都道府県・生産者へ割り当てていた主食用米の生産数量目標の配分を2018年産より廃止し、需要に応じた自主的生産判断へ移行。",
    tags: ["減反廃止", "生産調整", "主食用米"],
    related_nodes: ["農林水産省", "需要に応じた生産", "米政策見直し"],
    fact_check_status: "verified",
    source_citation: "農林水産省 平成30年産からの米政策の見直し",
    verified_at: "2026-05-18T00:00:00.000Z",
    policy_impact_notes:
      "行政割当の廃止後、地域ごとの需要見通しや加工・飼料用米等への作付選択がより重要になった。",
  },
  {
    slug: "fy2018-direct-payment-restructure",
    event_date: "2018-04-02",
    fiscal_year: 2018,
    phase: "past",
    title: "米の直接支払交付金廃止と経営所得安定対策の再編",
    summary:
      "主食用米の一律面積払い（10a当たり7,500円）を2017年産で終了し、ナラシ対策・水田活用の直接支払交付金等へ重心を移行。",
    tags: ["直接支払い", "ナラシ対策", "水田活用"],
    related_nodes: [
      "収入減少影響緩和対策",
      "水田活用の直接支払交付金",
      "米政策見直し",
    ],
    fact_check_status: "verified",
    source_citation: "農林水産省 経営所得安定対策等の概要",
    verified_at: "2026-05-18T00:00:00.000Z",
    policy_impact_notes:
      "主食用米への固定直接支払を終了し、非主食用米や畑作物の作付転換と価格下落対策を組み合わせる設計へ再編。",
  },
  {
    slug: "fy2019-marukin-safety-net",
    event_date: "2019-04-01",
    fiscal_year: 2019,
    phase: "past",
    title: "マルキン制度（牛・豚経営安定交付金）の法制化・セーフティネット比較",
    summary:
      "標準的販売価格が標準的生産費を下回った際に差額を補填する畜産マルキン制度を法制化。米・畑作の経営安定策と対比される制度。",
    tags: ["マルキン制度", "経営安定対策", "セーフティネット"],
    related_nodes: [
      "肉用牛肥育経営安定交付金",
      "養豚経営安定対策",
      "収入減少影響緩和対策",
    ],
    fact_check_status: "verified",
    source_citation: "農林水産省 畜産経営の安定に関する法律（牛・豚マルキン）",
    verified_at: "2026-05-18T00:00:00.000Z",
    policy_impact_notes:
      "生産コストと販売価格の差額補填を行う畜産向け制度であり、穀物・米分野の直接支払いや収入保険との補完・比較対象となる。",
  },
  {
    slug: "fy2025-water-rule-abolition-plan",
    event_date: "2025-04-01",
    fiscal_year: 2025,
    phase: "current",
    title: "水田活用の直接支払交付金「5年水張りルール」見直し・廃止方針",
    summary:
      "令和4年度見直しで導入された「5年間に一度も水張りがない水田を対象外とする要件」について、令和9年度新政策移行に伴い求めない方針へ転換。",
    tags: ["直接支払い", "水田政策", "5年水張り"],
    related_nodes: [
      "水田活用の直接支払交付金",
      "食料・農業・農村基本計画",
      "畑地化支援",
    ],
    fact_check_status: "verified",
    source_citation: "農林水産省 令和7年 水田政策の見直し方針",
    verified_at: "2026-05-18T00:00:00.000Z",
    policy_impact_notes:
      "現場の機械的転作負担や畑地化を巡る懸念を受け、面積要件から作物ごとの生産性・需要対応へ軸足を移す過渡期。",
  },
  {
    slug: "fy2027-rice-paddy-policy-reform",
    event_date: "2027-04-01",
    fiscal_year: 2027,
    phase: "planned",
    title: "2027年（令和9年）度 新たな米・水田政策の本格導入",
    summary:
      "水田維持を前提とした面積払いから脱却し、需要に応じた作物の単収・生産性向上、省力化、適正価格形成の促進を軸とした新制度へ移行予定。",
    tags: ["減反廃止", "直接支払い", "2027年改革"],
    related_nodes: [
      "生産性向上支援",
      "食料システム法",
      "需要に応じた生産",
    ],
    fact_check_status: "needs_review",
    source_citation: "農林水産省 令和9年度に向けた新たな水田政策の方向性",
    verified_at: null,
    policy_impact_notes:
      "予算要件・交付単価・備蓄米運用との連携など具体制度設計は公表資料の随時確認が必要。",
  },
];

function asHubTable(admin: AgriPolicyDb): HubQuery<unknown> {
  return admin.from("hub_data") as HubQuery<unknown>;
}

function sanitizeText(raw: unknown, maxLen: number): string {
  return String(raw ?? "").trim().slice(0, maxLen);
}

function normalizeStringList(raw: unknown, maxItems = 12): string[] {
  const source = Array.isArray(raw)
    ? raw
    : typeof raw === "string"
    ? raw.split(",")
    : [];
  const unique = new Set<string>();
  for (const item of source) {
    const clean = String(item ?? "").trim().slice(0, 48);
    if (clean) unique.add(clean);
    if (unique.size >= maxItems) break;
  }
  return Array.from(unique);
}

function normalizeEventDate(raw: unknown): string {
  const clean = sanitizeText(raw, 32);
  if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) {
    return clean;
  }
  throw new AgriPolicyActionError(
    "event_date must match YYYY-MM-DD",
    400,
  );
}

function normalizePhase(raw: unknown, fiscalYear: number): PolicyPhase {
  const clean = sanitizeText(raw, 20).toLowerCase() as PolicyPhase;
  if (VALID_PHASES.has(clean)) return clean;
  if (fiscalYear >= 2027) return "planned";
  if (fiscalYear >= 2025) return "current";
  return "past";
}

function normalizeFactCheckStatus(raw: unknown): FactCheckStatus {
  const clean = sanitizeText(raw, 24).toLowerCase() as FactCheckStatus;
  if (VALID_FACT_STATUSES.has(clean)) return clean;
  if (!clean) return "unverified";
  throw new AgriPolicyActionError(
    "fact_check_status must be verified, needs_review, disputed, or unverified",
    400,
  );
}

function formatEvent(row: HubDataRow): AgriPolicyEvent {
  const meta = (row.metadata ?? {}) as Record<string, unknown>;
  const eventDate = String(meta.event_date ?? "2018-04-01");
  const parsedYear = Number(meta.fiscal_year ?? eventDate.slice(0, 4));
  const fiscalYear = Number.isInteger(parsedYear) ? parsedYear : 2018;
  const phase = normalizePhase(meta.phase, fiscalYear);
  const rawStatus = sanitizeText(meta.fact_check_status, 24).toLowerCase();
  const factStatus = VALID_FACT_STATUSES.has(rawStatus as FactCheckStatus)
    ? (rawStatus as FactCheckStatus)
    : "unverified";
  const verifiedAt = meta.verified_at == null
    ? null
    : sanitizeText(meta.verified_at, 64) || null;

  return {
    id: row.id,
    slug: sanitizeText(meta.slug, 120),
    event_date: eventDate,
    fiscal_year: fiscalYear,
    phase,
    title: sanitizeText(meta.title, 160),
    summary: sanitizeText(meta.summary, 1500),
    tags: normalizeStringList(meta.tags),
    related_nodes: normalizeStringList(meta.related_nodes),
    fact_check_status: factStatus,
    source_citation: sanitizeText(meta.source_citation, 300),
    verified_at: verifiedAt,
    policy_impact_notes: sanitizeText(meta.policy_impact_notes, 1000),
    updated_at: sanitizeText(meta.updated_at, 64) ||
      (row.created_at ?? ""),
    created_at: row.created_at ?? "",
  };
}

export function buildKnowledgeEdges(
  events: readonly AgriPolicyEvent[],
): KnowledgeGraphEdge[] {
  const edges: KnowledgeGraphEdge[] = [];
  for (let i = 0; i < events.length; i += 1) {
    for (let j = i + 1; j < events.length; j += 1) {
      const a = events[i];
      const b = events[j];
      const termsA = new Set([...a.tags, ...a.related_nodes]);
      const shared = [...b.tags, ...b.related_nodes].filter((term) =>
        termsA.has(term)
      );
      const uniqueShared = Array.from(new Set(shared));
      if (uniqueShared.length > 0) {
        edges.push({
          from_event_id: a.id,
          to_event_id: b.id,
          shared_terms: uniqueShared,
        });
      }
    }
  }
  return edges;
}

export function sortEventsChronologically(
  events: readonly AgriPolicyEvent[],
): AgriPolicyEvent[] {
  return [...events].sort((a, b) => {
    const cmp = a.event_date.localeCompare(b.event_date);
    if (cmp !== 0) return cmp;
    return a.created_at.localeCompare(b.created_at);
  });
}

async function fetchOwnedEvents(
  admin: AgriPolicyDb,
  userId: string,
): Promise<AgriPolicyEvent[]> {
  const { data, error } = await asHubTable(admin)
    .select("id, metadata, created_at")
    .eq("source", AGRI_POLICY_SOURCE)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: true })
    .limit(100);
  if (error) {
    throw new AgriPolicyActionError(
      error.message ?? "Failed to query agri_policy_event rows",
      500,
    );
  }
  const rows = (data ?? []) as HubDataRow[];
  return sortEventsChronologically(rows.map(formatEvent));
}

async function seedMissingDefaults(
  admin: AgriPolicyDb,
  userId: string,
  existing: readonly AgriPolicyEvent[],
): Promise<number> {
  const existingSlugs = new Set(
    existing.map((event) => event.slug).filter(Boolean),
  );
  let insertedCount = 0;
  const nowIso = new Date().toISOString();

  for (const seed of DEFAULT_AGRI_POLICY_EVENTS) {
    if (existingSlugs.has(seed.slug)) continue;
    const { error } = await asHubTable(admin)
      .insert({
        source: AGRI_POLICY_SOURCE,
        metadata: {
          user_id: userId,
          ...seed,
          updated_at: nowIso,
        },
      })
      .select("id, metadata, created_at")
      .single();
    if (error) {
      throw new AgriPolicyActionError(
        error.message ?? "Failed to seed default policy event",
        500,
      );
    }
    insertedCount += 1;
  }
  return insertedCount;
}

function matchesSearch(
  event: AgriPolicyEvent,
  queryLower: string,
  tagFilter: string,
  phaseFilter: string,
  factStatusFilter: string,
): boolean {
  if (tagFilter && !event.tags.includes(tagFilter)) return false;
  if (phaseFilter && event.phase !== phaseFilter) return false;
  if (factStatusFilter && event.fact_check_status !== factStatusFilter) {
    return false;
  }
  if (!queryLower) return true;

  const haystack = [
    event.title,
    event.summary,
    event.event_date,
    String(event.fiscal_year),
    event.source_citation,
    event.policy_impact_notes,
    ...event.tags,
    ...event.related_nodes,
  ].join("\n").toLowerCase();
  return haystack.includes(queryLower);
}

export async function handleAgriPolicyAction({
  action,
  admin,
  body,
  userId,
}: {
  action: string;
  admin: AgriPolicyDb;
  body: Record<string, unknown>;
  userId: string;
}): Promise<Record<string, unknown>> {
  switch (action) {
    case "agri_policy.list": {
      let allEvents = await fetchOwnedEvents(admin, userId);
      let seededCount = 0;
      if (allEvents.length === 0 && body.seed_if_empty === true) {
        seededCount = await seedMissingDefaults(admin, userId, allEvents);
        allEvents = await fetchOwnedEvents(admin, userId);
      }
      const queryLower = sanitizeText(body.query, 120).toLowerCase();
      const tagFilter = sanitizeText(body.tag, 48);
      const phaseFilter = sanitizeText(body.phase, 20).toLowerCase();
      const factFilter = sanitizeText(body.fact_check_status, 24)
        .toLowerCase();

      const filtered = allEvents.filter((event) =>
        matchesSearch(event, queryLower, tagFilter, phaseFilter, factFilter)
      );
      const tagSet = new Set<string>();
      for (const event of allEvents) {
        for (const tag of event.tags) tagSet.add(tag);
      }

      return {
        events: filtered,
        total_count: allEvents.length,
        filtered_count: filtered.length,
        seeded_count: seededCount,
        available_tags: Array.from(tagSet),
        knowledge_edges: buildKnowledgeEdges(filtered),
      };
    }

    case "agri_policy.seed_defaults": {
      const existing = await fetchOwnedEvents(admin, userId);
      const insertedCount = await seedMissingDefaults(admin, userId, existing);
      const events = await fetchOwnedEvents(admin, userId);
      return {
        inserted_count: insertedCount,
        events,
        knowledge_edges: buildKnowledgeEdges(events),
      };
    }

    case "agri_policy.create": {
      const title = sanitizeText(body.title, 160);
      if (!title) {
        throw new AgriPolicyActionError("title is required", 400);
      }
      const eventDate = normalizeEventDate(body.event_date);
      const parsedYear = Number(
        body.fiscal_year ?? eventDate.slice(0, 4),
      );
      const fiscalYear = Number.isInteger(parsedYear)
        ? parsedYear
        : Number(eventDate.slice(0, 4));
      const phase = normalizePhase(body.phase, fiscalYear);
      const factStatus = normalizeFactCheckStatus(body.fact_check_status);
      const summary = sanitizeText(body.summary, 1500);
      const tags = normalizeStringList(body.tags);
      const relatedNodes = normalizeStringList(body.related_nodes);
      const sourceCitation = sanitizeText(body.source_citation, 300);
      const impactNotes = sanitizeText(body.policy_impact_notes, 1000);
      const nowIso = new Date().toISOString();
      const verifiedAt = factStatus === "verified"
        ? sanitizeText(body.verified_at, 64) || nowIso
        : sanitizeText(body.verified_at, 64) || null;
      const slug = sanitizeText(body.slug, 120) ||
        `custom-${crypto.randomUUID().slice(0, 8)}`;

      const { data, error } = await asHubTable(admin)
        .insert({
          source: AGRI_POLICY_SOURCE,
          metadata: {
            user_id: userId,
            slug,
            event_date: eventDate,
            fiscal_year: fiscalYear,
            phase,
            title,
            summary,
            tags,
            related_nodes: relatedNodes,
            fact_check_status: factStatus,
            source_citation: sourceCitation,
            verified_at: verifiedAt,
            policy_impact_notes: impactNotes,
            updated_at: nowIso,
          },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data) {
        throw new AgriPolicyActionError(
          error?.message ?? "Failed to create agri policy event",
          500,
        );
      }
      return { event: formatEvent(data as HubDataRow) };
    }

    case "agri_policy.update": {
      const id = sanitizeText(body.id, 120);
      if (!id) {
        throw new AgriPolicyActionError("id is required", 400);
      }
      const { data: existingRow, error: readErr } = await asHubTable(admin)
        .select("id, metadata, created_at")
        .eq("id", id)
        .eq("source", AGRI_POLICY_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (readErr) {
        throw new AgriPolicyActionError(
          readErr.message ?? "Failed to load agri policy event",
          500,
        );
      }
      if (!existingRow) {
        throw new AgriPolicyActionError("Policy event not found", 404);
      }

      const prev = ((existingRow as HubDataRow).metadata ?? {}) as Record<
        string,
        unknown
      >;
      const nowIso = new Date().toISOString();
      const nextDate = body.event_date !== undefined
        ? normalizeEventDate(body.event_date)
        : String(prev.event_date ?? "2018-04-01");
      const parsedYear = Number(
        body.fiscal_year ?? prev.fiscal_year ?? nextDate.slice(0, 4),
      );
      const nextStatus = body.fact_check_status !== undefined
        ? normalizeFactCheckStatus(body.fact_check_status)
        : normalizeFactCheckStatus(prev.fact_check_status);

      const nextMeta: Record<string, unknown> = {
        ...prev,
        user_id: userId,
        event_date: nextDate,
        fiscal_year: parsedYear,
        phase: normalizePhase(body.phase ?? prev.phase, parsedYear),
        title: body.title !== undefined
          ? sanitizeText(body.title, 160) || String(prev.title ?? "")
          : prev.title,
        summary: body.summary !== undefined
          ? sanitizeText(body.summary, 1500)
          : prev.summary,
        tags: body.tags !== undefined
          ? normalizeStringList(body.tags)
          : prev.tags,
        related_nodes: body.related_nodes !== undefined
          ? normalizeStringList(body.related_nodes)
          : prev.related_nodes,
        fact_check_status: nextStatus,
        source_citation: body.source_citation !== undefined
          ? sanitizeText(body.source_citation, 300)
          : prev.source_citation,
        policy_impact_notes: body.policy_impact_notes !== undefined
          ? sanitizeText(body.policy_impact_notes, 1000)
          : prev.policy_impact_notes,
        verified_at: body.verified_at !== undefined
          ? sanitizeText(body.verified_at, 64) || null
          : nextStatus === "verified" && !prev.verified_at
          ? nowIso
          : prev.verified_at ?? null,
        updated_at: nowIso,
      };

      const { data: updated, error: updErr } = await asHubTable(admin)
        .update({ metadata: nextMeta })
        .eq("id", id)
        .eq("source", AGRI_POLICY_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .single();
      if (updErr || !updated) {
        throw new AgriPolicyActionError(
          updErr?.message ?? "Failed to update agri policy event",
          500,
        );
      }
      return { event: formatEvent(updated as HubDataRow) };
    }

    default:
      throw new AgriPolicyActionError(`Unsupported action: ${action}`, 400);
  }
}
