import { runScheduledHealthcheck } from "./llm_healthcheck_runner.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(
      `Assertion failed: expected ${String(expected)}, got ${String(actual)}`,
    );
  }
}

Deno.test("blocks SSRF target and notifies on down provider", async () => {
  const sent: string[] = [];
  const res = await runScheduledHealthcheck({
    targets: [
      {
        provider_name: "Unsafe Local",
        endpoint_url: "https://127.0.0.1/health",
      },
      {
        provider_name: "Healthy LLM",
        endpoint_url: "https://api.example.com/health",
      },
    ],
    dryRun: false,
    webhookUrl: "https://hooks.example.com/alerts",
    fetcher: (input, init) => {
      const url = typeof input === "string" ? input : String(input);
      if (url.includes("hooks.example.com")) {
        sent.push(String(init?.body ?? ""));
        return Promise.resolve(new Response("ok", { status: 200 }));
      }
      return Promise.resolve(new Response("ok", { status: 200 }));
    },
  });

  assertEquals(res.total_targets, 2);
  assertEquals(res.down_count, 1);
  assertEquals(res.results[0].error_type, "ssrf_blocked");
  assertEquals(res.results[1].status, "healthy");
  assertEquals(res.alert_delivery, "notified");
  assertEquals(sent.length, 1);
});

Deno.test("dryRun skips network probes and external webhooks", async () => {
  const res = await runScheduledHealthcheck({
    targets: [
      {
        provider_name: "Custom LLM",
        endpoint_url: "https://api.example.com/v1/health",
      },
    ],
    dryRun: true,
    webhookUrl: "https://hooks.example.com/alerts",
  });
  assertEquals(res.down_count, 0);
  assertEquals(res.results[0].status, "healthy");
  assertEquals(res.alert_delivery, "not_needed");
});
