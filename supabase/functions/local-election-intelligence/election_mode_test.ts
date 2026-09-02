import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildElectionIntelligenceSnapshot,
  normalizeElectionModeRegistry,
  normalizeOfficialEndorsementSnapshot,
  verifyElectionGoalSources,
} from "./election_mode.ts";
import endorsementAsset from "../../../assets/data/kokumin_local_endorsements.json" with {
  type: "json",
};

function registryFixture() {
  return {
    schemaVersion: 1,
    defaultMode: "local",
    modes: [
      {
        id: "local",
        label: "地方選",
        shortLabel: "地方",
        availability: "active",
        description: "local",
        collectors: ["local_results", "local_members"],
        goals: [{
          id: "local_members_700",
          title: "地方議員700人",
          metric: "local_member_count",
          targetValue: 700,
          unit: "人",
          deadlineLabel: "次期統一地方選終了時",
          sourceUrl: "https://example.com/goal",
          sourcePublishedAt: "2026-07-14",
          verificationTerms: ["地方自治体議員", "700"],
        }],
        achievements: [{
          id: "unified_local_election_wins_2023",
          title: "2023年統一地方選 当選者",
          metric: "unified_local_election_wins_2023",
          unit: "人",
          periodLabel: "2023年統一地方選",
          sourceUrls: ["https://example.com/result"],
        }],
      },
      {
        id: "house_of_representatives",
        label: "衆院選",
        shortLabel: "衆院",
        availability: "registered",
        description: "registered",
        collectors: [],
        goals: [],
        achievements: [],
      },
      {
        id: "house_of_councillors",
        label: "参院選",
        shortLabel: "参院",
        availability: "registered",
        description: "registered",
        collectors: [],
        goals: [],
        achievements: [],
      },
    ],
  };
}

Deno.test("registry keeps future election modes without inventing goals", () => {
  const registry = normalizeElectionModeRegistry(registryFixture());

  assertEquals(registry.defaultMode, "local");
  assertEquals(registry.modes.map((mode) => mode.id), [
    "local",
    "house_of_representatives",
    "house_of_councillors",
  ]);
  assertEquals(registry.modes[1].availability, "registered");
  assertEquals(registry.modes[1].goals, []);
});

Deno.test("goal source terms are verified before snapshot persistence", async () => {
  const registry = normalizeElectionModeRegistry(registryFixture());
  const verified = await verifyElectionGoalSources(
    registry,
    (_url) =>
      Promise.resolve("次期統一地方選までに地方自治体議員700人を目指す"),
  );
  assertEquals(verified.verifiedGoalIds, ["local_members_700"]);
  assertEquals(verified.issues, []);

  const missing = await verifyElectionGoalSources(
    registry,
    (_url) => Promise.resolve("地方自治体議員を増やす"),
  );
  assertEquals(missing.verifiedGoalIds, []);
  assertEquals(missing.issues, [
    "goal_source_terms_missing:local_members_700:700",
  ]);

  const failed = await verifyElectionGoalSources(
    registry,
    (_url) => Promise.reject(new Error("offline")),
  );
  assertEquals(failed.issues, [
    "goal_source_fetch_failed:local_members_700",
  ]);
});

Deno.test("local snapshot resolves goal progress and official achievements", () => {
  const registry = normalizeElectionModeRegistry(registryFixture());
  const snapshot = buildElectionIntelligenceSnapshot({
    registry,
    selectedMode: "local",
    verifiedGoalIds: ["local_members_700"],
    officialEndorsements: {
      sourceUrl: "https://example.com/list",
      sourceAsOf: "2026-08-05",
      sourceDocumentSha256: "a".repeat(64),
      totalCount: 217,
      incumbentCount: 102,
      newcomerCount: 106,
      formerCount: 9,
      recommendationCount: 9,
      prefectureCount: 0,
      prefectures: [],
    },
    officialCurrentLocalMembers: 360,
    official2023TotalWins: 183,
  });

  assertEquals(snapshot.selectedMode, "local");
  assertEquals(snapshot.goals[0].currentValue, 360);
  assertEquals(snapshot.goals[0].targetValue, 700);
  assertEquals(snapshot.goals[0].verificationStatus, "verified");
  assertEquals(snapshot.achievements[0].value, 183);
  assertEquals(snapshot.officialEndorsements.totalCount, 217);

  assertThrows(
    () =>
      buildElectionIntelligenceSnapshot({
        registry,
        selectedMode: "house_of_representatives",
        verifiedGoalIds: [],
        officialEndorsements: snapshot.officialEndorsements,
        officialCurrentLocalMembers: 360,
        official2023TotalWins: 183,
      }),
    Error,
    "registered but not active",
  );
});

Deno.test("generated endorsement asset passes the shared validator", () => {
  const snapshot = normalizeOfficialEndorsementSnapshot(endorsementAsset);

  // Counts change when the generated asset refreshes; validate the data contract.
  assertEquals(snapshot.totalCount, endorsementAsset.officialEndorsements.totalCount);
  assertEquals(snapshot.incumbentCount, endorsementAsset.officialEndorsements.incumbentCount);
  assertEquals(snapshot.newcomerCount, endorsementAsset.officialEndorsements.newcomerCount);
  assertEquals(snapshot.formerCount, endorsementAsset.officialEndorsements.formerCount);
  assertEquals(snapshot.recommendationCount, endorsementAsset.recommendations.totalCount);
  assertEquals(snapshot.prefectureCount, endorsementAsset.prefectures.length);
  assertEquals(
    snapshot.totalCount,
    snapshot.incumbentCount + snapshot.newcomerCount + snapshot.formerCount,
  );
});
