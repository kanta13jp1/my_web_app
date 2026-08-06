import {
  MIN_TASK_BUDGET_TOKENS,
  normalizeTaskBudgetDocuments,
  normalizeTaskBudgetTokens,
  runTaskBudgetAssistant,
} from "./task_budget_assistant.ts";

Deno.test("normalizeTaskBudgetTokens enforces the 20k minimum", () => {
  if (normalizeTaskBudgetTokens(5000) !== MIN_TASK_BUDGET_TOKENS) {
    throw new Error("budget minimum was not enforced");
  }
  if (normalizeTaskBudgetTokens(32000) !== 32000) {
    throw new Error("valid budget should be preserved");
  }
});

Deno.test("normalizeTaskBudgetDocuments accepts title/content inputs", () => {
  const docs = normalizeTaskBudgetDocuments([
    { title: "Spec", content: "Extract requirements." },
    { name: "Notes", text: "Summarize meeting notes." },
    { title: "Empty", content: " " },
  ]);
  if (docs.length !== 2) throw new Error(`expected 2 docs, got ${docs.length}`);
  if (docs[1].title !== "Notes") throw new Error("name fallback failed");
});

Deno.test("runTaskBudgetAssistant completes small multi-document jobs", () => {
  const run = runTaskBudgetAssistant({
    objective: "Extract action items and organize the files.",
    budget_tokens: 20_000,
    effort: "medium",
    documents: [
      { title: "Invoice memo", content: "Invoice paid. Receipt saved." },
      {
        title: "Meeting notes",
        content: "Discussed launch tasks. Owner assigned.",
      },
    ],
  });
  if (run.status !== "completed") throw new Error(`unexpected ${run.status}`);
  if (run.progress_percent !== 100) throw new Error("progress should complete");
  if (run.steps.length < 3) {
    throw new Error("expected extraction and aggregate steps");
  }
});

Deno.test("runTaskBudgetAssistant saves partial results near budget limit", () => {
  const large = "Long research note ".repeat(5000);
  const run = runTaskBudgetAssistant({
    objective: "Aggregate everything without exceeding budget.",
    budget_tokens: 20_000,
    effort: "xhigh",
    documents: [
      { title: "Research A", content: large },
      { title: "Research B", content: large },
      { title: "Research C", content: large },
    ],
  });
  if (run.status !== "budget_safed") {
    throw new Error(`expected budget_safed, got ${run.status}`);
  }
  if (run.consumed_tokens > 20_000) {
    throw new Error("consumed tokens exceeded budget");
  }
  if (!run.steps.some((step) => step.status === "budget_safed")) {
    throw new Error("missing safe stop step");
  }
});
