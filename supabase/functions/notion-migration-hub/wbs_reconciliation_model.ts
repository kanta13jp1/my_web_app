export type WbsMirrorRecord = {
  id: string;
  title: string;
  instance: string;
  status: string;
  progress: number;
  deadline: string | null;
  updatedAt: string | null;
};

export type WbsMirrorField =
  | "title"
  | "instance"
  | "status"
  | "progress"
  | "deadline"
  | "updated_at";

export type WbsMirrorReconciliation = {
  siteRows: number;
  notionRows: number;
  siteDistinctIds: number;
  notionDistinctIds: number;
  siteDuplicateRows: number;
  notionDuplicateRows: number;
  siteInvalidIds: number;
  notionInvalidIds: number;
  onlyInSite: number;
  onlyInNotion: number;
  exactMatches: number;
  mismatchedRecords: number;
  mismatchedFields: Record<WbsMirrorField, number>;
  deletionGatePassed: boolean;
};

export type WbsStagingInput = {
  sourcePageId: string;
  record: WbsMirrorRecord;
  sourceLastEditedAt: unknown;
  sourcePayload: Record<string, unknown>;
};

export type WbsStagingRow = {
  sourcePageId: string;
  taskId: string;
  duplicateOrdinal: number;
  title: string;
  instance: string;
  status: string;
  progress: number;
  deadline: string | null;
  sourceUpdatedAt: string | null;
  sourceLastEditedAt: string | null;
  sourcePayload: Record<string, unknown>;
};

const mirrorFields: readonly WbsMirrorField[] = [
  "title",
  "instance",
  "status",
  "progress",
  "deadline",
  "updated_at",
];

function normalizeId(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

function normalizeInstance(value: unknown): string {
  const instance = String(value ?? "win").trim();
  if (instance === "all") return "codex";
  if (instance === "copilot" || instance === "github-copilot") {
    return "co-pilot";
  }
  return instance || "win";
}

function normalizeStatus(value: unknown): string {
  const status = String(value ?? "pending").trim();
  if (status === "in-progress") return "in_progress";
  if (status === "not_started" || status === "draft") return "pending";
  if (status === "done") return "completed";
  return status || "pending";
}

function normalizeProgress(value: unknown): number {
  const progress = Number(value ?? 0);
  return Number.isFinite(progress) ? progress : 0;
}

function normalizeDate(value: unknown): string | null {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? text : parsed.toISOString();
}

function normalizeDeadline(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text ? text.slice(0, 10) : null;
}

export function wbsMirrorRecord(input: {
  id: unknown;
  title: unknown;
  instance: unknown;
  status: unknown;
  progress: unknown;
  deadline: unknown;
  updatedAt: unknown;
}): WbsMirrorRecord {
  return {
    id: normalizeId(input.id),
    title: String(input.title ?? ""),
    instance: normalizeInstance(input.instance),
    status: normalizeStatus(input.status),
    progress: normalizeProgress(input.progress),
    deadline: normalizeDeadline(input.deadline),
    updatedAt: normalizeDate(input.updatedAt),
  };
}

export function prepareWbsStagingRows(
  inputs: readonly WbsStagingInput[],
): WbsStagingRow[] {
  const sourcePageIds = new Set<string>();
  const taskOccurrences = new Map<string, number>();

  return inputs.map((input) => {
    const sourcePageId = String(input.sourcePageId ?? "").trim();
    if (!sourcePageId) throw new Error("wbs_stage_source_page_id_required");
    if (sourcePageIds.has(sourcePageId)) {
      throw new Error("wbs_stage_duplicate_source_page_id");
    }
    sourcePageIds.add(sourcePageId);

    const taskId = input.record.id;
    const duplicateOrdinal = taskId
      ? (taskOccurrences.get(taskId) ?? 0) + 1
      : 1;
    if (taskId) taskOccurrences.set(taskId, duplicateOrdinal);

    return {
      sourcePageId,
      taskId,
      duplicateOrdinal,
      title: input.record.title,
      instance: input.record.instance,
      status: input.record.status,
      progress: input.record.progress,
      deadline: input.record.deadline,
      sourceUpdatedAt: input.record.updatedAt,
      sourceLastEditedAt: normalizeDate(input.sourceLastEditedAt),
      sourcePayload: input.sourcePayload,
    };
  });
}

function indexById(records: readonly WbsMirrorRecord[]): {
  records: Map<string, WbsMirrorRecord>;
  duplicateRows: number;
  invalidIds: number;
} {
  const indexed = new Map<string, WbsMirrorRecord>();
  let duplicateRows = 0;
  let invalidIds = 0;
  for (const record of records) {
    if (!record.id) {
      invalidIds += 1;
      continue;
    }
    if (indexed.has(record.id)) {
      duplicateRows += 1;
      continue;
    }
    indexed.set(record.id, record);
  }
  return { records: indexed, duplicateRows, invalidIds };
}

function differingFields(
  site: WbsMirrorRecord,
  notion: WbsMirrorRecord,
): WbsMirrorField[] {
  const fields: WbsMirrorField[] = [];
  if (site.title !== notion.title) fields.push("title");
  if (site.instance !== notion.instance) fields.push("instance");
  if (site.status !== notion.status) fields.push("status");
  if (site.progress !== notion.progress) fields.push("progress");
  if (site.deadline !== notion.deadline) fields.push("deadline");
  if (site.updatedAt !== notion.updatedAt) fields.push("updated_at");
  return fields;
}

export function reconcileWbsMirror(
  siteRows: readonly WbsMirrorRecord[],
  notionRows: readonly WbsMirrorRecord[],
): WbsMirrorReconciliation {
  const site = indexById(siteRows);
  const notion = indexById(notionRows);
  const mismatchedFields = Object.fromEntries(
    mirrorFields.map((field) => [field, 0]),
  ) as Record<WbsMirrorField, number>;
  let onlyInSite = 0;
  let exactMatches = 0;
  let mismatchedRecords = 0;

  for (const [id, siteRecord] of site.records) {
    const notionRecord = notion.records.get(id);
    if (!notionRecord) {
      onlyInSite += 1;
      continue;
    }
    const differences = differingFields(siteRecord, notionRecord);
    if (differences.length === 0) {
      exactMatches += 1;
      continue;
    }
    mismatchedRecords += 1;
    for (const field of differences) mismatchedFields[field] += 1;
  }

  let onlyInNotion = 0;
  for (const id of notion.records.keys()) {
    if (!site.records.has(id)) onlyInNotion += 1;
  }

  const deletionGatePassed = siteRows.length > 0 &&
    notionRows.length > 0 &&
    site.duplicateRows === 0 &&
    notion.duplicateRows === 0 &&
    site.invalidIds === 0 &&
    notion.invalidIds === 0 &&
    onlyInSite === 0 &&
    onlyInNotion === 0 &&
    mismatchedRecords === 0 &&
    exactMatches === site.records.size &&
    exactMatches === notion.records.size;

  return {
    siteRows: siteRows.length,
    notionRows: notionRows.length,
    siteDistinctIds: site.records.size,
    notionDistinctIds: notion.records.size,
    siteDuplicateRows: site.duplicateRows,
    notionDuplicateRows: notion.duplicateRows,
    siteInvalidIds: site.invalidIds,
    notionInvalidIds: notion.invalidIds,
    onlyInSite,
    onlyInNotion,
    exactMatches,
    mismatchedRecords,
    mismatchedFields,
    deletionGatePassed,
  };
}
