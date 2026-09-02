import { assertEquals } from "jsr:@std/assert@1";
import { corsHeaders } from "./edge.ts";
import { requestTraceId } from "./trace_context.ts";

Deno.test("shared CORS allows W3C and Sentry trace headers", () => {
  const allowed = corsHeaders["Access-Control-Allow-Headers"];
  for (
    const header of ["traceparent", "tracestate", "baggage", "sentry-trace"]
  ) {
    assertEquals(allowed.includes(header), true);
  }
});

Deno.test("ai-hub browser CORS allows propagated trace headers", async () => {
  const source = await Deno.readTextFile(
    new URL("../ai-hub/index.ts", import.meta.url),
  );
  for (
    const header of ["traceparent", "tracestate", "baggage", "sentry-trace"]
  ) {
    assertEquals(source.includes(header), true);
  }
  assertEquals(source.includes("requestTraceId(req, body.trace_id)"), true);
});

Deno.test("health-check returns and logs the propagated trace ID", async () => {
  const source = await Deno.readTextFile(
    new URL("../health-check/index.ts", import.meta.url),
  );
  assertEquals(source.includes("const traceId = requestTraceId(req)"), true);
  assertEquals(source.includes("trace_id: traceId"), true);
  assertEquals(source.includes('"X-Trace-Id": traceId'), true);
  assertEquals(source.includes('event: "health_check.completed"'), true);
});

async function* typescriptFiles(directory: URL): AsyncGenerator<URL> {
  for await (const entry of Deno.readDir(directory)) {
    const child = new URL(
      entry.name + (entry.isDirectory ? "/" : ""),
      directory,
    );
    if (entry.isDirectory) {
      yield* typescriptFiles(child);
    } else if (entry.isFile && entry.name.endsWith(".ts")) {
      yield child;
    }
  }
}

Deno.test("every Edge CORS declaration allows trace propagation", async () => {
  let checked = 0;
  for await (const file of typescriptFiles(new URL("../", import.meta.url))) {
    const source = await Deno.readTextFile(file);
    if (!source.includes("Access-Control-Allow-Headers")) continue;
    checked += 1;
    for (
      const header of ["traceparent", "tracestate", "baggage", "sentry-trace"]
    ) {
      assertEquals(
        source.includes(header),
        true,
        `${file.pathname} misses ${header}`,
      );
    }
  }
  assertEquals(checked >= 27, true);
});

Deno.test("requestTraceId correlates a valid W3C request", () => {
  const req = new Request("https://example.test", {
    headers: {
      traceparent: "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
    },
  });
  assertEquals(
    requestTraceId(req, "legacy-id"),
    "0123456789abcdef0123456789abcdef",
  );
});

Deno.test("requestTraceId keeps a safe legacy ID without W3C context", () => {
  const req = new Request("https://example.test");
  assertEquals(requestTraceId(req, "legacy.trace-42"), "legacy.trace-42");
});

Deno.test("requestTraceId rejects malformed or sensitive caller input", () => {
  const req = new Request("https://example.test", {
    headers: { traceparent: "00-invalid-secret-value-01" },
  });
  assertEquals(
    requestTraceId(req, "prompt body\nsecret", () => "safe-fallback"),
    "safe-fallback",
  );
});

Deno.test("requestTraceId rejects all-zero W3C trace and parent IDs", () => {
  for (
    const traceparent of [
      "00-00000000000000000000000000000000-0123456789abcdef-01",
      "00-0123456789abcdef0123456789abcdef-0000000000000000-01",
    ]
  ) {
    const req = new Request("https://example.test", {
      headers: { traceparent },
    });
    assertEquals(requestTraceId(req, undefined, () => "safe"), "safe");
  }
});
