export type WbsRescheduleTier =
  | "pinned"
  | "github_issue"
  | "feature_request"
  | "high"
  | "medium"
  | "low";

export type WbsTaskRecord = Record<string, unknown>;

export interface WbsScheduleUpdate {
  id: string;
  start_date: string;
  end_date: string;
  tier: WbsRescheduleTier;
  stagger_days: number;
  github_issue_number?: number;
  schedule_source: "pinned" | "computed";
}

interface QueueConfig {
  offset_days: number;
  duration_days: number;
  parallel_capacity: number;
}

export interface WbsRescheduleParams {
  high: QueueConfig;
  medium: QueueConfig;
  low: QueueConfig;
  feature_request: QueueConfig;
  github_issue: QueueConfig;
  pinned_issue_numbers: number[];
}

export interface WbsReschedulePlan {
  totalOpen: number;
  totalSkippedCompleted: number;
  updates: WbsScheduleUpdate[];
  byPriority: Record<string, {
    count: number;
    first_start: string;
    last_end: string;
  }>;
  sample: WbsScheduleUpdate[];
  today: string;
  params: WbsRescheduleParams;
}

interface PinnedIssueSchedule {
  start_date: string;
  end_date: string;
}

const ADDITIONAL_REQUEST_TEXT = "\u8ffd\u52a0\u8981\u671b";
const USER_REQUEST_CATEGORY_TEXT = "\u30e6\u30fc\u30b6\u30fc\u8981\u671b";

export const ASSET_MANAGEMENT_PINNED_ISSUE_SCHEDULE: Record<
  number,
  PinnedIssueSchedule
> = {
  2448: { start_date: "2026-05-17", end_date: "2026-05-18" },
  2449: { start_date: "2026-05-19", end_date: "2026-05-21" },
  2450: { start_date: "2026-05-22", end_date: "2026-05-23" },
  2451: { start_date: "2026-05-24", end_date: "2026-05-26" },
  2452: { start_date: "2026-05-27", end_date: "2026-05-28" },
  2453: { start_date: "2026-05-29", end_date: "2026-05-30" },
  2454: { start_date: "2026-05-31", end_date: "2026-06-02" },
  2455: { start_date: "2026-06-03", end_date: "2026-06-04" },
  2456: { start_date: "2026-06-05", end_date: "2026-06-05" },
  2520: { start_date: "2026-06-06", end_date: "2026-06-07" },
  2521: { start_date: "2026-06-08", end_date: "2026-06-09" },
  2522: { start_date: "2026-06-10", end_date: "2026-06-11" },
  2460: { start_date: "2026-06-12", end_date: "2026-06-12" },
  2461: { start_date: "2026-06-13", end_date: "2026-06-14" },
  2462: { start_date: "2026-06-15", end_date: "2026-06-15" },
  2463: { start_date: "2026-06-16", end_date: "2026-06-17" },
  2464: { start_date: "2026-06-18", end_date: "2026-06-18" },
  2465: { start_date: "2026-06-19", end_date: "2026-06-19" },
  2466: { start_date: "2026-06-20", end_date: "2026-06-21" },
  2467: { start_date: "2026-06-22", end_date: "2026-06-22" },
  2468: { start_date: "2026-06-23", end_date: "2026-06-24" },
  2469: { start_date: "2026-06-25", end_date: "2026-06-26" },
  2470: { start_date: "2026-06-27", end_date: "2026-06-28" },
  2471: { start_date: "2026-06-29", end_date: "2026-06-29" },
  2472: { start_date: "2026-06-30", end_date: "2026-07-01" },
  2473: { start_date: "2026-07-02", end_date: "2026-07-02" },
  2474: { start_date: "2026-07-03", end_date: "2026-07-03" },
  2475: { start_date: "2026-07-04", end_date: "2026-07-04" },
  2476: { start_date: "2026-07-05", end_date: "2026-07-05" },
  2477: { start_date: "2026-07-06", end_date: "2026-07-07" },
  2478: { start_date: "2026-07-08", end_date: "2026-07-08" },
  2479: { start_date: "2026-07-09", end_date: "2026-07-10" },
  2480: { start_date: "2026-07-11", end_date: "2026-07-11" },
  2481: { start_date: "2026-07-12", end_date: "2026-07-13" },
  2482: { start_date: "2026-07-14", end_date: "2026-07-14" },
  2483: { start_date: "2026-07-15", end_date: "2026-07-15" },
  2484: { start_date: "2026-07-16", end_date: "2026-07-16" },
  2485: { start_date: "2026-07-17", end_date: "2026-07-18" },
  2486: { start_date: "2026-07-19", end_date: "2026-07-20" },
  2487: { start_date: "2026-07-21", end_date: "2026-07-21" },
  2488: { start_date: "2026-07-22", end_date: "2026-07-22" },
  2489: { start_date: "2026-07-23", end_date: "2026-07-23" },
  2490: { start_date: "2026-07-24", end_date: "2026-07-24" },
  2491: { start_date: "2026-07-25", end_date: "2026-07-25" },
  2492: { start_date: "2026-07-26", end_date: "2026-07-27" },
  2493: { start_date: "2026-07-28", end_date: "2026-07-28" },
  2496: { start_date: "2026-07-29", end_date: "2026-07-29" },
  2497: { start_date: "2026-07-30", end_date: "2026-07-31" },
  2498: { start_date: "2026-08-01", end_date: "2026-08-01" },
  2499: { start_date: "2026-08-02", end_date: "2026-08-02" },
  2500: { start_date: "2026-08-03", end_date: "2026-08-03" },
  2501: { start_date: "2026-08-04", end_date: "2026-08-04" },
  2502: { start_date: "2026-08-05", end_date: "2026-08-06" },
  2503: { start_date: "2026-08-07", end_date: "2026-08-07" },
  2504: { start_date: "2026-08-08", end_date: "2026-08-08" },
  2505: { start_date: "2026-08-09", end_date: "2026-08-09" },
  2508: { start_date: "2026-08-10", end_date: "2026-08-11" },
};

function numberFromBody(
  body: Record<string, unknown>,
  key: string,
  defaultValue: number,
): number {
  const value = Number(body[key] ?? defaultValue);
  return Number.isFinite(value) ? value : defaultValue;
}

function queueConfig(
  offsetDays: number,
  durationDays: number,
  parallelCapacity: number,
): QueueConfig {
  return {
    offset_days: Math.max(0, offsetDays),
    duration_days: Math.max(0, durationDays),
    parallel_capacity: Math.max(1, parallelCapacity),
  };
}

function nestedNumber(
  value: unknown,
  key: string,
  defaultValue: number,
): number {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return defaultValue;
  }
  const raw = (value as Record<string, unknown>)[key];
  const num = Number(raw ?? defaultValue);
  return Number.isFinite(num) ? num : defaultValue;
}

export function resolveWbsRescheduleParams(
  body: Record<string, unknown> = {},
): WbsRescheduleParams {
  const offsetIn = body.priority_offset_days;
  const durIn = body.duration_days;
  const parIn = body.parallel_capacity;
  return {
    high: queueConfig(
      nestedNumber(offsetIn, "high", 7),
      nestedNumber(durIn, "high", 3),
      nestedNumber(parIn, "high", 2),
    ),
    medium: queueConfig(
      nestedNumber(offsetIn, "medium", 30),
      nestedNumber(durIn, "medium", 7),
      nestedNumber(parIn, "medium", 2),
    ),
    low: queueConfig(
      nestedNumber(offsetIn, "low", 90),
      nestedNumber(durIn, "low", 14),
      nestedNumber(parIn, "low", 2),
    ),
    feature_request: queueConfig(
      numberFromBody(body, "feature_request_offset_days", 30),
      numberFromBody(body, "feature_request_duration_days", 1),
      numberFromBody(body, "feature_request_parallel_capacity", 2),
    ),
    github_issue: queueConfig(
      numberFromBody(body, "github_issue_offset_days", 0),
      numberFromBody(body, "github_issue_duration_days", 2),
      numberFromBody(body, "github_issue_parallel_capacity", 2),
    ),
    pinned_issue_numbers: Object.keys(ASSET_MANAGEMENT_PINNED_ISSUE_SCHEDULE)
      .map((issue) => Number(issue))
      .sort((a, b) => a - b),
  };
}

function dateOnlyUtc(date: Date): Date {
  const copy = new Date(date);
  copy.setUTCHours(0, 0, 0, 0);
  return copy;
}

function formatIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function addDays(base: Date, days: number): Date {
  const d = new Date(base);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

function daysBetween(base: Date, dateText: string): number {
  const target = new Date(`${dateText}T00:00:00.000Z`);
  return Math.floor((target.getTime() - base.getTime()) / 86400000);
}

function githubIssueNumberFromTask(task: WbsTaskRecord): number | null {
  const raw = task.github_issue_number;
  if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) {
    return Math.trunc(raw);
  }
  const parsed = Number(raw);
  if (Number.isFinite(parsed) && parsed > 0) return Math.trunc(parsed);
  return null;
}

function hasAdditionalRequestText(value: unknown): boolean {
  return String(value ?? "").includes(ADDITIONAL_REQUEST_TEXT);
}

function isFeatureRequestTask(task: WbsTaskRecord): boolean {
  const category = String(task.category ?? "");
  const title = String(task.title ?? "");
  return category === USER_REQUEST_CATEGORY_TEXT ||
    hasAdditionalRequestText(category) ||
    hasAdditionalRequestText(title);
}

function isGithubIssueLinkedTask(task: WbsTaskRecord): boolean {
  return githubIssueNumberFromTask(task) !== null ||
    String(task.github_issue_state ?? "").trim() !== "";
}

function isOpenTask(task: WbsTaskRecord): boolean {
  return String(task.status ?? "") !== "completed" &&
    String(task.github_issue_state ?? "").toUpperCase() !== "CLOSED";
}

function wbsPriorityRank(priority: unknown): number {
  const value = String(priority ?? "").toLowerCase();
  if (value === "urgent") return 4;
  if (value === "high") return 3;
  if (value === "medium") return 2;
  if (value === "low") return 1;
  return 0;
}

function sortTasks(a: WbsTaskRecord, b: WbsTaskRecord): number {
  return wbsPriorityRank(b.priority) - wbsPriorityRank(a.priority) ||
    Number(a.category_order ?? 999) - Number(b.category_order ?? 999) ||
    String(a.id).localeCompare(String(b.id));
}

function scheduleQueue(
  updates: WbsScheduleUpdate[],
  tasks: WbsTaskRecord[],
  tier: WbsRescheduleTier,
  config: QueueConfig,
  today: Date,
  earliestOffsetDays: number,
): number {
  const startOffset = Math.max(config.offset_days, earliestOffsetDays);
  const sorted = [...tasks].sort(sortTasks);
  for (let i = 0; i < sorted.length; i++) {
    const task = sorted[i];
    const stagger = Math.floor(i / config.parallel_capacity);
    const start = addDays(today, startOffset + stagger);
    const end = addDays(start, config.duration_days);
    const issueNumber = githubIssueNumberFromTask(task);
    updates.push({
      id: String(task.id),
      start_date: formatIsoDate(start),
      end_date: formatIsoDate(end),
      tier,
      stagger_days: stagger,
      github_issue_number: issueNumber ?? undefined,
      schedule_source: "computed",
    });
  }
  if (sorted.length === 0) return earliestOffsetDays;
  return startOffset +
    Math.floor((sorted.length - 1) / config.parallel_capacity) +
    config.duration_days +
    1;
}

function buildSummary(
  updates: WbsScheduleUpdate[],
): Record<string, { count: number; first_start: string; last_end: string }> {
  const summary: Record<string, {
    count: number;
    first_start: string;
    last_end: string;
  }> = {};
  for (const update of updates) {
    const current = summary[update.tier] ?? {
      count: 0,
      first_start: update.start_date,
      last_end: update.end_date,
    };
    current.count += 1;
    if (update.start_date < current.first_start) {
      current.first_start = update.start_date;
    }
    if (update.end_date > current.last_end) current.last_end = update.end_date;
    summary[update.tier] = current;
  }
  return summary;
}

export function buildWbsReschedulePlan(
  tasks: WbsTaskRecord[],
  body: Record<string, unknown> = {},
  now = new Date(),
): WbsReschedulePlan {
  const today = dateOnlyUtc(now);
  const params = resolveWbsRescheduleParams(body);
  const open = tasks.filter(isOpenTask);
  const updates: WbsScheduleUpdate[] = [];
  const scheduledIds = new Set<string>();
  let pinnedEndOffsetExclusive = 0;

  for (const task of open) {
    const issueNumber = githubIssueNumberFromTask(task);
    if (!issueNumber) continue;
    const pinned = ASSET_MANAGEMENT_PINNED_ISSUE_SCHEDULE[issueNumber];
    if (!pinned) continue;
    const id = String(task.id);
    scheduledIds.add(id);
    updates.push({
      id,
      start_date: pinned.start_date,
      end_date: pinned.end_date,
      tier: "pinned",
      stagger_days: 0,
      github_issue_number: issueNumber,
      schedule_source: "pinned",
    });
    pinnedEndOffsetExclusive = Math.max(
      pinnedEndOffsetExclusive,
      daysBetween(today, pinned.end_date) + 1,
    );
  }

  const remaining = open.filter((task) => !scheduledIds.has(String(task.id)));
  const githubIssueTasks = remaining.filter(isGithubIssueLinkedTask);
  const featureRequestTasks = remaining.filter((task) =>
    !isGithubIssueLinkedTask(task) && isFeatureRequestTask(task)
  );
  const regularTasks = remaining.filter((task) =>
    !isGithubIssueLinkedTask(task) && !isFeatureRequestTask(task)
  );
  const regularBuckets: Record<"high" | "medium" | "low", WbsTaskRecord[]> = {
    high: [],
    medium: [],
    low: [],
  };
  for (const task of regularTasks) {
    const priority = String(task.priority ?? "medium").toLowerCase();
    const tier = priority === "high" || priority === "urgent"
      ? "high"
      : priority === "low"
      ? "low"
      : "medium";
    regularBuckets[tier].push(task);
  }

  const afterPinned = Math.max(0, pinnedEndOffsetExclusive);
  const afterGithubIssues = scheduleQueue(
    updates,
    githubIssueTasks,
    "github_issue",
    params.github_issue,
    today,
    afterPinned,
  );
  const afterHigh = scheduleQueue(
    updates,
    regularBuckets.high,
    "high",
    params.high,
    today,
    afterPinned,
  );
  const afterMedium = scheduleQueue(
    updates,
    regularBuckets.medium,
    "medium",
    params.medium,
    today,
    Math.max(afterPinned, afterHigh),
  );
  scheduleQueue(
    updates,
    featureRequestTasks,
    "feature_request",
    params.feature_request,
    today,
    Math.max(afterPinned, afterGithubIssues, afterMedium),
  );
  scheduleQueue(
    updates,
    regularBuckets.low,
    "low",
    params.low,
    today,
    afterPinned,
  );

  const orderedUpdates = updates.sort((a, b) =>
    a.start_date.localeCompare(b.start_date) ||
    a.end_date.localeCompare(b.end_date) ||
    a.tier.localeCompare(b.tier) ||
    a.id.localeCompare(b.id)
  );

  return {
    totalOpen: open.length,
    totalSkippedCompleted: tasks.length - open.length,
    updates: orderedUpdates,
    byPriority: buildSummary(orderedUpdates),
    sample: orderedUpdates.slice(0, 10),
    today: formatIsoDate(today),
    params,
  };
}
