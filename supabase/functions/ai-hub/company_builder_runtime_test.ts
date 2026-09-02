import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCompanyRuntimePrompt,
  companyRuntimeRoutingTier,
  nextCompanyRuntimeRoutingProfile,
  parseCompanyRuntimeQueueMessages,
  selectCompanyRuntimeRouting,
} from "./company_builder_runtime.ts";

Deno.test("queue parser rejects malformed or unscoped messages", () => {
  assertEquals(parseCompanyRuntimeQueueMessages(null), []);
  assertEquals(parseCompanyRuntimeQueueMessages([{ msg_id: 1 }]), []);
  assertEquals(
    parseCompanyRuntimeQueueMessages([{
      msg_id: 12,
      read_ct: 2,
      message: { user_id: "user-1", company_id: "company-1" },
    }]),
    [{
      msgId: 12,
      readCount: 2,
      userId: "user-1",
      companyId: "company-1",
    }],
  );
});

Deno.test("runtime prompt binds company, manager, tool, and task context", () => {
  const prompt = buildCompanyRuntimePrompt(
    {
      metadata: {
        company_name: "Signal School",
        idea: "AI school for founders",
        offer: "One useful lesson each day",
        audience: "Japanese founders",
      },
    },
    {
      title: "Shape the MVP",
      description: "Cut the first release to one workflow.",
      metadata: { stage: "product" },
    },
    {
      display_name: "Max",
      role_title: "Product Manager",
      metadata: { focus: "Own scope" },
    },
    {
      display_name: "Atlas",
      role_title: "Architect",
      metadata: { focus: "Own architecture" },
    },
  );

  assertStringIncludes(prompt, "Company: Signal School");
  assertStringIncludes(prompt, "Manager: Max - Product Manager");
  assertStringIncludes(prompt, "Tool agent: Atlas - Architect");
  assertStringIncludes(prompt, "Task: Shape the MVP");
  assertStringIncludes(prompt, "Return a concrete work product");
});

Deno.test("runtime prompt requires bracket citations when research is available", () => {
  const prompt = buildCompanyRuntimePrompt(
    { metadata: { company_name: "Signal School" } },
    { title: "Review pricing", metadata: { stage: "research" } },
    null,
    null,
    "[1] Pricing page\nURL: https://example.com/pricing\nExcerpt: Pro is $20.",
  );
  assertStringIncludes(prompt, "Company research sources:");
  assertStringIncludes(prompt, "Cite concrete claims with bracket references");
});

Deno.test("high-risk business stages start on stronger routing tiers", () => {
  assertEquals(
    companyRuntimeRoutingTier({ metadata: { stage: "legal" } }),
    "performance",
  );
  assertEquals(
    companyRuntimeRoutingTier({ metadata: { stage: "finance" } }),
    "budget",
  );
  assertEquals(
    companyRuntimeRoutingTier({ metadata: { stage: "product" } }),
    "free",
  );
});

Deno.test("adaptive routing escalates retries and failures", () => {
  const task = { attempt_count: 2, metadata: { stage: "finance" } };
  const decision = selectCompanyRuntimeRouting(task, {
    current_tier: "budget",
  });
  assertEquals(decision.tier, "performance");
  assertEquals(decision.retryBoost, 1);
  const profile = nextCompanyRuntimeRoutingProfile(
    null,
    decision,
    false,
    "performance",
  );
  assertEquals(profile.current_tier, "premium");
  assertEquals(profile.last_decision, "escalated_after_failure");
});

Deno.test("adaptive routing downgrades after five consecutive successes", () => {
  const decision = selectCompanyRuntimeRouting(
    { attempt_count: 1, metadata: { stage: "finance" } },
    { current_tier: "performance" },
  );
  const profile = nextCompanyRuntimeRoutingProfile(
    { consecutive_successes: 4, current_tier: "performance" },
    decision,
    true,
    "performance",
  );
  assertEquals(profile.current_tier, "budget");
  assertEquals(profile.consecutive_successes, 0);
  assertEquals(profile.downgrade_count, 1);
  assertEquals(profile.last_decision, "downgraded_after_5_successes");
});

Deno.test("adaptive routing never downgrades legal tasks below performance", () => {
  const decision = selectCompanyRuntimeRouting(
    { attempt_count: 1, metadata: { stage: "legal" } },
    { current_tier: "performance" },
  );
  const profile = nextCompanyRuntimeRoutingProfile(
    { consecutive_successes: 4, current_tier: "performance" },
    decision,
    true,
    "performance",
  );
  assertEquals(profile.current_tier, "performance");
  assertEquals(profile.last_decision, "success_floor_retained");
});
