export type WbsListPagination = {
  limit: number;
  offset: number;
};

export type WbsTaskDedupeResult = {
  tasks: Array<Record<string, unknown>>;
  duplicateRowsRemoved: number;
};

function boundedInteger(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  const parsed = Math.trunc(Number(value));
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

export function normalizeWbsListPagination(
  body: Record<string, unknown>,
): WbsListPagination {
  return {
    limit: boundedInteger(body.limit, 50, 1, 200),
    offset: boundedInteger(body.offset, 0, 0, 100_000),
  };
}

export function dedupeWbsTasksById(
  tasks: Array<Record<string, unknown>>,
): WbsTaskDedupeResult {
  const seen = new Set<string>();
  const deduped: Array<Record<string, unknown>> = [];

  for (const task of tasks) {
    const id = String(task.id ?? "").trim();
    if (!id) {
      deduped.push(task);
      continue;
    }
    if (seen.has(id)) continue;
    seen.add(id);
    deduped.push(task);
  }

  return {
    tasks: deduped,
    duplicateRowsRemoved: tasks.length - deduped.length,
  };
}

export function paginateWbsTasks(
  tasks: Array<Record<string, unknown>>,
  pagination: WbsListPagination,
): Array<Record<string, unknown>> {
  return tasks.slice(pagination.offset, pagination.offset + pagination.limit);
}
