export const TEMPORARY_EXTERNAL_ERROR_MESSAGE =
  "一時的な通信エラーが発生しました。時間をおいて再度お試しください。";

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

type Sleeper = (ms: number) => Promise<void>;

export interface ExternalFetchOptions {
  retries?: number;
  timeoutMs?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  retryStatuses?: number[];
  traceId?: string;
  fetcher?: Fetcher;
  sleep?: Sleeper;
}

export class ExternalFetchError extends Error {
  targetApi: string;
  attempts: number;
  status: number | null;
  errorType: "timeout" | "network" | "http";
  userMessage: string;
  responseBody: string;

  constructor(params: {
    targetApi: string;
    attempts: number;
    status?: number | null;
    errorType: "timeout" | "network" | "http";
    message: string;
    responseBody?: string;
  }) {
    super(params.message);
    this.name = "ExternalFetchError";
    this.targetApi = params.targetApi;
    this.attempts = params.attempts;
    this.status = params.status ?? null;
    this.errorType = params.errorType;
    this.userMessage = TEMPORARY_EXTERNAL_ERROR_MESSAGE;
    this.responseBody = params.responseBody ?? "";
  }
}

export function isExternalFetchError(
  value: unknown,
): value is ExternalFetchError {
  return value instanceof ExternalFetchError;
}

export function externalFetchErrorPayload(error: ExternalFetchError) {
  return {
    ok: false,
    temporary: true,
    target_api: error.targetApi,
    status: error.status,
    attempts: error.attempts,
    error_type: error.errorType,
    error: error.message,
    user_message: error.userMessage,
  };
}

export async function externalFetch(
  targetApi: string,
  input: string | URL | Request,
  init: RequestInit = {},
  options: ExternalFetchOptions = {},
): Promise<Response> {
  const retries = Math.max(0, Math.floor(options.retries ?? 3));
  const maxAttempts = retries + 1;
  const timeoutMs = Math.max(1_000, Math.floor(options.timeoutMs ?? 30_000));
  const baseDelayMs = Math.max(0, Math.floor(options.baseDelayMs ?? 500));
  const maxDelayMs = Math.max(
    baseDelayMs,
    Math.floor(options.maxDelayMs ?? 5_000),
  );
  const retryStatuses = new Set(
    options.retryStatuses ?? [408, 429, 500, 502, 503, 504],
  );
  const fetcher = options.fetcher ?? fetch;
  const sleep = options.sleep ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));

  let lastError: ExternalFetchError | null = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetcher(input, {
        ...init,
        signal: controller.signal,
      });
      if (!retryStatuses.has(response.status)) {
        return response;
      }

      const responseBody = await response.clone().text().catch(() => "");
      lastError = new ExternalFetchError({
        targetApi,
        attempts: attempt,
        status: response.status,
        errorType: "http",
        message: `${targetApi} returned retryable HTTP ${response.status}`,
        responseBody,
      });
    } catch (error) {
      const aborted = controller.signal.aborted;
      lastError = new ExternalFetchError({
        targetApi,
        attempts: attempt,
        status: null,
        errorType: aborted ? "timeout" : "network",
        message: `${targetApi} ${aborted ? "timed out" : "network failure"}: ${
          String(error)
        }`,
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (attempt < maxAttempts) {
      const delayMs = Math.min(maxDelayMs, baseDelayMs * 2 ** (attempt - 1));
      if (delayMs > 0) {
        await sleep(delayMs);
      }
    }
  }

  const error = lastError ??
    new ExternalFetchError({
      targetApi,
      attempts: maxAttempts,
      status: null,
      errorType: "network",
      message: `${targetApi} failed without response`,
    });
  logExternalFetchError(error, options.traceId);
  throw error;
}

function logExternalFetchError(error: ExternalFetchError, traceId?: string) {
  console.error(
    JSON.stringify({
      level: "ERROR",
      at: new Date().toISOString(),
      target_api: error.targetApi,
      status: error.status,
      attempts: error.attempts,
      error_type: error.errorType,
      error: error.message,
      response_body: error.responseBody.slice(0, 500),
      trace_id: traceId ?? null,
    }),
  );
}
