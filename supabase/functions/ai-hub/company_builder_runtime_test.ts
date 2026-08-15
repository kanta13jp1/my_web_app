import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCompanyRuntimePrompt,
  companyRuntimeRoutingTier,
  parseCompanyRuntimeQueueMessages,
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
