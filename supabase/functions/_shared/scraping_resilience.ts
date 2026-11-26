export const DEFAULT_SCRAPE_USER_AGENT_APP = "MyWebAppMonitor";
export const DEFAULT_SCRAPE_USER_AGENT_VERSION = "1.0";
export const DEFAULT_SCRAPE_CONTACT_URL = "https://my-web-app-b67f4.web.app";
export const DEFAULT_DLQ_RETRY_DELAY_MS = 60 * 60 * 1_000; // 1 hour
export const DEFAULT_BACKOFF_BASE_MS = 1_000;
export const DEFAULT_BACKOFF_MAX_MS = 60_000;
export const DEFAULT_MAX_DLQ_ATTEMPTS = 5;

export type ScrapeAbortReason =
  | "none"
  | "service_unavailable_503"
  | "rate_limited_429"
  | "captcha_detected"
  | "transient_http_error"
  | "network_error";

export const SCRAPE_ABORT_LABELS = {
  none: "正常完了",
  service_unavailable_503: "503一時停止(即中断)",
  rate_limited_429: "429レート制限(即中断)",
  captcha_detected: "CAPTCHA検知(即中断・回避禁止)",
  transient_http_error: "一時的HTTPエラー",
  network_error: "ネットワークエラー",
} as const satisfies Record<ScrapeAbortReason, string>;

export interface UserAgentOptions {
  appName?: string;
  version?: string;
  contactUrl?: string;
}

export interface ScrapeTask {
  taskId: string;
  targetUrl: string;
  sourceName: string;
  attempt?: number;
}

export interface DlqEntry {
  taskId: string;
  targetUrl: string;
  sourceName: string;
  reason: ScrapeAbortReason;
  statusCode: number | null;
  captchaDetected: boolean;
  attempts: number;
  backoffMs: number;
  nextRetryAt: string | null;
  manualReviewRequired: boolean;
  createdAt: string;
}

export interface DlqStore {
  enqueue(entry: DlqEntry): Promise<void>;
  listDue(nowIso: string): Promise<DlqEntry[]>;
  listAll(): Promise<DlqEntry[]>;
  markCompleted(taskId: string): Promise<void>;
}

export type FetchFn = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type SleepFn = (ms: number) => Promise<void>;

export interface ResilientScrapeResult {
  ok: boolean;
  status: number | null;
  body: string;
  attempts: number;
  abortedImmediately: boolean;
  captchaDetected: boolean;
  reason: ScrapeAbortReason;
  reasonLabel: string;
  backoffMs: number;
  dlqEntry: DlqEntry | null;
}

const CAPTCHA_PATTERNS: RegExp[] = [
  /\bcaptcha\b/i,
  /\brecaptcha\b/i,
  /\bhcaptcha\b/i,
  /cloudflare\s+turnstile/i,
  /cf-challenge/i,
  /verify\s+you\s+are\s+human/i,
  /automated\s+access/i,
  /robot\s+check/i,
  /\baltcha\b/i,
];

export function buildCompliantUserAgent(
  options: UserAgentOptions = {},
): string {
  const appName = (options.appName ?? DEFAULT_SCRAPE_USER_AGENT_APP)
    .replace(/[\r\n]/g, "")
    .trim();
  const version = (options.version ?? DEFAULT_SCRAPE_USER_AGENT_VERSION)
    .replace(/[\r\n]/g, "")
    .trim();
  const contactUrl = (options.contactUrl ?? DEFAULT_SCRAPE_CONTACT_URL)
    .replace(/[\r\n]/g, "")
    .trim();
  return `${appName}/${version} (+${contactUrl})`;
}

export function detectCaptchaInBody(body: string): boolean {
  if (!body) return false;
  return CAPTCHA_PATTERNS.some((pattern) => pattern.test(body));
}

export function parseRetryAfterMs(
  headerValue: string | null,
  nowMs: number,
): number | null {
  if (!headerValue) return null;
  const trimmed = headerValue.trim();
  const seconds = Number(trimmed);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.round(seconds * 1_000);
  }
  const parsedDate = Date.parse(trimmed);
  if (Number.isFinite(parsedDate)) {
    return Math.max(0, parsedDate - nowMs);
  }
  return null;
}

export function computeBackoffDelayMs(params: {
  attempt: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  retryAfterMs?: number | null;
}): number {
  const base = Math.max(100, params.baseDelayMs ?? DEFAULT_BACKOFF_BASE_MS);
  const max = Math.max(base, params.maxDelayMs ?? DEFAULT_BACKOFF_MAX_MS);
  const exp = Math.min(
    max,
    base * Math.pow(2, Math.max(0, params.attempt - 1)),
  );
  if (params.retryAfterMs !== null && params.retryAfterMs !== undefined) {
    return Math.max(exp, params.retryAfterMs);
  }
  return exp;
}

export class InMemoryDlqStore implements DlqStore {
  private readonly entries = new Map<string, DlqEntry>();

  enqueue(entry: DlqEntry): Promise<void> {
    this.entries.set(entry.taskId, entry);
    return Promise.resolve();
  }

  listDue(nowIso: string): Promise<DlqEntry[]> {
    const due: DlqEntry[] = [];
    for (const entry of this.entries.values()) {
      if (entry.manualReviewRequired || entry.captchaDetected) continue;
      if (entry.nextRetryAt !== null && entry.nextRetryAt <= nowIso) {
        due.push(entry);
      }
    }
    return Promise.resolve(due);
  }

  listAll(): Promise<DlqEntry[]> {
    return Promise.resolve([...this.entries.values()]);
  }

  markCompleted(taskId: string): Promise<void> {
    this.entries.delete(taskId);
    return Promise.resolve();
  }
}

export async function executeResilientScrape(params: {
  task: ScrapeTask;
  dlq: DlqStore;
  fetcher?: FetchFn;
  sleep?: SleepFn;
  now?: () => Date;
  maxRetries?: number;
  baseDelayMs?: number;
  dlqDelayMs?: number;
  userAgent?: UserAgentOptions;
}): Promise<ResilientScrapeResult> {
  const fetcher = params.fetcher ?? fetch;
  const sleep = params.sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  const now = params.now ?? (() => new Date());
  const maxRetries = Math.max(0, Math.floor(params.maxRetries ?? 2));
  const dlqDelayMs = Math.max(
    60_000,
    params.dlqDelayMs ?? DEFAULT_DLQ_RETRY_DELAY_MS,
  );
  const userAgent = buildCompliantUserAgent(params.userAgent);
  const priorAttempts = Math.max(0, Math.floor(params.task.attempt ?? 0));

  let attempts = 0;
  let lastStatus: number | null = null;
  let lastBody = "";
  let lastReason: ScrapeAbortReason = "transient_http_error";
  let lastBackoffMs = 0;
  let abortedImmediately = false;
  let captchaDetected = false;

  for (let i = 0; i <= maxRetries; i += 1) {
    attempts += 1;
    try {
      const response = await fetcher(params.task.targetUrl, {
        method: "GET",
        headers: {
          "User-Agent": userAgent,
          Accept: "text/html,application/xhtml+xml,application/json",
        },
      });
      lastStatus = response.status;
      lastBody = await response.text();
      const nowMs = now().getTime();
      const retryAfterMs = parseRetryAfterMs(
        response.headers.get("Retry-After"),
        nowMs,
      );

      // Immediate abort on CAPTCHA detection — never solve or bypass.
      if (detectCaptchaInBody(lastBody)) {
        captchaDetected = true;
        abortedImmediately = true;
        lastReason = "captcha_detected";
        lastBackoffMs = computeBackoffDelayMs({
          attempt: priorAttempts + attempts,
          baseDelayMs: params.baseDelayMs,
          retryAfterMs,
        });
        break;
      }

      // Immediate abort on 503 / 429 rate-limit to respect target availability.
      if (response.status === 503 || response.status === 429) {
        abortedImmediately = true;
        lastReason = response.status === 503
          ? "service_unavailable_503"
          : "rate_limited_429";
        lastBackoffMs = computeBackoffDelayMs({
          attempt: priorAttempts + attempts,
          baseDelayMs: params.baseDelayMs,
          retryAfterMs,
        });
        break;
      }

      if (response.ok) {
        await params.dlq.markCompleted(params.task.taskId);
        return {
          ok: true,
          status: response.status,
          body: lastBody,
          attempts,
          abortedImmediately: false,
          captchaDetected: false,
          reason: "none",
          reasonLabel: SCRAPE_ABORT_LABELS.none,
          backoffMs: 0,
          dlqEntry: null,
        };
      }

      lastReason = "transient_http_error";
      lastBackoffMs = computeBackoffDelayMs({
        attempt: attempts,
        baseDelayMs: params.baseDelayMs,
        retryAfterMs,
      });
    } catch {
      lastReason = "network_error";
      lastBackoffMs = computeBackoffDelayMs({
        attempt: attempts,
        baseDelayMs: params.baseDelayMs,
      });
    }

    if (i < maxRetries) {
      await sleep(lastBackoffMs);
    }
  }

  const nowDate = now();
  const totalAttempts = priorAttempts + attempts;
  const manualReview = captchaDetected ||
    totalAttempts >= DEFAULT_MAX_DLQ_ATTEMPTS;
  const scheduledDelay = Math.max(dlqDelayMs, lastBackoffMs);
  const nextRetryAt = manualReview
    ? null
    : new Date(nowDate.getTime() + scheduledDelay).toISOString();

  const dlqEntry: DlqEntry = {
    taskId: params.task.taskId,
    targetUrl: params.task.targetUrl,
    sourceName: params.task.sourceName,
    reason: lastReason,
    statusCode: lastStatus,
    captchaDetected,
    attempts: totalAttempts,
    backoffMs: scheduledDelay,
    nextRetryAt,
    manualReviewRequired: manualReview,
    createdAt: nowDate.toISOString(),
  };
  await params.dlq.enqueue(dlqEntry);

  return {
    ok: false,
    status: lastStatus,
    body: lastBody,
    attempts,
    abortedImmediately,
    captchaDetected,
    reason: lastReason,
    reasonLabel: SCRAPE_ABORT_LABELS[lastReason],
    backoffMs: scheduledDelay,
    dlqEntry,
  };
}

export async function processDueDlqTasks(params: {
  dlq: DlqStore;
  fetcher?: FetchFn;
  sleep?: SleepFn;
  now?: () => Date;
}): Promise<ResilientScrapeResult[]> {
  const now = params.now ?? (() => new Date());
  const dueEntries = await params.dlq.listDue(now().toISOString());
  const results: ResilientScrapeResult[] = [];
  for (const entry of dueEntries) {
    const res = await executeResilientScrape({
      task: {
        taskId: entry.taskId,
        targetUrl: entry.targetUrl,
        sourceName: entry.sourceName,
        attempt: entry.attempts,
      },
      dlq: params.dlq,
      fetcher: params.fetcher,
      sleep: params.sleep,
      now: params.now,
    });
    results.push(res);
  }
  return results;
}
