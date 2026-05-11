import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildGaReadinessSnapshot,
  GA_READINESS_AXES,
  handleGaReadinessAction,
} from "./ga_readiness.ts";

Deno.test("GA readiness exposes the five launch axes", () => {
  const snapshot = buildGaReadinessSnapshot(new Date("2026-05-11T00:00:00Z"));

  assertEquals(snapshot.axes.map((axis) => axis.code), [
    "A",
    "B",
    "C",
    "D",
    "E",
  ]);
  assertEquals(snapshot.summary.axis_count, 5);
  assertEquals(snapshot.summary.overall_progress, 24);
  assertEquals(snapshot.ga_eligible, false);
});

Deno.test("GA readiness keeps user-owned blockers explicit", () => {
  const userOwnedBlockedAxes = GA_READINESS_AXES.filter((axis) =>
    axis.status === "blocked" && axis.owner === "User"
  );

  assertEquals(userOwnedBlockedAxes.length, 4);
  assertEquals(
    userOwnedBlockedAxes.every((axis) => Boolean(axis.blocker)),
    true,
  );
});

Deno.test("handleGaReadinessAction routes the app-hub action", () => {
  const snapshot = handleGaReadinessAction("agent.list_ga_axes");

  assertEquals(snapshot.axes.length, 5);
  assertThrows(() => handleGaReadinessAction("agent.unknown_ga_action"));
});
