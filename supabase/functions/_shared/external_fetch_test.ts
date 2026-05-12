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
  const response = await externalFetch(
    "test-api",
    "https://example.test/resource",
    {},
    {
      retries: 2,
      baseDelayMs: 0,
      sleep: async () => {},
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
  assertEquals(response.status, 200);
});

Deno.test("externalFetch returns non-retryable client errors", async () => {
  const response = await externalFetch(
    "test-api",
    "https://example.test/resource",
    {},
    {
      retries: 2,
      fetcher: () =>
        Promise.resolve(new Response("bad request", { status: 400 })),
    },
  );

  assertEquals(response.status, 400);
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
