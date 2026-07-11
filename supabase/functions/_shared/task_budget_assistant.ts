export type TaskBudgetAssistantEffort = "low" | "medium" | "high" | "xhigh";
export type TaskBudgetAssistantStatus =
  | "queued"
  | "running"
  | "completed"
  | "budget_safed"
  | "failed"
  | "cancelled";

export interface TaskBudgetAssistantDocument {
  title: string;
  content: string;
}

export interface TaskBudgetAssistantStep {
  step_index: number;
  title: string;
  status: "completed" | "skipped" | "budget_safed";
  input_tokens: number;
  output_tokens: number;
  notes: string;
}

export interface TaskBudgetAssistantRun {
  status: TaskBudgetAssistantStatus;
  consumed_tokens: number;
  progress_percent: number;
  summary: string;
  artifact: Record<string, unknown>;
  steps: TaskBudgetAssistantStep[];
}

export const MIN_TASK_BUDGET_TOKENS = 20_000;
export const MAX_TASK_BUDGET_TOKENS = 2_000_000;
const SAFE_STOP_RATIO = 0.92;

export function normalizeTaskBudgetTokens(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed)) return MIN_TASK_BUDGET_TOKENS;
  const rounded = Math.round(parsed);
  return Math.min(
    MAX_TASK_BUDGET_TOKENS,
    Math.max(MIN_TASK_BUDGET_TOKENS, rounded),
  );
}

export function normalizeTaskBudgetEffort(
  value: unknown,
): TaskBudgetAssistantEffort {
  return value === "low" || value === "medium" || value === "high" ||
      value === "xhigh"
    ? value
    : "medium";
}

export function normalizeTaskBudgetDocuments(
  value: unknown,
): TaskBudgetAssistantDocument[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item, index) => {
      const row: Record<string, unknown> = item && typeof item === "object"
        ? item as Record<string, unknown>
        : { content: item };
      const title = String(row.title ?? row.name ?? `Document ${index + 1}`)
        .trim();
      const content = String(row.content ?? row.text ?? "").trim();
      return { title: title || `Document ${index + 1}`, content };
    })
    .filter((item) => item.content.length > 0)
    .slice(0, 50);
}

export function estimateTaskTokens(text: string): number {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (!normalized) return 0;
  return Math.max(1, Math.ceil(normalized.length / 4));
}

function snippet(text: string, maxLength = 220): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength - 1).trimEnd()}...`;
}

function effortMultiplier(effort: TaskBudgetAssistantEffort): number {
  switch (effort) {
    case "low":
      return 0.8;
    case "high":
      return 1.25;
    case "xhigh":
      return 1.55;
    case "medium":
      return 1;
  }
}

export function runTaskBudgetAssistant(params: {
  objective: string;
  documents: TaskBudgetAssistantDocument[];
  budget_tokens: number;
  effort: TaskBudgetAssistantEffort;
}): TaskBudgetAssistantRun {
  const budgetTokens = normalizeTaskBudgetTokens(params.budget_tokens);
  const effort = normalizeTaskBudgetEffort(params.effort);
  const softLimit = Math.floor(budgetTokens * SAFE_STOP_RATIO);
  const documents = params.documents;
  const steps: TaskBudgetAssistantStep[] = [];
  const extracted: Array<Record<string, unknown>> = [];
  let consumed = estimateTaskTokens(params.objective) + 120;
  let safeStopped = false;

  documents.forEach((document, index) => {
    if (safeStopped) return;
    const inputTokens = estimateTaskTokens(document.content);
    const outputTokens = Math.max(
      80,
      Math.ceil(inputTokens * 0.12 * effortMultiplier(effort)),
    );
    const nextConsumption = consumed + inputTokens + outputTokens;
    if (nextConsumption >= softLimit) {
      const remaining = Math.max(0, budgetTokens - consumed);
      steps.push({
        step_index: steps.length + 1,
        title: `Safe stop before ${document.title}`,
        status: "budget_safed",
        input_tokens: 0,
        output_tokens: Math.min(160, remaining),
        notes:
          `Budget guard preserved partial results before processing document ${
            index + 1
          }.`,
      });
      consumed += Math.min(160, remaining);
      safeStopped = true;
      return;
    }

    consumed = nextConsumption;
    const keyPoints = document.content
      .split(/[\r\n.!?]+/)
      .map((line) => line.trim())
      .filter(Boolean)
      .slice(0, 3);
    extracted.push({
      title: document.title,
      token_estimate: inputTokens,
      key_points: keyPoints.length > 0
        ? keyPoints
        : [snippet(document.content)],
      suggested_folder: inferSuggestedFolder(document.title, document.content),
      excerpt: snippet(document.content),
    });
    steps.push({
      step_index: steps.length + 1,
      title: `Extract ${document.title}`,
      status: "completed",
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      notes: `${keyPoints.length || 1} visible points extracted.`,
    });
  });

  if (!safeStopped && documents.length > 0) {
    const aggregateInput = Math.max(160, extracted.length * 90);
    const aggregateOutput = Math.max(240, extracted.length * 120);
    const nextConsumption = consumed + aggregateInput + aggregateOutput;
    if (nextConsumption >= softLimit) {
      steps.push({
        step_index: steps.length + 1,
        title: "Save partial aggregate",
        status: "budget_safed",
        input_tokens: aggregateInput,
        output_tokens: Math.max(80, budgetTokens - consumed),
        notes: "Stopped near token budget and saved extracted document facts.",
      });
      consumed = Math.min(
        budgetTokens,
        consumed + Math.max(80, budgetTokens - consumed),
      );
      safeStopped = true;
    } else {
      consumed = nextConsumption;
      steps.push({
        step_index: steps.length + 1,
        title: "Aggregate cross-document findings",
        status: "completed",
        input_tokens: aggregateInput,
        output_tokens: aggregateOutput,
        notes: "Grouped extracted facts and file organization suggestions.",
      });
    }
  }

  const progress = documents.length === 0
    ? 0
    : Math.round((extracted.length / documents.length) * 100);
  const folders = groupFolders(extracted);
  const status: TaskBudgetAssistantStatus = safeStopped
    ? "budget_safed"
    : "completed";
  const summary = documents.length === 0
    ? "No documents were provided."
    : safeStopped
    ? `Processed ${extracted.length}/${documents.length} documents before the token budget guard stopped safely.`
    : `Processed ${documents.length} documents and saved cross-document findings.`;

  return {
    status,
    consumed_tokens: Math.min(consumed, budgetTokens),
    progress_percent: safeStopped ? Math.min(progress, 95) : 100,
    summary,
    artifact: {
      objective: params.objective,
      effort,
      document_count: documents.length,
      extracted,
      folders,
      safe_stop: safeStopped,
    },
    steps,
  };
}

function inferSuggestedFolder(title: string, content: string): string {
  const text = `${title}\n${content}`.toLowerCase();
  if (/invoice|receipt|payment|expense|budget|finance/.test(text)) {
    return "Finance";
  }
  if (/meeting|agenda|minutes|standup|retro/.test(text)) return "Meetings";
  if (/spec|requirement|design|roadmap|backlog/.test(text)) return "Specs";
  if (/research|source|reference|survey|benchmark/.test(text)) {
    return "Research";
  }
  return "Inbox Review";
}

function groupFolders(extracted: Array<Record<string, unknown>>) {
  const counts = new Map<string, number>();
  for (const item of extracted) {
    const folder = String(item.suggested_folder ?? "Inbox Review");
    counts.set(folder, (counts.get(folder) ?? 0) + 1);
  }
  return Array.from(counts.entries()).map(([folder, count]) => ({
    folder,
    count,
  }));
}
