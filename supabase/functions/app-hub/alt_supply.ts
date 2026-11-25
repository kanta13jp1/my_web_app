import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export const ALT_SUPPLY_SOURCE = "alt_supply_scenario";
export const DEFAULT_STOCKPILE_TARGET_10K_T = 100.0;
export const DEFAULT_PROCUREMENT_THRESHOLD_10K_T = 80.0;
export const DEFAULT_TOTAL_PRODUCTION_TARGET_10K_T = 800.0;
export const DEFAULT_MA_IMPORT_QUOTA_10K_T = 77.0;

export type AltSupplyRiskLevel = "low" | "elevated" | "high" | "critical";
export type AltSupplySourceKind = "manual" | "open_data_sync";

export interface AltSupplyScenarioRecord {
  id: string;
  user_id: string;
  title: string;
  source_kind: AltSupplySourceKind;
  source_ref: string;
  stockpile_target_10k_t: number;
  domestic_procurement_10k_t: number;
  stockpile_threshold_10k_t: number;
  stockpile_shortfall_10k_t: number;
  below_procurement_threshold: boolean;
  total_production_target_10k_t: number;
  current_production_10k_t: number;
  total_production_gap_10k_t: number;
  production_shortfall_10k_t: number;
  ma_import_quota_10k_t: number;
  import_escalation_probability: number;
  risk_level: AltSupplyRiskLevel;
  notes: string;
  updated_at: string;
}

export interface AltSupplyDb {
  listScenarios(
    userId: string,
    limit: number,
  ): Promise<Array<Record<string, unknown>>>;
  insertScenario(
    userId: string,
    metadata: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  findScenarioById(
    userId: string,
    id: string,
  ): Promise<Record<string, unknown> | null>;
  updateScenario(
    userId: string,
    id: string,
    metadata: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

export interface AltSupplyActionResult {
  status: number;
  body: Record<string, unknown>;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function asTrimmed(value: unknown, maxLen: number): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLen);
}

function parseBoundedNumber(
  value: unknown,
  min: number,
  max: number,
): number | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return null;
  }
  return round1(parsed);
}

function normalizeSourceKind(value: unknown): AltSupplySourceKind {
  return value === "open_data_sync" ? "open_data_sync" : "manual";
}

export function evaluateAltSupplyMetrics(input: {
  stockpileTarget10kT: number;
  domesticProcurement10kT: number;
  stockpileThreshold10kT: number;
  totalProductionTarget10kT: number;
  currentProduction10kT: number;
  maImportQuota10kT: number;
}): {
  stockpile_shortfall_10k_t: number;
  below_procurement_threshold: boolean;
  total_production_gap_10k_t: number;
  production_shortfall_10k_t: number;
  import_escalation_probability: number;
  risk_level: AltSupplyRiskLevel;
} {
  const shortfall = round1(
    Math.max(0, input.stockpileTarget10kT - input.domesticProcurement10kT),
  );
  const belowThreshold =
    input.domesticProcurement10kT < input.stockpileThreshold10kT;
  const prodGap = round1(
    input.currentProduction10kT - input.totalProductionTarget10kT,
  );
  const prodShortfall = round1(Math.max(0, -prodGap));

  const targetBase = Math.max(1, input.stockpileTarget10kT);
  const shortfallRatio = Math.min(1, shortfall / targetBase);
  const thresholdGapRatio = input.stockpileThreshold10kT > 0 && belowThreshold
    ? Math.min(
      1,
      (input.stockpileThreshold10kT - input.domesticProcurement10kT) /
        input.stockpileThreshold10kT,
    )
    : 0;
  const prodGapRatio = input.totalProductionTarget10kT > 0
    ? Math.min(1, prodShortfall / input.totalProductionTarget10kT)
    : 0;

  let prob = 10 + shortfallRatio * 45 + prodGapRatio * 20;
  if (belowThreshold) {
    prob += 25 + thresholdGapRatio * 20;
  }
  const importProbability = Math.max(5, Math.min(98, Math.round(prob)));

  let riskLevel: AltSupplyRiskLevel = "low";
  if (belowThreshold && importProbability >= 75) {
    riskLevel = "critical";
  } else if (belowThreshold) {
    riskLevel = "high";
  } else if (shortfall > 0 || prodShortfall > 0) {
    riskLevel = "elevated";
  }

  return {
    stockpile_shortfall_10k_t: shortfall,
    below_procurement_threshold: belowThreshold,
    total_production_gap_10k_t: prodGap,
    production_shortfall_10k_t: prodShortfall,
    import_escalation_probability: importProbability,
    risk_level: riskLevel,
  };
}

function mapRowToScenario(
  row: Record<string, unknown>,
  fallbackUserId: string,
): AltSupplyScenarioRecord {
  const meta = row.metadata && typeof row.metadata === "object"
    ? (row.metadata as Record<string, unknown>)
    : {};
  const stockpileTarget = parseBoundedNumber(
    meta.stockpile_target_10k_t,
    0,
    500,
  ) ?? DEFAULT_STOCKPILE_TARGET_10K_T;
  const domesticProcurement = parseBoundedNumber(
    meta.domestic_procurement_10k_t,
    0,
    500,
  ) ?? 0;
  const stockpileThreshold = parseBoundedNumber(
    meta.stockpile_threshold_10k_t,
    0,
    500,
  ) ?? DEFAULT_PROCUREMENT_THRESHOLD_10K_T;
  const totalTarget = parseBoundedNumber(
    meta.total_production_target_10k_t,
    1,
    2000,
  ) ?? DEFAULT_TOTAL_PRODUCTION_TARGET_10K_T;
  const currentProd = parseBoundedNumber(
    meta.current_production_10k_t,
    0,
    2000,
  ) ?? totalTarget;
  const maQuota = parseBoundedNumber(
    meta.ma_import_quota_10k_t,
    0,
    500,
  ) ?? DEFAULT_MA_IMPORT_QUOTA_10K_T;

  const metrics = evaluateAltSupplyMetrics({
    stockpileTarget10kT: stockpileTarget,
    domesticProcurement10kT: domesticProcurement,
    stockpileThreshold10kT: stockpileThreshold,
    totalProductionTarget10kT: totalTarget,
    currentProduction10kT: currentProd,
    maImportQuota10kT: maQuota,
  });

  return {
    id: row.id == null ? "" : String(row.id),
    user_id: asTrimmed(meta.user_id, 128) || fallbackUserId,
    title: asTrimmed(meta.title, 120) || "需給・輸入リスクシナリオ",
    source_kind: normalizeSourceKind(meta.source_kind),
    source_ref: asTrimmed(meta.source_ref, 300),
    stockpile_target_10k_t: stockpileTarget,
    domestic_procurement_10k_t: domesticProcurement,
    stockpile_threshold_10k_t: stockpileThreshold,
    total_production_target_10k_t: totalTarget,
    current_production_10k_t: currentProd,
    ma_import_quota_10k_t: maQuota,
    notes: asTrimmed(meta.notes, 500),
    updated_at: asTrimmed(meta.updated_at, 64) ||
      (row.created_at == null ? "" : String(row.created_at)),
    ...metrics,
  };
}

export function createSupabaseAltSupplyDb(
  admin: SupabaseClient,
): AltSupplyDb {
  return {
    async listScenarios(userId, limit) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", ALT_SUPPLY_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error || !Array.isArray(data)) {
        throw new Error(
          error?.message ?? "Failed to load alt_supply_scenario rows.",
        );
      }
      return (data as unknown[]).filter(
        (item): item is Record<string, unknown> =>
          item != null && typeof item === "object",
      );
    },

    async insertScenario(userId, metadata) {
      const { data, error } = await admin
        .from("hub_data")
        .insert({
          source: ALT_SUPPLY_SOURCE,
          metadata: { ...metadata, user_id: userId },
        })
        .select("id, metadata, created_at")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to insert alt_supply_scenario row.",
        );
      }
      return data as Record<string, unknown>;
    },

    async findScenarioById(userId, id) {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("id", id)
        .eq("source", ALT_SUPPLY_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .maybeSingle();
      if (error) {
        throw new Error(error.message);
      }
      return data && typeof data === "object"
        ? (data as Record<string, unknown>)
        : null;
    },

    async updateScenario(userId, id, metadata) {
      const { data, error } = await admin
        .from("hub_data")
        .update({ metadata: { ...metadata, user_id: userId } })
        .eq("id", id)
        .eq("source", ALT_SUPPLY_SOURCE)
        .filter("metadata->>user_id", "eq", userId)
        .select("id, metadata, created_at")
        .single();
      if (error || !data || typeof data !== "object") {
        throw new Error(
          error?.message ?? "Failed to update alt_supply_scenario row.",
        );
      }
      return data as Record<string, unknown>;
    },
  };
}

function buildScenarioMetadata(input: {
  title: string;
  sourceKind: AltSupplySourceKind;
  sourceRef: string;
  stockpileTarget10kT: number;
  domesticProcurement10kT: number;
  stockpileThreshold10kT: number;
  totalProductionTarget10kT: number;
  currentProduction10kT: number;
  maImportQuota10kT: number;
  notes: string;
}): Record<string, unknown> {
  const metrics = evaluateAltSupplyMetrics({
    stockpileTarget10kT: input.stockpileTarget10kT,
    domesticProcurement10kT: input.domesticProcurement10kT,
    stockpileThreshold10kT: input.stockpileThreshold10kT,
    totalProductionTarget10kT: input.totalProductionTarget10kT,
    currentProduction10kT: input.currentProduction10kT,
    maImportQuota10kT: input.maImportQuota10kT,
  });
  return {
    title: input.title,
    source_kind: input.sourceKind,
    source_ref: input.sourceRef,
    stockpile_target_10k_t: input.stockpileTarget10kT,
    domestic_procurement_10k_t: input.domesticProcurement10kT,
    stockpile_threshold_10k_t: input.stockpileThreshold10kT,
    total_production_target_10k_t: input.totalProductionTarget10kT,
    current_production_10k_t: input.currentProduction10kT,
    ma_import_quota_10k_t: input.maImportQuota10kT,
    notes: input.notes,
    updated_at: new Date().toISOString(),
    ...metrics,
  };
}

export async function handleAltSupplyAction(params: {
  action: string;
  body: Record<string, unknown>;
  userId: string;
  db: AltSupplyDb;
}): Promise<AltSupplyActionResult> {
  const { action, body, userId, db } = params;

  if (action === "alt_supply.list") {
    const rawLimit = Number(body.limit ?? 30);
    const limit = Number.isFinite(rawLimit) && rawLimit > 0
      ? Math.min(100, Math.floor(rawLimit))
      : 30;
    const rows = await db.listScenarios(userId, limit);
    const scenarios = rows.map((row) => mapRowToScenario(row, userId));
    return { status: 200, body: { success: true, scenarios } };
  }

  if (action === "alt_supply.seed_defaults") {
    const existing = await db.listScenarios(userId, 5);
    if (existing.length > 0) {
      return {
        status: 200,
        body: {
          success: true,
          seeded: 0,
          scenarios: existing.map((row) => mapRowToScenario(row, userId)),
        },
      };
    }

    const defaults = [
      buildScenarioMetadata({
        title: "国内作況低下・MA米転用リスク警戒シナリオ",
        sourceKind: "manual",
        sourceRef: "https://www.maff.go.jp/",
        stockpileTarget10kT: DEFAULT_STOCKPILE_TARGET_10K_T,
        domesticProcurement10kT: 64.0,
        stockpileThreshold10kT: DEFAULT_PROCUREMENT_THRESHOLD_10K_T,
        totalProductionTarget10kT: DEFAULT_TOTAL_PRODUCTION_TARGET_10K_T,
        currentProduction10kT: 735.0,
        maImportQuota10kT: DEFAULT_MA_IMPORT_QUOTA_10K_T,
        notes: "備蓄適正水準100万tに対し国内調達64万t想定。MA米77万t活用圧力増大。",
      }),
      buildScenarioMetadata({
        title: "国内買入順調・適正備蓄回復ベースシナリオ",
        sourceKind: "manual",
        sourceRef: "https://www.maff.go.jp/",
        stockpileTarget10kT: DEFAULT_STOCKPILE_TARGET_10K_T,
        domesticProcurement10kT: 94.0,
        stockpileThreshold10kT: DEFAULT_PROCUREMENT_THRESHOLD_10K_T,
        totalProductionTarget10kT: DEFAULT_TOTAL_PRODUCTION_TARGET_10K_T,
        currentProduction10kT: 792.0,
        maImportQuota10kT: DEFAULT_MA_IMPORT_QUOTA_10K_T,
        notes: "国内作付維持により備蓄回復が進み、代替輸入転用リスクは低水準。",
      }),
    ];

    const inserted: AltSupplyScenarioRecord[] = [];
    for (const meta of defaults) {
      const row = await db.insertScenario(userId, meta);
      inserted.push(mapRowToScenario(row, userId));
    }
    return {
      status: 200,
      body: {
        success: true,
        seeded: inserted.length,
        scenarios: inserted.reverse(),
      },
    };
  }

  if (action === "alt_supply.create") {
    const title = asTrimmed(body.title, 120);
    if (!title) {
      return { status: 400, body: { error: "title is required" } };
    }
    const stockpileTarget = parseBoundedNumber(
      body.stockpile_target_10k_t ?? DEFAULT_STOCKPILE_TARGET_10K_T,
      0,
      500,
    );
    const domesticProcurement = parseBoundedNumber(
      body.domestic_procurement_10k_t,
      0,
      500,
    );
    const stockpileThreshold = parseBoundedNumber(
      body.stockpile_threshold_10k_t ?? DEFAULT_PROCUREMENT_THRESHOLD_10K_T,
      0,
      500,
    );
    const totalTarget = parseBoundedNumber(
      body.total_production_target_10k_t ??
        DEFAULT_TOTAL_PRODUCTION_TARGET_10K_T,
      1,
      2000,
    );
    const fallbackProd = body.total_production_target_10k_t ??
      DEFAULT_TOTAL_PRODUCTION_TARGET_10K_T;
    const currentProd = parseBoundedNumber(
      body.current_production_10k_t ?? fallbackProd,
      0,
      2000,
    );
    const maQuota = parseBoundedNumber(
      body.ma_import_quota_10k_t ?? DEFAULT_MA_IMPORT_QUOTA_10K_T,
      0,
      500,
    );

    if (
      stockpileTarget === null ||
      domesticProcurement === null ||
      stockpileThreshold === null ||
      totalTarget === null ||
      currentProd === null ||
      maQuota === null
    ) {
      return {
        status: 400,
        body: { error: "valid numeric supply quantities are required" },
      };
    }

    const row = await db.insertScenario(
      userId,
      buildScenarioMetadata({
        title,
        sourceKind: normalizeSourceKind(body.source_kind),
        sourceRef: asTrimmed(body.source_ref, 300),
        stockpileTarget10kT: stockpileTarget,
        domesticProcurement10kT: domesticProcurement,
        stockpileThreshold10kT: stockpileThreshold,
        totalProductionTarget10kT: totalTarget,
        currentProduction10kT: currentProd,
        maImportQuota10kT: maQuota,
        notes: asTrimmed(body.notes, 500),
      }),
    );
    return {
      status: 200,
      body: { success: true, scenario: mapRowToScenario(row, userId) },
    };
  }

  if (action === "alt_supply.update") {
    const id = asTrimmed(body.id, 128);
    if (!id) {
      return { status: 400, body: { error: "id is required" } };
    }
    const existingRow = await db.findScenarioById(userId, id);
    if (!existingRow) {
      return { status: 404, body: { error: "scenario not found" } };
    }
    const prev = mapRowToScenario(existingRow, userId);

    const title = body.title === undefined
      ? prev.title
      : asTrimmed(body.title, 120);
    if (!title) {
      return { status: 400, body: { error: "title cannot be empty" } };
    }

    const stockpileTarget = body.stockpile_target_10k_t === undefined
      ? prev.stockpile_target_10k_t
      : parseBoundedNumber(body.stockpile_target_10k_t, 0, 500);
    const domesticProcurement = body.domestic_procurement_10k_t === undefined
      ? prev.domestic_procurement_10k_t
      : parseBoundedNumber(body.domestic_procurement_10k_t, 0, 500);
    const stockpileThreshold = body.stockpile_threshold_10k_t === undefined
      ? prev.stockpile_threshold_10k_t
      : parseBoundedNumber(body.stockpile_threshold_10k_t, 0, 500);
    const totalTarget = body.total_production_target_10k_t === undefined
      ? prev.total_production_target_10k_t
      : parseBoundedNumber(body.total_production_target_10k_t, 1, 2000);
    const currentProd = body.current_production_10k_t === undefined
      ? prev.current_production_10k_t
      : parseBoundedNumber(body.current_production_10k_t, 0, 2000);
    const maQuota = body.ma_import_quota_10k_t === undefined
      ? prev.ma_import_quota_10k_t
      : parseBoundedNumber(body.ma_import_quota_10k_t, 0, 500);

    if (
      stockpileTarget === null ||
      domesticProcurement === null ||
      stockpileThreshold === null ||
      totalTarget === null ||
      currentProd === null ||
      maQuota === null
    ) {
      return {
        status: 400,
        body: { error: "valid numeric supply quantities are required" },
      };
    }

    const updated = await db.updateScenario(
      userId,
      id,
      buildScenarioMetadata({
        title,
        sourceKind: body.source_kind === undefined
          ? prev.source_kind
          : normalizeSourceKind(body.source_kind),
        sourceRef: body.source_ref === undefined
          ? prev.source_ref
          : asTrimmed(body.source_ref, 300),
        stockpileTarget10kT: stockpileTarget,
        domesticProcurement10kT: domesticProcurement,
        stockpileThreshold10kT: stockpileThreshold,
        totalProductionTarget10kT: totalTarget,
        currentProduction10kT: currentProd,
        maImportQuota10kT: maQuota,
        notes: body.notes === undefined
          ? prev.notes
          : asTrimmed(body.notes, 500),
      }),
    );
    return {
      status: 200,
      body: { success: true, scenario: mapRowToScenario(updated, userId) },
    };
  }

  return { status: 400, body: { error: `Unknown action: ${action}` } };
}
