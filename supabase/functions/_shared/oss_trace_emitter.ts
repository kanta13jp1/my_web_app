export type TraceEmitOutcome =
  | "sent"
  | "skipped_unconfigured"
  | "failed_fail_open";

export const TRACE_EMIT_OUTCOME_LABELS = {
  sent: "OTLP送信成功",
  skipped_unconfigured: "エンドポイント未設定スキップ",
  failed_fail_open: "送信失敗（Fail-Open継続）",
} as const satisfies Record<TraceEmitOutcome, string>;

export interface OssTraceSpanInput {
  traceId: string;
  spanId: string;
  serviceName: string;
  operationName: string;
  startTimeMs: number;
  endTimeMs: number;
  attributes?: Record<string, string | number | boolean>;
}

export interface EmitOssTraceOptions {
  span: OssTraceSpanInput;
  otlpEndpoint?: string | null;
  authHeader?: string | null;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

export interface EmitOssTraceResult {
  outcome: TraceEmitOutcome;
  statusCode: number | null;
  errorMessage: string | null;
}

function toUnixNanoString(ms: number): string {
  const safeMs = Math.max(0, Math.round(ms));
  return `${safeMs}000000`;
}

export function buildOtlpTracePayload(
  span: OssTraceSpanInput,
): Record<string, unknown> {
  const attrs = Object.entries(span.attributes ?? {}).map(([key, value]) => {
    if (typeof value === "boolean") {
      return { key, value: { boolValue: value } };
    }
    if (typeof value === "number") {
      return { key, value: { doubleValue: value } };
    }
    return { key, value: { stringValue: String(value) } };
  });

  return {
    resourceSpans: [
      {
        resource: {
          attributes: [
            {
              key: "service.name",
              value: { stringValue: span.serviceName },
            },
          ],
        },
        scopeSpans: [
          {
            scope: { name: "my_web_app.oss_trace_emitter" },
            spans: [
              {
                traceId: span.traceId,
                spanId: span.spanId,
                name: span.operationName,
                startTimeUnixNano: toUnixNanoString(span.startTimeMs),
                endTimeUnixNano: toUnixNanoString(span.endTimeMs),
                attributes: attrs,
              },
            ],
          },
        ],
      },
    ],
  };
}

function resolveOtlpEndpoint(explicit?: string | null): string | null {
  if (explicit !== undefined) {
    const trimmed = explicit?.trim() ?? "";
    return trimmed.length > 0 ? trimmed : null;
  }
  try {
    const fromEnv = Deno.env.get("OTLP_TRACES_ENDPOINT")?.trim() ?? "";
    return fromEnv.length > 0 ? fromEnv : null;
  } catch {
    return null;
  }
}

export async function emitOssTraceFailOpen(
  options: EmitOssTraceOptions,
): Promise<EmitOssTraceResult> {
  const endpoint = resolveOtlpEndpoint(options.otlpEndpoint);
  if (!endpoint) {
    return {
      outcome: "skipped_unconfigured",
      statusCode: null,
      errorMessage: null,
    };
  }

  const fetcher = options.fetchImpl ?? fetch;
  const timeoutMs = Math.max(100, options.timeoutMs ?? 1000);
  const controller = new AbortController();
  const timerId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (options.authHeader?.trim()) {
      headers.Authorization = options.authHeader.trim();
    }

    const res = await fetcher(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(buildOtlpTracePayload(options.span)),
      signal: controller.signal,
    });

    if (!res.ok) {
      return {
        outcome: "failed_fail_open",
        statusCode: res.status,
        errorMessage: `HTTP ${res.status}`,
      };
    }

    return {
      outcome: "sent",
      statusCode: res.status,
      errorMessage: null,
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return {
      outcome: "failed_fail_open",
      statusCode: null,
      errorMessage: msg,
    };
  } finally {
    clearTimeout(timerId);
  }
}
