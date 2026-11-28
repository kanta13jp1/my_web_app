import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  calculateCtr,
  EVENT_KIND_LABELS,
  LlmToolEngagementMonitor,
} from "./llm_tool_engagement.ts";

Deno.test(
  "computeCtrMetrics aggregates (actionType, generatedLabel) pairs",
  () => {
    const monitor = new LlmToolEngagementMonitor();
    for (let i = 0; i < 4; i++) {
      monitor.recordEvent({
        actionType: "invite",
        generatedLabel: "Pay $30 Cash",
        eventKind: "impression",
      });
    }
    monitor.recordEvent({
      actionType: "invite",
      generatedLabel: "Pay $30 Cash",
      eventKind: "click",
    });

    const metrics = monitor.computeCtrMetrics();
    assertEquals(metrics.length, 1);
    assertEquals(metrics[0].actionType, "invite");
    assertEquals(metrics[0].generatedLabel, "Pay $30 Cash");
    assertEquals(metrics[0].impressions, 4);
    assertEquals(metrics[0].clicks, 1);
    assertEquals(metrics[0].ctr, 0.25);
    assertEquals(EVENT_KIND_LABELS.click, "Click");
    assertEquals(calculateCtr(0, 3), 0);
  },
);

Deno.test(
  "buildPruningReport flags low-CTR tools with sufficient impressions",
  () => {
    const monitor = new LlmToolEngagementMonitor();

    // Low engagement tool: 25 impressions, 0 clicks -> CTR 0.0
    for (let i = 0; i < 25; i++) {
      monitor.recordEvent({
        actionType: "legacy_upsell",
        generatedLabel: "Claim Mystery Bonus",
        eventKind: "impression",
      });
    }

    // Under-sampled tool: 5 impressions, 0 clicks -> should not be pruned yet
    for (let i = 0; i < 5; i++) {
      monitor.recordEvent({
        actionType: "new_helper",
        generatedLabel: "Try Quick Audit",
        eventKind: "impression",
      });
    }

    const report = monitor.buildPruningReport(20, 0.02);
    assertEquals(report.totalPairs, 2);
    assertEquals(report.prunedActionTypes, ["legacy_upsell"]);
    assertEquals(report.candidates.length, 1);
    assertEquals(report.candidates[0].generatedLabel, "Claim Mystery Bonus");
  },
);
