import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeDeltaDays,
  InMemoryDiscussionRoadmapStore,
} from "./discussion_roadmap.ts";

Deno.test(
  "computeDeltaDays computes positive delays and negative advancements",
  () => {
    assertEquals(computeDeltaDays("2026-12-01", "2026-12-08"), 7);
    assertEquals(computeDeltaDays("2026-12-08", "2026-12-03"), -5);
    assertEquals(computeDeltaDays("2026-12-01", "2026-12-01"), 0);
  },
);

Deno.test(
  "InMemoryDiscussionRoadmapStore records immutable schedule audit history",
  () => {
    const store = new InMemoryDiscussionRoadmapStore();
    store.registerMilestone(
      {
        id: "ms-1",
        topic: "緊急事態条項",
        stage: "general_debate",
        targetDate: "2026-12-10",
        ownerGroup: "起草委員会",
      },
      "2026-11-26T00:00:00Z",
    );

    const delayed = store.updateMilestoneSchedule({
      milestoneId: "ms-1",
      nextStage: "drafting",
      nextTargetDate: "2026-12-17",
      reason: "追加ヒアリングのため7日延長",
      nowIso: "2026-11-27T00:00:00Z",
    });
    assertExists(delayed);
    assertEquals(delayed.auditEntry.deltaDays, 7);
    assertEquals(delayed.milestone.stage, "drafting");

    const advanced = store.updateMilestoneSchedule({
      milestoneId: "ms-1",
      nextStage: "agreed",
      nextTargetDate: "2026-12-12",
      reason: "合意形成の前倒し",
      nowIso: "2026-11-28T00:00:00Z",
    });
    assertExists(advanced);
    assertEquals(advanced.auditEntry.deltaDays, -5);

    const history = store.listAuditHistory("ms-1");
    assertEquals(history.length, 2);
    assertEquals(history[0].previousStage, "general_debate");
    assertEquals(history[1].nextStage, "agreed");
  },
);
