export type QueryReportState =
  | "trivial"
  | "reformulated"
  | "unclear"
  | "unknown";

export interface ParsedQueryReport {
  state: QueryReportState;
  reformulatedQuery: string | null;
  reason: string | null;
  raw: string;
}

export interface QueryRouteDecision {
  action: "search" | "clarify";
  state: QueryReportState;
  searchQuery: string;
  feedback: string | null;
  report: ParsedQueryReport;
}

const STATE_FIELDS = [
  "state",
  "status",
  "query_state",
  "queryStatus",
  "classification",
] as const;

const REFORMULATED_QUERY_FIELDS = [
  "reformulated_query",
  "reformulatedQuery",
  "reformulated",
  "rewritten_query",
  "rewrittenQuery",
  "search_query",
  "searchQuery",
  "query",
] as const;

const REASON_FIELDS = ["reason", "message", "feedback", "explanation"] as const;

function normalizeState(value: string): QueryReportState {
  const normalized = value.trim().toLowerCase();
  if (!normalized) return "unknown";
  if (
    normalized.includes("reformulated") ||
    normalized.includes("reformulate") ||
    normalized.includes("rewritten") ||
    normalized.includes("rewrite")
  ) {
    return "reformulated";
  }
  if (
    normalized.includes("unclear") ||
    normalized.includes("ambiguous") ||
    normalized.includes("clarify") ||
    normalized.includes("insufficient")
  ) {
    return "unclear";
  }
  if (
    normalized.includes("trivial") ||
    normalized.includes("clear") ||
    normalized.includes("answerable")
  ) {
    return "trivial";
  }
  return "unknown";
}

function firstJsonObject(text: string): Record<string, unknown> | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(text.slice(start, end + 1));
    if (
      typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
    ) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    return null;
  }
  return null;
}

function valueFromRecord(
  record: Record<string, unknown> | null,
  fields: readonly string[],
): string {
  if (!record) return "";
  const lowerFields = fields.map((field) => field.toLowerCase());
  for (const [key, value] of Object.entries(record)) {
    if (!lowerFields.includes(key.toLowerCase())) continue;
    if (typeof value === "string") return value.trim();
    if (typeof value === "number" || typeof value === "boolean") {
      return String(value);
    }
  }
  return "";
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function valueFromTags(text: string, fields: readonly string[]): string {
  for (const field of fields) {
    const escaped = escapeRegExp(field);
    const xmlPattern = new RegExp(
      `<${escaped}[^>]*>([\\s\\S]*?)<\\/${escaped}>`,
      "i",
    );
    const xmlMatch = text.match(xmlPattern);
    if (xmlMatch?.[1]) return xmlMatch[1].trim();

    const sentinelPattern = new RegExp(
      `<\\|${escaped}\\|>([\\s\\S]*?)<\\|\\/${escaped}\\|>`,
      "i",
    );
    const sentinelMatch = text.match(sentinelPattern);
    if (sentinelMatch?.[1]) return sentinelMatch[1].trim();
  }
  return "";
}

function valueFromLines(text: string, fields: readonly string[]): string {
  for (const field of fields) {
    const escaped = escapeRegExp(field);
    const pattern = new RegExp(`^\\s*${escaped}\\s*[:=]\\s*(.+)$`, "im");
    const match = text.match(pattern);
    if (match?.[1]) return match[1].trim();
  }
  return "";
}

function readValue(
  text: string,
  record: Record<string, unknown> | null,
  fields: readonly string[],
): string {
  return valueFromRecord(record, fields) ||
    valueFromTags(text, fields) ||
    valueFromLines(text, fields);
}

export function parseQueryReport(rawReport: string): ParsedQueryReport {
  const raw = rawReport.trim();
  const record = firstJsonObject(raw);
  const stateValue = readValue(raw, record, STATE_FIELDS);
  const reformulatedQuery = readValue(raw, record, REFORMULATED_QUERY_FIELDS);
  const reason = readValue(raw, record, REASON_FIELDS);

  return {
    state: normalizeState(stateValue || raw),
    reformulatedQuery: reformulatedQuery || null,
    reason: reason || null,
    raw,
  };
}

export function buildQueryRouteDecision(
  originalQuery: string,
  rawReport: string,
): QueryRouteDecision {
  const query = originalQuery.trim();
  const report = parseQueryReport(rawReport);

  if (report.state === "unclear") {
    return {
      action: "clarify",
      state: report.state,
      searchQuery: query,
      feedback: report.reason ??
        "入力意図が不明瞭です。検索対象、条件、知りたい結論をもう少し具体的にしてください。",
      report,
    };
  }

  if (report.state === "reformulated") {
    if (!report.reformulatedQuery) {
      return {
        action: "clarify",
        state: report.state,
        searchQuery: query,
        feedback:
          "クエリは再定式化が必要と判定されましたが、再検索用クエリが見つかりませんでした。検索語を具体化してください。",
        report,
      };
    }
    return {
      action: "search",
      state: report.state,
      searchQuery: report.reformulatedQuery,
      feedback: report.reason,
      report,
    };
  }

  return {
    action: "search",
    state: report.state,
    searchQuery: query,
    feedback: report.reason,
    report,
  };
}
