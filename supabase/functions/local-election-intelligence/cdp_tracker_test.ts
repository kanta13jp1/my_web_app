import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyPostArchetype } from "../growth-hub/x_post_archetype.ts";
import type {
  HubDataRow,
  JsonRecord,
  LocalElectionHubStore,
} from "./snapshot_history.ts";
import {
  buildCdpMemberSnapshot,
  CDP_DATASET,
  CDP_MEMBER_PAGE_URL,
  type CdpMemberSnapshot,
  CDP_TRACKER_VARIANT,
  normalizeCdpPrefectureName,
  parseCdpSnapshotRecord,
  persistCdpSnapshot,
} from "./cdp_tracker.ts";

// Real benchmark counts captured from assets/data/cdp_local_members.json (47 prefectures, total 922).
const REAL_CDP_BENCHMARK_PAYLOAD = {
  source: CDP_MEMBER_PAGE_URL,
  prefectures: {
    "北海道": 57,
    "青森": 24,
    "岩手": 23,
    "宮城": 25,
    "秋田": 21,
    "山形": 16,
    "福島": 39,
    "茨城": 15,
    "栃木": 14,
    "群馬": 16,
    "埼玉": 46,
    "千葉": 57,
    "東京": 56,
    "神奈川": 59,
    "新潟": 14,
    "富山": 11,
    "石川": 5,
    "福井": 7,
    "山梨": 10,
    "長野": 18,
    "岐阜": 6,
    "静岡": 14,
    "愛知": 36,
    "三重": 8,
    "滋賀": 17,
    "京都": 21,
    "大阪": 19,
    "兵庫": 26,
    "奈良": 7,
    "和歌山": 3,
    "鳥取": 18,
    "島根": 21,
    "岡山": 9,
    "広島": 16,
    "山口": 5,
    "徳島": 7,
    "香川": 23,
    "愛媛": 8,
    "高知": 5,
    "福岡": 37,
    "佐賀": 17,
    "長崎": 7,
    "熊本": 9,
    "大分": 17,
    "宮崎": 16,
    "鹿児島": 8,
    "沖縄": 9,
  },
};

function createMemoryStore(): {
  store: LocalElectionHubStore;
  snapshots: HubDataRow[];
  candidates: HubDataRow[];
} {
  const snapshots: HubDataRow[] = [];
  const candidates: HubDataRow[] = [];
  let seq = 0;

  const store: LocalElectionHubStore = {
    getLatestSnapshot(dataset: string): Promise<HubDataRow | null> {
      const filtered = snapshots.filter((row) =>
        row.metadata.dataset === dataset
      );
      return Promise.resolve(
        filtered.length > 0 ? filtered[filtered.length - 1] : null,
      );
    },
    findSnapshotById(id: string): Promise<HubDataRow | null> {
      return Promise.resolve(snapshots.find((row) => row.id === id) ?? null);
    },
    listRecentSnapshots(): Promise<HubDataRow[]> {
      return Promise.resolve([...snapshots]);
    },
    insertSnapshot(metadata: JsonRecord) {
      const existing = snapshots.find((row) =>
        row.metadata.dataset === metadata.dataset &&
        row.metadata.snapshot_hash === metadata.snapshot_hash
      );
      if (existing) {
        return Promise.resolve({ row: existing, created: false });
      }
      seq += 1;
      const row: HubDataRow = {
        id: `snap-${seq}`,
        source: "local_election_dataset_snapshot",
        metadata: structuredClone(metadata),
        created_at: String(metadata.observed_at ?? "2026-11-28T10:00:00.000Z"),
      };
      snapshots.push(row);
      return Promise.resolve({ row, created: true });
    },
    insertPostCandidate(metadata: JsonRecord) {
      const existing = candidates.find((row) =>
        row.metadata.candidate_key === metadata.candidate_key
      );
      if (existing) {
        return Promise.resolve({ row: existing, created: false });
      }
      seq += 1;
      const row: HubDataRow = {
        id: `cand-${seq}`,
        source: "x_post_candidate",
        metadata: structuredClone(metadata),
        created_at: String(
          metadata.generated_at ?? "2026-11-28T10:00:00.000Z",
        ),
      };
      candidates.push(row);
      return Promise.resolve({ row, created: true });
    },
  };

  return { store, snapshots, candidates };
}

Deno.test(
  "buildCdpMemberSnapshot normalizes 47 short and full prefecture keys and sorts tallies",
  () => {
    const mixedPayload = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: {
        ...REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
        // Overwrite short key with canonical full form for Tokyo and Osaka.
      } as Record<string, number>,
    };
    delete mixedPayload.prefectures["東京"];
    delete mixedPayload.prefectures["大阪"];
    mixedPayload.prefectures["東京都"] = 56;
    mixedPayload.prefectures["大阪府"] = 19;

    assertEquals(normalizeCdpPrefectureName("東京"), "東京都");
    assertEquals(normalizeCdpPrefectureName("東京都"), "東京都");
    assertEquals(normalizeCdpPrefectureName("未知県"), null);

    const snapshot = buildCdpMemberSnapshot(mixedPayload);
    assertEquals(snapshot !== null, true);
    const s = snapshot as CdpMemberSnapshot;
    assertEquals(s.totalLocalMembers, 922);
    assertEquals(s.reportedPrefectureCount, 47);
    assertEquals(s.activePrefectureCount, 47);
    assertEquals(s.missingPrefectures.length, 0);
    assertEquals(s.prefectures[0], { prefecture: "神奈川県", count: 59 });
    assertEquals(s.prefectures[1], { prefecture: "北海道", count: 57 });
    assertEquals(s.prefectures[2], { prefecture: "千葉県", count: 57 });
    assertEquals(s.prefectures[3], { prefecture: "東京都", count: 56 });
    assertEquals(parseCdpSnapshotRecord(s)?.totalLocalMembers, 922);
  },
);

Deno.test(
  "buildCdpMemberSnapshot fails closed on thin coverage, thin total, invalid counts, or duplicate aliases",
  () => {
    const thinCoverage = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: Object.fromEntries(
        Object.entries(REAL_CDP_BENCHMARK_PAYLOAD.prefectures).slice(0, 39),
      ),
    };
    assertEquals(buildCdpMemberSnapshot(thinCoverage), null);

    const thinTotal = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: Object.fromEntries(
        Object.keys(REAL_CDP_BENCHMARK_PAYLOAD.prefectures).map((k) => [k, 5]),
      ),
    };
    assertEquals(buildCdpMemberSnapshot(thinTotal), null);

    const negativeCount = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: {
        ...REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
        "東京": -1,
      },
    };
    assertEquals(buildCdpMemberSnapshot(negativeCount), null);

    const floatCount = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: {
        ...REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
        "東京": 56.5,
      },
    };
    assertEquals(buildCdpMemberSnapshot(floatCount), null);

    const unknownKey = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: {
        ...REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
        "架空県": 10,
      },
    };
    assertEquals(buildCdpMemberSnapshot(unknownKey), null);

    const duplicateAlias = {
      source: CDP_MEMBER_PAGE_URL,
      prefectures: {
        ...REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
        "東京都": 56,
      },
    };
    assertEquals(buildCdpMemberSnapshot(duplicateAlias), null);
  },
);

Deno.test(
  "persistCdpSnapshot creates silent baseline first and deduplicates identical retries",
  async () => {
    const { store, snapshots, candidates } = createMemoryStore();
    const baseline = buildCdpMemberSnapshot(
      REAL_CDP_BENCHMARK_PAYLOAD,
    ) as CdpMemberSnapshot;

    const first = await persistCdpSnapshot(
      store,
      baseline,
      "2026-11-28T23:45:00.000Z",
    );
    assertEquals(first.dataset, CDP_DATASET);
    assertEquals(first.baselineCreated, true);
    assertEquals(first.snapshotCreated, true);
    assertEquals(first.deduplicated, false);
    assertEquals(first.hasChanges, false);
    assertEquals(first.candidateCount, 0);
    assertEquals(snapshots.length, 1);
    assertEquals(candidates.length, 0);

    const retry = await persistCdpSnapshot(
      store,
      baseline,
      "2026-11-29T23:45:00.000Z",
    );
    assertEquals(retry.baselineCreated, false);
    assertEquals(retry.snapshotCreated, false);
    assertEquals(retry.deduplicated, true);
    assertEquals(retry.hasChanges, false);
    assertEquals(retry.candidateCount, 0);
    assertEquals(snapshots.length, 1);
    assertEquals(candidates.length, 0);
  },
);

Deno.test(
  "persistCdpSnapshot queues HITL data_report candidate on count delta and suppresses sourceUrl-only noise",
  async () => {
    const { store, snapshots, candidates } = createMemoryStore();
    const baseline = buildCdpMemberSnapshot(
      REAL_CDP_BENCHMARK_PAYLOAD,
    ) as CdpMemberSnapshot;

    const sameCountsDifferentUrl = buildCdpMemberSnapshot({
      source: `${CDP_MEMBER_PAGE_URL}?cache=1`,
      prefectures: REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
    }) as CdpMemberSnapshot;

    await persistCdpSnapshot(store, baseline, "2026-11-28T23:45:00.000Z");
    const urlNoiseRetry = await persistCdpSnapshot(
      store,
      sameCountsDifferentUrl,
      "2026-11-29T00:15:00.000Z",
    );
    assertEquals(urlNoiseRetry.deduplicated, true);
    assertEquals(urlNoiseRetry.hasChanges, false);
    assertEquals(urlNoiseRetry.candidateCount, 0);
    assertEquals(snapshots.length, 1);
    assertEquals(candidates.length, 0);

    const updated = buildCdpMemberSnapshot({
      source: CDP_MEMBER_PAGE_URL,
      prefectures: {
        ...REAL_CDP_BENCHMARK_PAYLOAD.prefectures,
        "東京": 58,
      },
    }) as CdpMemberSnapshot;

    const next = await persistCdpSnapshot(
      store,
      updated,
      "2026-11-30T23:45:00.000Z",
    );
    assertEquals(next.snapshotCreated, true);
    assertEquals(next.hasChanges, true);
    assertEquals(next.candidateCount, 1);
    assertEquals(next.candidatesCreated, 1);
    assertEquals(candidates.length, 1);

    const meta = candidates[0].metadata;
    assertEquals(meta.status, "pending_approval");
    assertEquals(meta.requires_human_approval, true);
    assertEquals(meta.auto_publish, false);
    assertEquals(meta.variant, CDP_TRACKER_VARIANT);
    assertEquals(meta.content_archetype, "data_report");
    assertEquals((meta.post_payload as JsonRecord).linkInReply, true);

    const lead = String(meta.text ?? "");
    const replies = (meta.reply_texts ?? []) as string[];
    assertStringIncludes(lead, "立憲民主党 地方議員データ集計・更新");
    assertStringIncludes(lead, "922→924人 (+2)");
    assertStringIncludes(lead, "東京都: 56→58人 (+2)");
    assertStringIncludes(replies[0] ?? "", "立憲民主党 地方議員 都道府県別内訳");
    assertStringIncludes(replies[1] ?? "", CDP_MEMBER_PAGE_URL);
    assertEquals(classifyPostArchetype(lead), "data_report");
  },
);
