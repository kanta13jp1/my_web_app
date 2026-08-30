import {
  assertEquals,
  assertObjectMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createResourceOptimizerHandler,
  parseOptimizerRequest,
  requestMentorPlan,
} from "./index.ts";

const jsonRequest = (body: unknown, headers: HeadersInit = {}) =>
  new Request("https://example.test/resource-optimizer", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json; charset=utf-8",
      ...headers,
    },
    body: JSON.stringify(body),
  });

Deno.test("request contract defaults to deterministic analysis", async () => {
  const result = await parseOptimizerRequest(jsonRequest({ days: 90 }));
  assertEquals(result, {
    ok: true,
    value: { days: 90, useAi: false, aiDataConsent: false },
  });
});

Deno.test("request contract requires explicit AI data consent", async () => {
  const result = await parseOptimizerRequest(
    jsonRequest({ days: 90, use_ai: true }),
  );
  assertObjectMatch(result, { ok: false, status: 400 });
});

Deno.test("request contract rejects invalid media type, shape, fields, and days", async () => {
  const cases = [
    new Request("https://example.test", {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: "{}",
    }),
    new Request("https://example.test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{invalid",
    }),
    jsonRequest([]),
    jsonRequest({ days: "90" }),
    jsonRequest({ days: 6 }),
    jsonRequest({ days: 90.5 }),
    jsonRequest({ days: 90, unexpected: true }),
  ];
  for (const request of cases) {
    const result = await parseOptimizerRequest(request);
    assertEquals(result.ok, false);
  }
});

Deno.test("request contract rejects oversized declared and streamed bodies", async () => {
  const declared = jsonRequest({}, { "content-length": "1025" });
  assertObjectMatch(await parseOptimizerRequest(declared), {
    ok: false,
    status: 413,
  });

  const streamed = jsonRequest({ padding: "x".repeat(1100) });
  assertObjectMatch(await parseOptimizerRequest(streamed), {
    ok: false,
    status: 413,
  });
});

const metric = {
  habit_id: "11111111-1111-4111-8111-111111111111",
  habit_title: "Focused work",
  goal_title: "Goal",
  sample_count: 8,
  avg_time_minutes: 20,
  avg_fatigue_score: 2,
  avg_goal_contribution_score: 80,
  performance_measurement_source: "self_reported_goal_contribution_proxy",
  performance_is_proxy: true,
  performance_sample_stddev: 4,
  has_sufficient_data: true,
  insufficient_data_reason: null,
  resource_cost_index: 40,
  efficiency_score: 2,
  time_performance_correlation: null,
  fatigue_performance_correlation: null,
  overall_time_performance_correlation: null,
  overall_fatigue_performance_correlation: null,
  is_pareto_optimal: true,
};

Deno.test("Gemini request keeps the key out of the URL and caps output", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const fetcher: typeof fetch = (input, init) => {
    capturedUrl = String(input);
    capturedInit = init;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          candidates: [{
            content: {
              parts: [{
                text: JSON.stringify({
                  mentor_summary: "Summary",
                  recommendations: [{
                    habit_id: metric.habit_id,
                    reason: "Reason",
                  }],
                  scaling_plan: [
                    {
                      duration_days: 7,
                      load_multiplier: 1,
                      target: "Target 1",
                      guardrail: "Guardrail 1",
                    },
                    {
                      duration_days: 14,
                      load_multiplier: 1.1,
                      target: "Target 2",
                      guardrail: "Guardrail 2",
                    },
                    {
                      duration_days: 21,
                      load_multiplier: 1.2,
                      target: "Target 3",
                      guardrail: "Guardrail 3",
                    },
                  ],
                }),
              }],
            },
          }],
        }),
        { status: 200 },
      ),
    );
  };

  const plan = await requestMentorPlan([metric], 90, "secret-key", fetcher);
  assertEquals(plan?.mentor_summary, "Summary");
  assertEquals(capturedUrl.includes("secret-key"), false);
  assertEquals(
    new Headers(capturedInit?.headers).get("x-goog-api-key"),
    "secret-key",
  );
  const body = JSON.parse(String(capturedInit?.body));
  assertEquals(body.generationConfig.maxOutputTokens, 1024);
});

Deno.test("Gemini prompt derives frontier IDs from the same first 50 metrics", async () => {
  let prompt = "";
  const allMetrics = Array.from({ length: 51 }, (_, index) => ({
    ...metric,
    habit_id: `habit-${index}`,
    habit_title: `Habit ${index}`,
  }));
  const fetcher: typeof fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body));
    prompt = body.contents[0].parts[0].text;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: "not-json" }] } }],
        }),
        { status: 200 },
      ),
    );
  };

  assertEquals(
    await requestMentorPlan(allMetrics, 90, "secret-key", fetcher),
    null,
  );
  assertEquals(prompt.includes('"habit_id":"habit-49"'), true);
  assertEquals(prompt.includes('"habit_id":"habit-50"'), false);
  assertEquals(prompt.includes('"habit-49"'), true);
  assertEquals(prompt.includes('"habit-50"'), false);
});

Deno.test("Gemini invalid JSON or invalid plan is not adopted", async () => {
  for (
    const text of [
      "not-json",
      JSON.stringify({ mentor_summary: "Only a summary" }),
      JSON.stringify({
        mentor_summary: "Summary",
        recommendations: [{ habit_id: "outside-frontier", reason: "Reason" }],
        scaling_plan: [],
      }),
      JSON.stringify({
        mentor_summary: "Summary",
        recommendations: [{ habit_id: metric.habit_id, reason: "Reason" }],
        scaling_plan: [
          {
            duration_days: 7,
            load_multiplier: 1,
            target: "Target",
            guardrail: "Guardrail",
          },
          {
            duration_days: 14,
            load_multiplier: 1,
            target: "Target",
            guardrail: "Guardrail",
          },
          {
            duration_days: 21,
            load_multiplier: 1,
            target: "Target",
            guardrail: "Guardrail",
          },
        ],
      }),
    ]
  ) {
    const fetcher: typeof fetch = () =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text }] } }],
          }),
          { status: 200 },
        ),
      );
    assertEquals(
      await requestMentorPlan([metric], 90, "secret-key", fetcher),
      null,
    );
  }
});

Deno.test("quota migration includes safe re-application guards", async () => {
  const migration = await Deno.readTextFile(
    new URL(
      "../../migrations/20260827040000_resource_optimizer_ai_quota.sql",
      import.meta.url,
    ),
  );
  assertEquals(
    migration.includes(
      "create table if not exists public.resource_optimizer_ai_quota",
    ),
    true,
  );
  assertEquals(
    migration.includes(
      'drop policy if exists "users_read_own_resource_optimizer_ai_quota"',
    ),
    true,
  );
  assertEquals(
    migration.includes(
      "drop trigger if exists validate_resource_optimizer_ai_quota_write",
    ),
    true,
  );
  assertEquals(
    migration.includes(
      "alter column request_count type integer using request_count::text::integer",
    ),
    true,
  );
  assertEquals(
    migration.match(/create or replace function/g)?.length,
    2,
  );
});

const withTestEnvironment = async (run: () => Promise<void>) => {
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousKey = Deno.env.get("SUPABASE_ANON_KEY");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "test-anon-key");
  try {
    await run();
  } finally {
    if (previousUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", previousUrl);
    if (previousKey === undefined) Deno.env.delete("SUPABASE_ANON_KEY");
    else Deno.env.set("SUPABASE_ANON_KEY", previousKey);
  }
};

Deno.test("default request never consumes quota or calls Gemini", async () => {
  await withTestEnvironment(async () => {
    const rpcCalls: string[] = [];
    let mentorCalls = 0;
    const handler = createResourceOptimizerHandler({
      createSupabaseClient: () => ({
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-a" } }, error: null }),
        },
        rpc: (name) => {
          rpcCalls.push(name);
          return Promise.resolve({ data: [metric], error: null });
        },
      }),
      hasGeminiApiKey: () => true,
      requestMentorPlan: () => {
        mentorCalls += 1;
        return Promise.resolve(null);
      },
    });

    const response = await handler(jsonRequest({ days: 90 }));
    const payload = await response.json();
    assertEquals(response.status, 200);
    assertEquals(payload.generated_by, "deterministic");
    assertEquals(payload.ai_status, "not_requested");
    assertEquals(rpcCalls, ["analyze_habit_resource_efficiency"]);
    assertEquals(mentorCalls, 0);
  });
});

Deno.test("quota rejection falls back without calling Gemini", async () => {
  await withTestEnvironment(async () => {
    let mentorCalls = 0;
    const handler = createResourceOptimizerHandler({
      createSupabaseClient: () => ({
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-a" } }, error: null }),
        },
        rpc: (name) =>
          Promise.resolve({
            data: name === "analyze_habit_resource_efficiency"
              ? [metric]
              : [{ allowed: false, reason: "cooldown" }],
            error: null,
          }),
      }),
      hasGeminiApiKey: () => true,
      requestMentorPlan: () => {
        mentorCalls += 1;
        return Promise.resolve(null);
      },
    });

    const response = await handler(jsonRequest({
      days: 90,
      use_ai: true,
      ai_data_consent: true,
    }));
    const payload = await response.json();
    assertEquals(payload.generated_by, "deterministic");
    assertEquals(payload.ai_status, "cooldown");
    assertEquals(mentorCalls, 0);
  });
});

Deno.test("invalid Gemini plan is displayed as deterministic upstream fallback", async () => {
  await withTestEnvironment(async () => {
    const handler = createResourceOptimizerHandler({
      createSupabaseClient: () => ({
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-a" } }, error: null }),
        },
        rpc: (name) =>
          Promise.resolve({
            data: name === "analyze_habit_resource_efficiency"
              ? [metric]
              : [{ allowed: true, reason: "allowed" }],
            error: null,
          }),
      }),
      hasGeminiApiKey: () => true,
      requestMentorPlan: () => Promise.resolve(null),
    });

    const response = await handler(jsonRequest({
      days: 90,
      use_ai: true,
      ai_data_consent: true,
    }));
    const payload = await response.json();
    assertEquals(payload.generated_by, "deterministic");
    assertEquals(payload.ai_status, "upstream_unavailable");
  });
});

Deno.test("insufficient data skips quota and Gemini", async () => {
  await withTestEnvironment(async () => {
    const rpcCalls: string[] = [];
    let mentorCalls = 0;
    const handler = createResourceOptimizerHandler({
      createSupabaseClient: () => ({
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-a" } }, error: null }),
        },
        rpc: (name) => {
          rpcCalls.push(name);
          return Promise.resolve({
            data: [{
              ...metric,
              sample_count: 2,
              has_sufficient_data: false,
              insufficient_data_reason: "sample_count_below_7",
            }],
            error: null,
          });
        },
      }),
      hasGeminiApiKey: () => true,
      requestMentorPlan: () => {
        mentorCalls += 1;
        return Promise.resolve(null);
      },
    });

    const response = await handler(jsonRequest({
      days: 90,
      use_ai: true,
      ai_data_consent: true,
    }));
    const payload = await response.json();
    assertEquals(payload.generated_by, "deterministic");
    assertEquals(payload.ai_status, "insufficient_data");
    assertEquals(rpcCalls, ["analyze_habit_resource_efficiency"]);
    assertEquals(mentorCalls, 0);
  });
});
