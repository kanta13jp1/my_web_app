import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { loadWorkerWakeConfiguration, wakeVideoWorker } from "./worker_wake.ts";

Deno.test("worker wake configuration requires HTTPS and a bounded secret", () => {
  const values = new Map([
    ["VIDEO_WORKER_WAKE_URL", "https://controller.example.test/wake"],
    ["VIDEO_WORKER_WAKE_TOKEN", "x".repeat(32)],
  ]);
  assertEquals(
    loadWorkerWakeConfiguration((key) => values.get(key)),
    {
      url: "https://controller.example.test/wake",
      token: "x".repeat(32),
    },
  );
  values.set("VIDEO_WORKER_WAKE_URL", "http://controller.example.test/wake");
  assertEquals(loadWorkerWakeConfiguration((key) => values.get(key)), null);
});

Deno.test("wake request sends only the job identifier with bearer auth", async () => {
  let receivedAuthorization = "";
  let receivedBody: unknown = null;
  await wakeVideoWorker(
    "11111111-1111-4111-8111-111111111111",
    {
      url: "https://controller.example.test/wake",
      token: "x".repeat(32),
    },
    async (input, init) => {
      const received = new Request(input, init);
      receivedAuthorization = received.headers.get("authorization") ?? "";
      receivedBody = await received.json();
      return Promise.resolve(new Response("{}", { status: 202 }));
    },
  );
  assertEquals(receivedAuthorization, `Bearer ${"x".repeat(32)}`);
  assertEquals(receivedBody, {
    job_id: "11111111-1111-4111-8111-111111111111",
  });
});

Deno.test("controller failure rejects queue admission", async () => {
  await assertRejects(
    () =>
      wakeVideoWorker(
        "11111111-1111-4111-8111-111111111111",
        {
          url: "https://controller.example.test/wake",
          token: "x".repeat(32),
        },
        () => Promise.resolve(new Response("{}", { status: 503 })),
      ),
    Error,
    "worker_wake_failed",
  );
});
