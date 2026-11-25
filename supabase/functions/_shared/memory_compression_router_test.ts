import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  BASELINE_COMPRESSION_PROFILE_ID,
  buildCompressionProviderRequest,
  computeCompressionCostSavings,
  DEFAULT_COMPRESSION_PROFILE_ID,
  DEFAULT_COMPRESSION_PROFILES,
  evaluateSummaryRestorationQuality,
  resolveCompressionModelConfig,
} from "./memory_compression_router.ts";

Deno.test(
  "default compression route uses low-cost Gemini Flash tier",
  () => {
    const decision = resolveCompressionModelConfig();
    assertEquals(decision.profileId, DEFAULT_COMPRESSION_PROFILE_ID);
    assertEquals(decision.provider, "google");
    assertEquals(decision.model, "gemini-2.5-flash");
    assertEquals(decision.baselineModel, "claude-sonnet-4-6");
    assertEquals(decision.source, "default_config");
  },
);

Deno.test(
  "env overrides switch compression provider and model dynamically",
  () => {
    const decision = resolveCompressionModelConfig({
      env: {
        AGENT_MEMORY_COMPRESSION_PROVIDER: "groq",
      },
    });
    assertEquals(decision.provider, "groq");
    assertEquals(decision.model, "llama-3.3-70b-versatile");
    assertEquals(decision.source, "env_override");

    const custom = resolveCompressionModelConfig({
      env: {
        AGENT_MEMORY_COMPRESSION_PROVIDER: "google",
        AGENT_MEMORY_COMPRESSION_MODEL: "gemini-2.5-flash-lite",
      },
    });
    assertEquals(custom.profileId, "gemini_flash_lite");
    assertEquals(custom.model, "gemini-2.5-flash-lite");
  },
);

Deno.test(
  "cost telemetry measures >90% reduction vs Sonnet baseline",
  () => {
    const metrics = computeCompressionCostSavings({
      inputTokens: 100_000,
      outputTokens: 10_000,
      activeProfile:
        DEFAULT_COMPRESSION_PROFILES[DEFAULT_COMPRESSION_PROFILE_ID],
      baselineProfile:
        DEFAULT_COMPRESSION_PROFILES[BASELINE_COMPRESSION_PROFILE_ID],
    });
    assertEquals(metrics.activeCostUsd, 0.021);
    assertEquals(metrics.baselineCostUsd, 0.45);
    assertEquals(metrics.savingsUsd, 0.429);
    assertEquals(metrics.savingsPct, 95.33);
  },
);

Deno.test(
  "restoration quality gate catches missing sections or anchors",
  () => {
    const raw = "Log for #2708 and #6337. Must keep safety guards." +
      " ".repeat(140);
    const goodSummary = [
      "## Decisions",
      "- Switched #2708 compression engine to Gemini.",
      "## Open Tasks",
      "- Verify #6337 telemetry.",
      "## Key Identifiers",
      "- #2708, #6337",
      "## Constraints",
      "- Keep safety guards.",
    ].join("\n");
    const passRes = evaluateSummaryRestorationQuality(raw, goodSummary);
    assertEquals(passRes.passed, true);
    assertEquals(passRes.contextRecallScore, 1);

    const badRes = evaluateSummaryRestorationQuality(raw, "short summary");
    assertEquals(badRes.passed, false);
    assertEquals(badRes.missingAnchors, ["#2708", "#6337"]);
  },
);

Deno.test(
  "provider request builder shapes Gemini and Anthropic headers cleanly",
  () => {
    const geminiRoute = resolveCompressionModelConfig();
    const geminiReq = buildCompressionProviderRequest(
      geminiRoute,
      "summarize",
      ["demo", "val"].join("-"),
    );
    assertEquals(geminiReq.headers["x-goog-api-key"], "demo-val");

    const anthropicRoute = resolveCompressionModelConfig({
      profile: "claude_haiku",
    });
    const anthropicReq = buildCompressionProviderRequest(
      anthropicRoute,
      "summarize",
      ["demo", "val"].join("-"),
    );
    assertEquals(anthropicReq.headers["anthropic-version"], "2023-06-01");
  },
);
