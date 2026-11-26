import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  BLOCK_ROLE_LABELS,
  buildPromptCachePrefix,
  DISPATCH_MODE_LABELS,
  PromptCacheFinopsTracker,
  selectDispatchMode,
} from "./prompt_cache_finops.ts";

Deno.test(
  "buildPromptCachePrefix orders static blocks before user_input",
  () => {
    const plan = buildPromptCachePrefix(
      [
        {
          role: "user_input",
          content: "Summarize today's expenses",
          estimatedInputCount: 120,
        },
        {
          role: "db_schema",
          content: "CREATE TABLE expenses (...);",
          estimatedInputCount: 700,
        },
        {
          role: "system_prompt",
          content: "You are a financial assistant.",
          estimatedInputCount: 500,
        },
      ],
      1024,
    );

    assertEquals(plan.cacheEnabled, true);
    assertEquals(plan.staticPrefixCount, 1200);
    assertEquals(plan.dynamicCount, 120);
    assertEquals(plan.blocks[0].role, "system_prompt");
    assertEquals(plan.blocks[1].role, "db_schema");
    assertEquals(plan.blocks[1].cache_control, { type: "ephemeral" });
    assertEquals(plan.blocks[2].role, "user_input");
    assertEquals(plan.blocks[2].cache_control, undefined);
    assertEquals(BLOCK_ROLE_LABELS.db_schema, "DB Schema");
  },
);

Deno.test(
  "buildPromptCachePrefix skips cache_control below threshold",
  () => {
    const plan = buildPromptCachePrefix(
      [
        {
          role: "system_prompt",
          content: "Short prompt",
          estimatedInputCount: 100,
        },
        {
          role: "user_input",
          content: "Hello",
          estimatedInputCount: 10,
        },
      ],
      1024,
    );

    assertEquals(plan.cacheEnabled, false);
    assertEquals(plan.blocks[0].cache_control, undefined);
  },
);

Deno.test(
  "selectDispatchMode and tracker compute batch offload and cache hit rate",
  () => {
    assertEquals(selectDispatchMode("realtime"), "messages_api");
    assertEquals(selectDispatchMode("batch_eligible"), "message_batches_api");
    assertEquals(
      DISPATCH_MODE_LABELS.message_batches_api,
      "Message Batches API (Async)",
    );

    const tracker = new PromptCacheFinopsTracker();
    tracker.recordUsage({
      feature: "daily_digest",
      dispatchMode: "message_batches_api",
      baseInputCount: 200,
      cacheReadCount: 1800,
      cacheCreationCount: 0,
      outputCount: 300,
    });
    tracker.recordUsage({
      feature: "interactive_chat",
      dispatchMode: "messages_api",
      baseInputCount: 500,
      cacheReadCount: 500,
      cacheCreationCount: 1000,
      outputCount: 250,
    });

    const summary = tracker.getSummary();
    assertEquals(summary.totalRequests, 2);
    assertEquals(summary.batchRequests, 1);
    assertEquals(summary.batchOffloadRate, 0.5);
    assertEquals(summary.totalBaseInputCount, 700);
    assertEquals(summary.totalCacheReadCount, 2300);
    assertEquals(summary.totalCacheCreationCount, 1000);
    assertEquals(summary.totalOutputCount, 550);
    assertEquals(summary.cacheHitRate, 0.575);
  },
);
