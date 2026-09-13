import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canonicalizeLocalElectionSnapshot,
  computeLocalElectionDiff,
  evaluateScheduleCollectionQuality,
  hashLocalElectionSnapshot,
  type HubDataRow,
  type HubInsertResult,
  type JsonRecord,
  LOCAL_ELECTION_DATASET,
  type LocalElectionHubStore,
  persistLocalElectionSnapshot,
} from "./snapshot_history.ts";

function baseSnapshot(): JsonRecord {
  return {
    fetchedAt: "2026-07-12T00:00:00.000Z",
    baselineCurrentLocalMembers: 340,
    officialCurrentLocalMembers: 1,
    targetLocalMembers: 700,
    baselineNetIncreaseRequired: 360,
    actualNetIncreaseRequired: 699,
    official2023FirstHalfWins: 10,
    official2023SecondHalfWins: 20,
    official2023TotalWins: 30,
    collectionQuality: {
      complete: true,
      failedPrefectureFetches: [],
      linkedPrefectureCount: 30,
      minimumExpectedMemberCount: 170,
      officialElectionPrefectureLinkCount: 47,
      minimumExpectedOfficialElectionPrefectureLinks: 10,
      scheduleSourceCount: 3,
      scheduleFetchSuccessCount: 3,
      scheduleParsedSourceCount: 2,
      scheduleParsedEntryCount: 50,
      scheduleManualEntryCount: 1,
      scheduleManualFallbackOnly: false,
      failedScheduleSourceUrls: [],
      parserEmptyScheduleSourceUrls: ["https://example.com/empty"],
      failedRequiredScheduleSourceUrls: [],
      parserEmptyRequiredScheduleSourceUrls: [],
      issues: [],
    },
    aiSummary: "request-time prose is not dataset content",
    sources: [
      {
        label: "Official members",
        url: "https://new-kokumin.jp/member",
        category: "official_members",
        note: "official",
      },
      {
        label: "Official elections",
        url: "https://new-kokumin.jp/election",
        category: "official_local_elections",
        note: "official",
      },
      {
        label: "Schedule",
        url: "https://go2senkyo.com/schedule",
        category: "schedule_source",
        note: "schedule",
      },
    ],
    prefectures: [
      {
        prefecture: "東京都",
        sourceUrl: "https://new-kokumin.jp/member/tokyo",
        currentMembers: 1,
        prefecturalAssemblyMembers: 0,
        municipalAssemblyMembers: 1,
        cdpLocalMembers: 2,
        cdpSourceUrl: "https://cdp-japan.jp/members/house/local_authorities",
      },
    ],
    members: [
      {
        prefecture: "東京都",
        sourceUrl: "https://new-kokumin.jp/member/tokyo",
        detailUrl: "https://new-kokumin.jp/member/member-a",
        name: "田中一郎",
        kana: "たなかいちろう",
        constituency: "A市",
        municipality: "A市",
        assemblyLabel: "A市議会",
        assemblyCategory: "municipal",
        electionCountLabel: "1期",
        birthDate: "1980-01-01",
        age: 46,
        gender: "男性",
        profile: "profile v1",
      },
    ],
    upcomingSchedules: [
      {
        electionName: "A市議会議員選挙",
        prefecture: "東京都",
        municipality: "A市",
        electionCategory: "assembly",
        voteDate: "2026-08-01",
        announcementDate: "2026-07-25",
        detailUrl: "https://go2senkyo.com/local/a",
        officialCandidateSourceUrl: "https://new-kokumin.jp/election/a",
        seatCount: 20,
        totalCandidateCount: 25,
        kokuminCandidateCount: 1,
        kokuminCandidateNames: ["佐藤花子"],
        kokuminCandidateStatuses: ["公認"],
        kokuminCandidateVotes: [0],
        kokuminCandidateXHandles: ["satohanako"],
        isPast: false,
      },
    ],
  };
}

function changedSnapshot(): JsonRecord {
  const snapshot = structuredClone(baseSnapshot());
  snapshot.fetchedAt = "2026-07-13T00:00:00.000Z";
  snapshot.officialCurrentLocalMembers = 2;
  snapshot.actualNetIncreaseRequired = 698;
  const prefectures = snapshot.prefectures as JsonRecord[];
  prefectures[0].currentMembers = 2;
  prefectures[0].municipalAssemblyMembers = 2;
  const members = snapshot.members as JsonRecord[];
  members.push({
    ...members[0],
    detailUrl: "https://new-kokumin.jp/member/member-b",
    name: "鈴木二郎",
    kana: "すずきじろう",
  });
  const schedules = snapshot.upcomingSchedules as JsonRecord[];
  const schedule = schedules[0];
  schedule.seatCount = 21;
  schedule.kokuminCandidateCount = 2;
  schedule.kokuminCandidateNames = ["佐藤花子", "高橋三郎"];
  schedule.kokuminCandidateStatuses = ["公認", "推薦"];
  schedule.kokuminCandidateVotes = [0, 0];
  schedule.kokuminCandidateXHandles = ["satohanako", "takahashisaburo"];
  return snapshot;
}

function intelligenceSnapshot(): JsonRecord {
  const snapshot = structuredClone(baseSnapshot());
  (snapshot.prefectures as JsonRecord[])[0].cdpLocalMembers = 0;
  snapshot.electionIntelligence = {
    schemaVersion: 1,
    selectedMode: "local",
    modes: [
      {
        id: "local",
        label: "地方選",
        shortLabel: "地方",
        availability: "active",
        description: "地方選を追跡",
        collectors: ["official_endorsements", "local_members"],
      },
      {
        id: "house_of_representatives",
        label: "衆院選",
        shortLabel: "衆院",
        availability: "registered",
        description: "準備中",
        collectors: [],
      },
      {
        id: "house_of_councillors",
        label: "参院選",
        shortLabel: "参院",
        availability: "registered",
        description: "準備中",
        collectors: [],
      },
    ],
    goals: [{
      id: "local_members_700",
      mode: "local",
      title: "地方議員700人",
      metric: "local_member_count",
      currentValue: 1,
      targetValue: 700,
      unit: "人",
      deadlineLabel: "次期統一地方選終了時",
      sourceUrl: "https://example.com/goal",
      sourcePublishedAt: "2026-07-14",
      verificationStatus: "verified",
    }],
    achievements: [{
      id: "unified_local_election_wins_2023",
      mode: "local",
      title: "2023年統一地方選 当選者",
      metric: "unified_local_election_wins_2023",
      value: 30,
      unit: "人",
      periodLabel: "2023年統一地方選",
      sourceUrls: ["https://example.com/result"],
    }],
    officialEndorsements: {
      sourceUrl: "https://new-kokumin.jp/local-election-list",
      sourceAsOf: "2026-08-05",
      sourceDocumentSha256: "a".repeat(64),
      totalCount: 1,
      incumbentCount: 0,
      newcomerCount: 1,
      formerCount: 0,
      recommendationCount: 0,
      prefectureCount: 1,
      prefectures: [{
        prefecture: "東京",
        totalCount: 1,
        incumbentCount: 0,
        newcomerCount: 1,
        formerCount: 0,
      }],
    },
  };
  return snapshot;
}

function changedIntelligenceSnapshot(): JsonRecord {
  const snapshot = structuredClone(intelligenceSnapshot());
  const intelligence = snapshot.electionIntelligence as JsonRecord;
  const goals = intelligence.goals as JsonRecord[];
  goals[0].targetValue = 750;
  const achievements = intelligence.achievements as JsonRecord[];
  achievements[0].value = 31;
  const endorsements = intelligence.officialEndorsements as JsonRecord;
  endorsements.sourceAsOf = "2026-08-06";
  endorsements.sourceDocumentSha256 = "b".repeat(64);
  endorsements.totalCount = 2;
  endorsements.incumbentCount = 1;
  const prefectures = endorsements.prefectures as JsonRecord[];
  prefectures[0].totalCount = 2;
  prefectures[0].incumbentCount = 1;
  return snapshot;
}

class MemoryStore implements LocalElectionHubStore {
  snapshots: HubDataRow[] = [];
  candidates: HubDataRow[] = [];
  #nextId = 1;

  findSnapshotTransition(
    dataset: string,
    previousSnapshotId: string | null,
    snapshotHash: string,
  ): Promise<HubDataRow | null> {
    return Promise.resolve(
      this.snapshots.find((row) =>
        row.metadata.dataset === dataset &&
        (row.metadata.previous_snapshot_id ?? null) === previousSnapshotId &&
        row.metadata.snapshot_hash === snapshotHash
      ) ?? null,
    );
  }

  findSnapshotById(snapshotId: string): Promise<HubDataRow | null> {
    return Promise.resolve(
      this.snapshots.find((row) => row.id === snapshotId) ?? null,
    );
  }

  getLatestSnapshot(dataset: string): Promise<HubDataRow | null> {
    return Promise.resolve(
      [...this.snapshots].reverse().find((row) =>
        row.metadata.dataset === dataset
      ) ?? null,
    );
  }

  async insertSnapshot(metadata: JsonRecord): Promise<HubInsertResult> {
    const previousSnapshotId = typeof metadata.previous_snapshot_id ===
          "string" && metadata.previous_snapshot_id
      ? metadata.previous_snapshot_id
      : null;
    const existing = await this.findSnapshotTransition(
      String(metadata.dataset),
      previousSnapshotId,
      String(metadata.snapshot_hash),
    );
    if (existing) return { row: existing, created: false };
    const row = this.#row(metadata);
    this.snapshots.push(row);
    return { row, created: true };
  }

  insertPostCandidate(metadata: JsonRecord): Promise<HubInsertResult> {
    const existing = this.candidates.find((row) =>
      row.metadata.candidate_key === metadata.candidate_key
    );
    if (existing) return Promise.resolve({ row: existing, created: false });
    const row = this.#row(metadata);
    this.candidates.push(row);
    return Promise.resolve({ row, created: true });
  }

  #row(metadata: JsonRecord): HubDataRow {
    const id = `row-${this.#nextId++}`;
    return {
      id,
      metadata: structuredClone(metadata),
      created_at: `2026-07-12T00:00:${String(this.#nextId).padStart(2, "0")}Z`,
    };
  }
}

Deno.test("schedule quality requires one healthy primary and tolerates optional helpers", () => {
  const allFailed = evaluateScheduleCollectionQuality([
    {
      url: "https://example.com/a",
      requiredForPersistence: true,
      fetchSucceeded: false,
      parsedEntryCount: 0,
    },
    {
      url: "https://example.com/b",
      requiredForPersistence: true,
      fetchSucceeded: false,
      parsedEntryCount: 0,
    },
  ], 4);
  assertEquals(allFailed.fetchSuccessCount, 0);
  assertEquals(allFailed.manualFallbackOnly, true);
  assertEquals(allFailed.failedSourceUrls, [
    "https://example.com/a",
    "https://example.com/b",
  ]);
  assertEquals(allFailed.issues, [
    "schedule_sources_all_failed",
    "required_schedule_source_fetch_failed:https://example.com/a,https://example.com/b",
  ]);

  const parserEmpty = evaluateScheduleCollectionQuality([
    {
      url: "https://example.com/a",
      requiredForPersistence: true,
      fetchSucceeded: true,
      parsedEntryCount: 0,
    },
  ], 4);
  assertEquals(parserEmpty.fetchSuccessCount, 1);
  assertEquals(parserEmpty.parsedSourceCount, 0);
  assertEquals(parserEmpty.manualFallbackOnly, true);
  assertEquals(parserEmpty.parserEmptySourceUrls, ["https://example.com/a"]);
  assertEquals(parserEmpty.issues, [
    "schedule_sources_parser_empty",
    "required_schedule_source_parser_empty:https://example.com/a",
  ]);

  const loneRequiredFailureWithOptionalSuccess =
    evaluateScheduleCollectionQuality([
      {
        url: "https://example.com/required-base",
        requiredForPersistence: true,
        fetchSucceeded: false,
        parsedEntryCount: 0,
      },
      {
        url: "https://example.com/optional-year",
        requiredForPersistence: false,
        fetchSucceeded: true,
        parsedEntryCount: 8,
      },
    ], 4);
  assertEquals(loneRequiredFailureWithOptionalSuccess.parsedSourceCount, 1);
  assertEquals(loneRequiredFailureWithOptionalSuccess.issues, [
    "required_schedule_source_fetch_failed:https://example.com/required-base",
  ]);

  const redundantRequiredFailureWithHealthyPeer =
    evaluateScheduleCollectionQuality([
      {
        url: "https://example.com/required-base",
        requiredForPersistence: true,
        fetchSucceeded: false,
        parsedEntryCount: 0,
      },
      {
        url: "https://example.com/required-official",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 12,
      },
      {
        url: "https://example.com/optional-year",
        requiredForPersistence: false,
        fetchSucceeded: true,
        parsedEntryCount: 8,
      },
    ], 4);
  assertEquals(redundantRequiredFailureWithHealthyPeer.parsedSourceCount, 2);
  assertEquals(redundantRequiredFailureWithHealthyPeer.issues, []);
  assertEquals(
    redundantRequiredFailureWithHealthyPeer.failedRequiredSourceUrls,
    [
      "https://example.com/required-base",
    ],
  );

  const requiredParserEmptyWithOptionalSuccess =
    evaluateScheduleCollectionQuality([
      {
        url: "https://example.com/required-base",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 0,
      },
      {
        url: "https://example.com/required-official",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 12,
      },
      {
        url: "https://example.com/optional-year",
        requiredForPersistence: false,
        fetchSucceeded: true,
        parsedEntryCount: 8,
      },
    ], 4);
  assertEquals(requiredParserEmptyWithOptionalSuccess.parsedSourceCount, 2);
  assertEquals(requiredParserEmptyWithOptionalSuccess.issues, []);
  assertEquals(
    requiredParserEmptyWithOptionalSuccess.parserEmptyRequiredSourceUrls,
    ["https://example.com/required-base"],
  );

  const optionalFailureWithRequiredSourcesHealthy =
    evaluateScheduleCollectionQuality([
      {
        url: "https://example.com/required-base",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 20,
      },
      {
        url: "https://example.com/required-official",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 12,
      },
      {
        url: "https://example.com/optional-year",
        requiredForPersistence: false,
        fetchSucceeded: false,
        parsedEntryCount: 0,
      },
    ], 4);
  assertEquals(optionalFailureWithRequiredSourcesHealthy.parsedSourceCount, 2);
  assertEquals(optionalFailureWithRequiredSourcesHealthy.parsedEntryCount, 32);
  assertEquals(
    optionalFailureWithRequiredSourcesHealthy.manualFallbackOnly,
    false,
  );
  assertEquals(optionalFailureWithRequiredSourcesHealthy.issues, []);

  const optionalParserEmptyWithRequiredSourcesHealthy =
    evaluateScheduleCollectionQuality([
      {
        url: "https://example.com/required-base",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 20,
      },
      {
        url: "https://example.com/required-official",
        requiredForPersistence: true,
        fetchSucceeded: true,
        parsedEntryCount: 12,
      },
      {
        url: "https://example.com/optional-year",
        requiredForPersistence: false,
        fetchSucceeded: true,
        parsedEntryCount: 0,
      },
    ], 4);
  assertEquals(optionalParserEmptyWithRequiredSourcesHealthy.issues, []);
});

Deno.test("canonical hash ignores fetch/AI prose and unordered entity rows", async () => {
  const first = baseSnapshot();
  const second = structuredClone(first);
  second.fetchedAt = "2026-07-13T00:00:00.000Z";
  second.aiSummary = "different prose";
  second.sources = [...second.sources as JsonRecord[]].reverse();

  const firstHash = await hashLocalElectionSnapshot(
    canonicalizeLocalElectionSnapshot(first),
  );
  const secondHash = await hashLocalElectionSnapshot(
    canonicalizeLocalElectionSnapshot(second),
  );

  assertEquals(firstHash.length, 64);
  assertEquals(firstHash, secondHash);
});

Deno.test("diff separates member, candidate, and schedule changes", () => {
  const diff = computeLocalElectionDiff(
    canonicalizeLocalElectionSnapshot(baseSnapshot()),
    canonicalizeLocalElectionSnapshot(changedSnapshot()),
  );

  assertEquals(diff.significantKinds, [
    "member_delta",
    "candidate_delta",
    "schedule_delta",
  ]);
  assertEquals(diff.members.added.map((member) => member.name), ["鈴木二郎"]);
  assertEquals(diff.candidates.added.map((candidate) => candidate.name), [
    "高橋三郎",
  ]);
  assertEquals(diff.schedules.changed[0].changedFields, ["seatCount"]);
});

Deno.test("diff tracks official goals, achievements, and endorsements", () => {
  const diff = computeLocalElectionDiff(
    canonicalizeLocalElectionSnapshot(intelligenceSnapshot()),
    canonicalizeLocalElectionSnapshot(changedIntelligenceSnapshot()),
  );

  assertEquals(diff.significantKinds, [
    "goal_delta",
    "achievement_delta",
    "endorsement_delta",
  ]);
  assertEquals(diff.electionIntelligence.goals.changed[0].changedFields, [
    "targetValue",
  ]);
  assertEquals(
    diff.electionIntelligence.achievements.changed[0].changedFields,
    ["value"],
  );
  assertEquals(
    diff.electionIntelligence.officialEndorsements.after.totalCount,
    2,
  );
});

Deno.test("intelligence transition queues one candidate per diff kind", async () => {
  const store = new MemoryStore();
  await persistLocalElectionSnapshot(store, intelligenceSnapshot());
  const result = await persistLocalElectionSnapshot(
    store,
    changedIntelligenceSnapshot(),
  );

  assertEquals(result.candidateCount, 3);
  assertEquals(result.candidatesCreated, 3);
  assertEquals(
    store.candidates.map((row) => row.metadata.diff_kind).sort(),
    ["achievement_delta", "endorsement_delta", "goal_delta"],
  );
});

Deno.test("first persistence creates baseline history without a post candidate", async () => {
  const store = new MemoryStore();
  const result = await persistLocalElectionSnapshot(
    store,
    baseSnapshot(),
    "2026-07-12T01:00:00.000Z",
  );

  assert(result.baselineCreated);
  assert(result.snapshotCreated);
  assertEquals(result.previousSnapshotId, null);
  assertEquals(result.previousSnapshotHash, null);
  assertEquals(result.candidateCount, 0);
  assertEquals(store.snapshots.length, 1);
  assertEquals(store.candidates.length, 0);
  assertEquals(store.snapshots[0].metadata.dataset, LOCAL_ELECTION_DATASET);
  assertEquals(store.snapshots[0].metadata.is_baseline, true);
  assertEquals(store.snapshots[0].metadata.previous_snapshot_id, null);
});

Deno.test("significant transition queues shared-contract approval candidates", async () => {
  const store = new MemoryStore();
  await persistLocalElectionSnapshot(store, baseSnapshot());
  const result = await persistLocalElectionSnapshot(
    store,
    changedSnapshot(),
    "2026-07-13T01:00:00.000Z",
  );

  assertEquals(result.candidateCount, 3);
  assertEquals(result.candidatesCreated, 3);
  assertEquals(store.snapshots.length, 2);
  assertEquals(store.candidates.length, 3);
  for (const row of store.candidates) {
    const metadata = row.metadata;
    const postPayload = metadata.post_payload as JsonRecord;
    assertEquals(metadata.status, "pending_approval");
    assertEquals(metadata.schema_version, 1);
    assertEquals(metadata.approval_required, true);
    assertEquals(metadata.content_archetype, "data_report");
    assertEquals(metadata.candidate_type, "local_election_delta");
    assertEquals(metadata.source_kind, "local_election_snapshot_diff");
    assertEquals(metadata.created_by, "local-election-intelligence");
    assertEquals(metadata.dataset, LOCAL_ELECTION_DATASET);
    assertEquals(metadata.snapshot_observation_id, result.snapshotRow.id);
    assertEquals(metadata.previous_snapshot_id, result.previousSnapshotId);
    assert(typeof metadata.previous_snapshot_hash === "string");
    assert(typeof metadata.dataset_snapshot_hash === "string");
    assert(typeof metadata.diff_kind === "string");
    assert(typeof metadata.candidate_key === "string");
    assert(Array.isArray(metadata.source_urls));
    assertEquals(postPayload.action, "x.post");
    assertEquals(postPayload.text, metadata.text);
    assertEquals(postPayload.replyTexts, []);
    assert(Array.from(String(metadata.text)).length <= 280);
  }
});

Deno.test("same snapshot is idempotent and repairs candidates after a crash", async () => {
  const store = new MemoryStore();
  await persistLocalElectionSnapshot(store, baseSnapshot());
  await persistLocalElectionSnapshot(store, changedSnapshot());

  const repeated = await persistLocalElectionSnapshot(store, changedSnapshot());
  assert(repeated.deduplicated);
  assertEquals(repeated.candidatesCreated, 0);
  assertEquals(store.snapshots.length, 2);
  assertEquals(store.candidates.length, 3);

  store.candidates = [];
  const repaired = await persistLocalElectionSnapshot(store, changedSnapshot());
  assert(repaired.deduplicated);
  assertEquals(repaired.candidatesCreated, 3);
  assertEquals(store.snapshots.length, 2);
  assertEquals(store.candidates.length, 3);
});

Deno.test("A to B to A records a new observation and later transitions stay distinct", async () => {
  const store = new MemoryStore();
  const firstA = await persistLocalElectionSnapshot(store, baseSnapshot());
  const firstB = await persistLocalElectionSnapshot(store, changedSnapshot());
  const secondA = await persistLocalElectionSnapshot(store, baseSnapshot());

  assert(secondA.snapshotCreated);
  assertEquals(secondA.snapshotHash, firstA.snapshotHash);
  assert(secondA.snapshotRow.id !== firstA.snapshotRow.id);
  assertEquals(secondA.previousSnapshotId, firstB.snapshotRow.id);
  assertEquals(secondA.previousSnapshotHash, firstB.snapshotHash);
  assertEquals(store.snapshots.length, 3);
  assertEquals(store.candidates.length, 6);

  const firstBKeys = new Set(
    store.candidates
      .filter((row) =>
        row.metadata.snapshot_observation_id === firstB.snapshotRow.id
      )
      .map((row) => String(row.metadata.candidate_key)),
  );
  const secondAKeys = store.candidates
    .filter((row) =>
      row.metadata.snapshot_observation_id === secondA.snapshotRow.id
    )
    .map((row) => String(row.metadata.candidate_key));
  assert(secondAKeys.every((key) => !firstBKeys.has(key)));

  const secondB = await persistLocalElectionSnapshot(store, changedSnapshot());
  assert(secondB.snapshotCreated);
  assertEquals(secondB.snapshotHash, firstB.snapshotHash);
  assert(secondB.snapshotRow.id !== firstB.snapshotRow.id);
  assertEquals(secondB.previousSnapshotId, secondA.snapshotRow.id);
  assertEquals(store.snapshots.length, 4);
  assertEquals(store.candidates.length, 9);

  const beforeRetryKeys = new Set(
    store.candidates.map((row) => String(row.metadata.candidate_key)),
  );
  const retry = await persistLocalElectionSnapshot(store, changedSnapshot());
  assert(retry.deduplicated);
  assertEquals(retry.snapshotRow.id, secondB.snapshotRow.id);
  assertEquals(retry.candidatesCreated, 0);
  assertEquals(store.snapshots.length, 4);
  assertEquals(store.candidates.length, 9);
  assertEquals(
    new Set(store.candidates.map((row) => String(row.metadata.candidate_key))),
    beforeRetryKeys,
  );

  store.candidates = store.candidates.filter((row) =>
    row.metadata.snapshot_observation_id !== secondB.snapshotRow.id
  );
  const repaired = await persistLocalElectionSnapshot(
    store,
    changedSnapshot(),
  );
  assert(repaired.deduplicated);
  assertEquals(repaired.snapshotRow.id, secondB.snapshotRow.id);
  assertEquals(repaired.candidatesCreated, 3);
  assertEquals(store.snapshots.length, 4);
  assertEquals(store.candidates.length, 9);
});

Deno.test("profile-only content version is recorded without queueing", async () => {
  const store = new MemoryStore();
  await persistLocalElectionSnapshot(store, baseSnapshot());
  const profileUpdate = structuredClone(baseSnapshot());
  (profileUpdate.members as JsonRecord[])[0].profile = "profile v2";

  const result = await persistLocalElectionSnapshot(store, profileUpdate);

  assert(result.snapshotCreated);
  assertEquals(result.significantKinds, []);
  assertEquals(result.candidateCount, 0);
  assertEquals(store.snapshots.length, 2);
  assertEquals(store.candidates.length, 0);
});

Deno.test("incomplete collection is rejected before history or queue writes", async () => {
  const store = new MemoryStore();
  const incomplete = baseSnapshot();
  incomplete.collectionQuality = {
    ...(incomplete.collectionQuality as JsonRecord),
    complete: false,
    failedPrefectureFetches: ["東京都"],
    linkedPrefectureCount: 30,
    minimumExpectedMemberCount: 170,
    issues: ["prefecture_fetch_failed:東京都"],
  };

  await assertRejects(
    () => persistLocalElectionSnapshot(store, incomplete),
    Error,
    "incomplete local-election snapshot",
  );
  assertEquals(store.snapshots.length, 0);
  assertEquals(store.candidates.length, 0);
});
