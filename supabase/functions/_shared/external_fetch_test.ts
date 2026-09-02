import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  externalFetch,
  ExternalFetchError,
  externalFetchErrorPayload,
  TEMPORARY_EXTERNAL_ERROR_MESSAGE,
} from "./external_fetch.ts";

Deno.test("externalFetch retries retryable HTTP statuses", async () => {
  let calls = 0;
  const delays: number[] = [];
  const response = await externalFetch(
    "test-api",
    "https://example.test/resource",
    {},
    {
      retries: 2,
      baseDelayMs: 100,
      sleep: (ms) => {
        delays.push(ms);
        return Promise.resolve();
      },
      fetcher: () => {
        calls += 1;
        return Promise.resolve(
          calls < 3
            ? new Response("temporary", { status: 503 })
            : new Response("ok", { status: 200 }),
        );
      },
    },
  );

  assertEquals(calls, 3);
  assertEquals(delays, [100, 200]);
  assertEquals(response.status, 200);
});

Deno.test("externalFetch returns non-retryable client errors", async () => {
  let calls = 0;
  const delays: number[] = [];
  const response = await externalFetch(
    "test-api",
    "https://example.test/resource",
    {},
    {
      retries: 2,
      sleep: (ms) => {
        delays.push(ms);
        return Promise.resolve();
      },
      fetcher: () => {
        calls += 1;
        return Promise.resolve(
          new Response("validation detail", {
            status: 400,
          }),
        );
      },
    },
  );

  assertEquals(response.status, 400);
  assertEquals(await response.text(), "validation detail");
  assertEquals(calls, 1);
  assertEquals(delays, []);
});

Deno.test("externalFetch honors bounded Retry-After for opted-in 429", async () => {
  let calls = 0;
  const delays: number[] = [];
  const response = await externalFetch(
    "notion",
    "https://example.test/resource",
    {},
    {
      retries: 1,
      baseDelayMs: 500,
      maxDelayMs: 1_500,
      retryStatuses: [429, 503],
      sleep: (ms) => {
        delays.push(ms);
        return Promise.resolve();
      },
      fetcher: () => {
        calls += 1;
        return Promise.resolve(
          calls === 1
            ? new Response("rate_limited", {
              status: 429,
              headers: { "Retry-After": "2" },
            })
            : new Response("ok", { status: 200 }),
        );
      },
    },
  );

  assertEquals(response.status, 200);
  assertEquals(calls, 2);
  assertEquals(delays, [1_500]);
});

Deno.test("externalFetch can add deterministic exponential jitter", async () => {
  let calls = 0;
  const delays: number[] = [];
  await externalFetch("notion", "https://example.test/resource", {}, {
    retries: 1,
    baseDelayMs: 1_000,
    jitterRatio: 0.2,
    random: () => 0.5,
    sleep: (ms) => {
      delays.push(ms);
      return Promise.resolve();
    },
    fetcher: () => {
      calls += 1;
      return Promise.resolve(
        new Response(calls === 1 ? "temporary" : "ok", {
          status: calls === 1 ? 503 : 200,
        }),
      );
    },
  });

  assertEquals(delays, [1_100]);
});

Deno.test("externalFetch reports exhausted timeout as user-facing temporary error", async () => {
  const error = await assertRejects(
    () =>
      externalFetch("test-api", "https://example.test/resource", {}, {
        retries: 1,
        timeoutMs: 1_000,
        baseDelayMs: 0,
        sleep: async () => {},
        fetcher: async (_input, init) => {
          const signal = init?.signal;
          await new Promise((_resolve, reject) => {
            signal?.addEventListener("abort", () => {
              reject(new DOMException("Aborted", "AbortError"));
            });
          });
          return new Response("unreachable");
        },
      }),
    ExternalFetchError,
  );

  assertEquals(error.targetApi, "test-api");
  assertEquals(error.attempts, 2);
  assertEquals(error.errorType, "timeout");
  assertEquals(error.userMessage, TEMPORARY_EXTERNAL_ERROR_MESSAGE);
  assertEquals(
    externalFetchErrorPayload(error).user_message,
    TEMPORARY_EXTERNAL_ERROR_MESSAGE,
  );
});
