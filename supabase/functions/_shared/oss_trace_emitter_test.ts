import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildOtlpTracePayload,
  emitOssTraceFailOpen,
  type OssTraceSpanInput,
} from "./oss_trace_emitter.ts";

const SAMPLE_SPAN: OssTraceSpanInput = {
  traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
  spanId: "00f067aa0ba902b7",
  serviceName: "my_web_app-edge",
  operationName: "ai.intent.route",
  startTimeMs: 1700000000000,
  endTimeMs: 1700000000180,
  attributes: {
    "ai.provider": "groq",
    "ai.within_sla": true,
    "ai.latency_ms": 180,
  },
};

Deno.test(
  "emitOssTraceFailOpen skips cleanly when OTLP endpoint is unset",
  async () => {
    let called = false;
    const res = await emitOssTraceFailOpen({
      span: SAMPLE_SPAN,
      otlpEndpoint: null,
      fetchImpl: () => {
        called = true;
        return Promise.resolve(new Response("{}", { status: 200 }));
      },
    });

    assertEquals(called, false);
    assertEquals(res.outcome, "skipped_unconfigured");
    assertEquals(res.statusCode, null);
  },
);

Deno.test(
  "emitOssTraceFailOpen posts OTLP resourceSpans JSON and handles errors",
  async () => {
    let capturedBody = "";
    const okRes = await emitOssTraceFailOpen({
      span: SAMPLE_SPAN,
      otlpEndpoint: "http://localhost:4318/v1/traces",
      fetchImpl: (_input, init) => {
        capturedBody = String(init?.body ?? "");
        return Promise.resolve(new Response("{}", { status: 200 }));
      },
    });

    assertEquals(okRes.outcome, "sent");
    assertEquals(okRes.statusCode, 200);
    const parsed = JSON.parse(capturedBody) as Record<string, unknown>;
    assertExists(parsed.resourceSpans);

    const payload = buildOtlpTracePayload(SAMPLE_SPAN);
    assertExists(payload.resourceSpans);

    const errRes = await emitOssTraceFailOpen({
      span: SAMPLE_SPAN,
      otlpEndpoint: "http://localhost:4318/v1/traces",
      fetchImpl: () => Promise.resolve(new Response("err", { status: 503 })),
    });
    assertEquals(errRes.outcome, "failed_fail_open");
    assertEquals(errRes.statusCode, 503);
  },
);
