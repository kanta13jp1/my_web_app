import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCompliantUserAgent,
  DEFAULT_DLQ_RETRY_DELAY_MS,
  executeResilientScrape,
  InMemoryDlqStore,
  processDueDlqTasks,
} from "./scraping_resilience.ts";

Deno.test("buildCompliantUserAgent builds transparent service header", () => {
  const ua = buildCompliantUserAgent({
    appName: "MyWebAppPriceWatch",
    version: "2.0",
    contactUrl: "https://my-web-app-b67f4.web.app",
  });
  assertStringIncludes(ua, "MyWebAppPriceWatch/2.0");
  assertStringIncludes(ua, "https://my-web-app-b67f4.web.app");
});

Deno.test(
  "executeResilientScrape aborts immediately on 503 and schedules 1h DLQ",
  async () => {
    const dlq = new InMemoryDlqStore();
    let callCount = 0;
    const seenUa: string[] = [];
    const fixedNow = new Date("2026-11-26T05:00:00.000Z");

    const res = await executeResilientScrape({
      task: {
        taskId: "task-503",
        targetUrl: "https://example.com/item/1",
        sourceName: "example-shop",
      },
      dlq,
      now: () => fixedNow,
      sleep: () => Promise.resolve(),
      fetcher: (_input, init) => {
        callCount += 1;
        const headers = new Headers(init?.headers);
        seenUa.push(headers.get("User-Agent") ?? "");
        return Promise.resolve(
          new Response("Service Unavailable", { status: 503 }),
        );
      },
    });

    assertEquals(res.ok, false);
    assertEquals(res.abortedImmediately, true);
    assertEquals(res.reason, "service_unavailable_503");
    assertEquals(callCount, 1);
    assertEquals(seenUa[0].startsWith("MyWebAppMonitor/"), true);
    assertEquals(res.dlqEntry?.nextRetryAt, "2026-11-26T06:00:00.000Z");
    assertEquals(res.backoffMs >= DEFAULT_DLQ_RETRY_DELAY_MS, true);
  },
);

Deno.test(
  "executeResilientScrape aborts immediately on CAPTCHA with zero bypass",
  async () => {
    const dlq = new InMemoryDlqStore();
    let callCount = 0;

    const res = await executeResilientScrape({
      task: {
        taskId: "task-captcha",
        targetUrl: "https://example.com/item/2",
        sourceName: "example-shop",
      },
      dlq,
      now: () => new Date("2026-11-26T05:00:00.000Z"),
      sleep: () => Promise.resolve(),
      fetcher: () => {
        callCount += 1;
        return Promise.resolve(
          new Response("<html>Please verify you are human (reCAPTCHA)</html>", {
            status: 200,
          }),
        );
      },
    });

    assertEquals(res.ok, false);
    assertEquals(res.abortedImmediately, true);
    assertEquals(res.captchaDetected, true);
    assertEquals(res.reason, "captcha_detected");
    assertEquals(callCount, 1);
    assertEquals(res.dlqEntry?.manualReviewRequired, true);
    assertEquals(res.dlqEntry?.nextRetryAt, null);

    const due = await dlq.listDue("2026-11-26T08:00:00.000Z");
    assertEquals(due.length, 0);
  },
);

Deno.test(
  "executeResilientScrape aborts on 429 and processDueDlqTasks retries later",
  async () => {
    const dlq = new InMemoryDlqStore();
    let mode: "rate_limit" | "ok" = "rate_limit";

    const first = await executeResilientScrape({
      task: {
        taskId: "task-429",
        targetUrl: "https://example.com/item/3",
        sourceName: "example-shop",
      },
      dlq,
      now: () => new Date("2026-11-26T05:00:00.000Z"),
      sleep: () => Promise.resolve(),
      fetcher: () => {
        if (mode === "rate_limit") {
          return Promise.resolve(
            new Response("Too Many Requests", {
              status: 429,
              headers: { "Retry-After": "120" },
            }),
          );
        }
        return Promise.resolve(
          new Response("{\"price\":1980}", { status: 200 }),
        );
      },
    });

    assertEquals(first.ok, false);
    assertEquals(first.reason, "rate_limited_429");
    assertEquals(first.attempts, 1);

    // Not due yet at 05:30Z.
    const notDue = await processDueDlqTasks({
      dlq,
      now: () => new Date("2026-11-26T05:30:00.000Z"),
      sleep: () => Promise.resolve(),
      fetcher: () => Promise.resolve(new Response("ok", { status: 200 })),
    });
    assertEquals(notDue.length, 0);

    // Due at 06:05Z -> succeeds and clears from DLQ.
    mode = "ok";
    const retried = await processDueDlqTasks({
      dlq,
      now: () => new Date("2026-11-26T06:05:00.000Z"),
      sleep: () => Promise.resolve(),
      fetcher: () =>
        Promise.resolve(new Response("{\"price\":1980}", { status: 200 })),
    });
    assertEquals(retried.length, 1);
    assertEquals(retried[0].ok, true);
    assertEquals((await dlq.listAll()).length, 0);
  },
);
