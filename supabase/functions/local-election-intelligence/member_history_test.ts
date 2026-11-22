import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildHistoryPointFromSnapshot,
  LOCAL_ELECTION_MEMBER_HISTORY_MAX_POINTS,
  type LocalElectionMemberHistoryPoint,
  type LocalElectionMemberHistoryStore,
  type LocalElectionMemberHistoryUpsertRow,
  mergeMemberHistoryPoints,
  recordAndLoadMemberHistory,
  toJstSnapshotDate,
} from "./member_history.ts";

class InMemoryHistoryStore implements LocalElectionMemberHistoryStore {
  readonly rows = new Map<string, LocalElectionMemberHistoryUpsertRow>();
  upsertCalls = 0;

  constructor(initialRows: readonly LocalElectionMemberHistoryUpsertRow[] = []) {
    for (const row of initialRows) {
      this.rows.set(row.snapshot_date, row);
    }
  }

  listHistory(limit: number): Promise<LocalElectionMemberHistoryPoint[]> {
    const sorted = [...this.rows.values()]
      .sort((left, right) =>
        right.snapshot_date.localeCompare(left.snapshot_date)
      )
      .slice(0, limit)
      .map((row) => ({
        fetchedAt: row.fetched_at,
        officialCurrentLocalMembers: row.official_current_local_members,
        actualNetIncreaseRequired: row.actual_net_increase_required,
      }));
    return Promise.resolve(sorted);
  }

  upsertDailyPoint(row: LocalElectionMemberHistoryUpsertRow): Promise<void> {
    this.upsertCalls += 1;
    this.rows.set(row.snapshot_date, row);
    return Promise.resolve();
  }
}

Deno.test("toJstSnapshotDate respects UTC+9 midnight rollover", () => {
  assertEquals(toJstSnapshotDate("2026-11-22T14:59:59.000Z"), "2026-11-22");
  assertEquals(toJstSnapshotDate("2026-11-22T15:30:00.000Z"), "2026-11-23");
  assertEquals(toJstSnapshotDate(""), null);
  assertEquals(toJstSnapshotDate("invalid-date"), null);
});

Deno.test("buildHistoryPointFromSnapshot rejects non-positive member counts", () => {
  assertEquals(
    buildHistoryPointFromSnapshot({
      fetchedAt: "2026-11-23T00:00:00.000Z",
      officialCurrentLocalMembers: 0,
      actualNetIncreaseRequired: 700,
    }),
    null,
  );
  assertEquals(
    buildHistoryPointFromSnapshot({
      fetchedAt: "2026-11-23T00:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: -1,
    }),
    null,
  );
  assertEquals(
    buildHistoryPointFromSnapshot({
      fetchedAt: "2026-11-23T00:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    }),
    {
      fetchedAt: "2026-11-23T00:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
  );
});

Deno.test("mergeMemberHistoryPoints keeps latest per JST day and caps at maxPoints", () => {
  const merged = mergeMemberHistoryPoints([
    {
      fetchedAt: "2026-11-20T01:00:00.000Z",
      officialCurrentLocalMembers: 418,
      actualNetIncreaseRequired: 282,
    },
    {
      fetchedAt: "2026-11-20T12:00:00.000Z",
      officialCurrentLocalMembers: 419,
      actualNetIncreaseRequired: 281,
    },
    {
      fetchedAt: "2026-11-21T01:00:00.000Z",
      officialCurrentLocalMembers: 420,
      actualNetIncreaseRequired: 280,
    },
    {
      fetchedAt: "2026-11-22T01:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
    {
      fetchedAt: "2026-11-22T02:00:00.000Z",
      officialCurrentLocalMembers: 0,
      actualNetIncreaseRequired: 700,
    },
  ], 2);

  assertEquals(merged, [
    {
      fetchedAt: "2026-11-21T01:00:00.000Z",
      officialCurrentLocalMembers: 420,
      actualNetIncreaseRequired: 280,
    },
    {
      fetchedAt: "2026-11-22T01:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
  ]);
});

Deno.test("recordAndLoadMemberHistory skips writes on public snapshot reads and merges persisted history", async () => {
  const store = new InMemoryHistoryStore([
    {
      snapshot_date: "2026-11-21",
      fetched_at: "2026-11-21T03:00:00.000Z",
      official_current_local_members: 419,
      actual_net_increase_required: 281,
      source: "local-election-intelligence",
    },
  ]);

  const history = await recordAndLoadMemberHistory({
    store,
    snapshot: {
      fetchedAt: "2026-11-22T03:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
    persistDailyPoint: false,
  });

  assertEquals(store.upsertCalls, 0);
  assertEquals(history.length, 2);
  assertEquals(history[0].officialCurrentLocalMembers, 419);
  assertEquals(history[1].officialCurrentLocalMembers, 421);
});

Deno.test("recordAndLoadMemberHistory persists daily point during patrol and updates same JST day", async () => {
  const store = new InMemoryHistoryStore();

  const first = await recordAndLoadMemberHistory({
    store,
    snapshot: {
      fetchedAt: "2026-11-22T01:00:00.000Z",
      officialCurrentLocalMembers: 420,
      actualNetIncreaseRequired: 280,
    },
    persistDailyPoint: true,
  });
  assertEquals(first.length, 1);
  assertEquals(store.upsertCalls, 1);

  const second = await recordAndLoadMemberHistory({
    store,
    snapshot: {
      fetchedAt: "2026-11-22T12:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
    persistDailyPoint: true,
  });
  assertEquals(store.upsertCalls, 2);
  assertEquals(second, [
    {
      fetchedAt: "2026-11-22T12:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
  ]);
});

Deno.test("recordAndLoadMemberHistory fails open if store errors", async () => {
  const failingStore: LocalElectionMemberHistoryStore = {
    listHistory(): Promise<LocalElectionMemberHistoryPoint[]> {
      return Promise.reject(new Error("db read timeout"));
    },
    upsertDailyPoint(): Promise<void> {
      return Promise.reject(new Error("db write timeout"));
    },
  };

  const history = await recordAndLoadMemberHistory({
    store: failingStore,
    snapshot: {
      fetchedAt: "2026-11-23T01:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
    persistDailyPoint: true,
  });

  assertEquals(history, [
    {
      fetchedAt: "2026-11-23T01:00:00.000Z",
      officialCurrentLocalMembers: 421,
      actualNetIncreaseRequired: 279,
    },
  ]);
  assertEquals(LOCAL_ELECTION_MEMBER_HISTORY_MAX_POINTS, 180);
});
