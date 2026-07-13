import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildPartyGapCandidateMetadata,
  isoWeekKey,
  PARTY_GAP_VARIANT,
} from "./party_gap_ranking.ts";
import type {
  CanonicalLocalElectionSnapshot,
  CanonicalPrefecture,
} from "./snapshot_history.ts";
import { classifyPostArchetype } from "../growth-hub/x_post_archetype.ts";

function prefecture(
  name: string,
  kokumin: number,
  cdp: number,
): CanonicalPrefecture {
  return {
    prefecture: name,
    sourceUrl: `https://new-kokumin.jp/member/${name}`,
    currentMembers: kokumin,
    prefecturalAssemblyMembers: 0,
    municipalAssemblyMembers: kokumin,
    cdpLocalMembers: cdp,
    cdpSourceUrl: "https://cdp-japan.jp/members/house/local_authorities",
  };
}

/// 47 都道府県のフィクスチャ。上位・下位の実測値(2026-07-10 のポストA)を
/// 一部に埋め、残りは互角圏で埋める。
function snapshot(
  overridePrefectures?: CanonicalPrefecture[],
): CanonicalLocalElectionSnapshot {
  const names = Array.from({ length: 47 }, (_, index) => `県${index + 1}`);
  const prefectures = overridePrefectures ?? [
    prefecture("香川県", 26, 23),
    prefecture("茨城県", 22, 14),
    prefecture("北海道", 5, 57),
    prefecture("千葉県", 8, 57),
    prefecture("神奈川県", 14, 59),
    prefecture("鳥取県", 0, 18),
    ...names.slice(6).map((name) => prefecture(name, 3, 3)),
  ];
  return {
    metrics: {
      baselineCurrentLocalMembers: 340,
      officialCurrentLocalMembers: 378,
      targetLocalMembers: 700,
      baselineNetIncreaseRequired: 360,
      actualNetIncreaseRequired: 322,
      official2023FirstHalfWins: 62,
      official2023SecondHalfWins: 121,
      official2023TotalWins: 183,
    },
    collectionQuality: {
      complete: true,
      failedPrefectureFetches: [],
      linkedPrefectureCount: 47,
      minimumExpectedMemberCount: 300,
      officialElectionPrefectureLinkCount: 47,
      minimumExpectedOfficialElectionPrefectureLinks: 40,
      scheduleSourceCount: 1,
      scheduleFetchSuccessCount: 1,
      scheduleParsedSourceCount: 1,
      scheduleParsedEntryCount: 1,
      scheduleManualEntryCount: 0,
      scheduleManualFallbackOnly: false,
      failedScheduleSourceUrls: [],
      parserEmptyScheduleSourceUrls: [],
      failedRequiredScheduleSourceUrls: [],
      parserEmptyRequiredScheduleSourceUrls: [],
      issues: [],
    },
    sources: [
      {
        label: "Official members",
        url: "https://new-kokumin.jp/member",
        category: "official_members",
        note: "",
      },
    ],
    prefectures,
    members: [],
    upcomingSchedules: [],
  };
}

const OPTIONS = {
  snapshotObservationId: "obs-1",
  snapshotHash: "hash-1",
  datasetVersion: "v1",
  observedAt: "2026-07-13T21:00:00Z",
  datasetSource: "local-election-intelligence",
  dataset: "kokumin_local_election_intelligence",
};

Deno.test("isoWeekKey produces stable weekly keys", () => {
  // 同一 ISO 週(月曜起点)の日は同じキー=日次 cron でも週1候補。
  assertEquals(isoWeekKey("2026-07-13T21:00:00Z"), "2026-W29");
  assertEquals(isoWeekKey("2026-07-19T21:00:00Z"), "2026-W29");
  assertEquals(isoWeekKey("2026-07-20T21:00:00Z"), "2026-W30");
  assertEquals(isoWeekKey("not-a-date"), null);
});

Deno.test("buildPartyGapCandidateMetadata refuses thin or unsynced data", () => {
  // 県数欠損(取得失敗日)。
  assertEquals(
    buildPartyGapCandidateMetadata(
      snapshot([prefecture("東京都", 49, 56)]),
      OPTIONS,
    ),
    null,
  );
  // 立憲参考が全県 0 = 未同期日は比較を名乗らない。
  const zeroCdp = snapshot().prefectures.map((entry) => ({
    ...entry,
    cdpLocalMembers: 0,
  }));
  assertEquals(
    buildPartyGapCandidateMetadata(snapshot(zeroCdp), OPTIONS),
    null,
  );
  // observedAt 不正。
  assertEquals(
    buildPartyGapCandidateMetadata(snapshot(), {
      ...OPTIONS,
      observedAt: "junk",
    }),
    null,
  );
});

Deno.test("buildPartyGapCandidateMetadata composes the gap ranking candidate", () => {
  const metadata = buildPartyGapCandidateMetadata(snapshot(), OPTIONS);
  assert(metadata !== null);
  const text = String(metadata!.text);
  // ポストA構造の骨格。
  assert(text.includes("国民民主党×立憲民主党 地方議員 地力差 2026/7/14"));
  assert(text.includes("取得日時: 2026-07-13T21:00:00Z"));
  assert(text.includes("国民民主 公式地方議員数: 198人"));
  assert(text.includes("立憲民主 参考合計: 351人"));
  assert(text.includes("両党差分: -153人"));
  // リード上位は実ギャップ順(香川 +3 → 茨城 +8 が上)。
  assert(
    text.indexOf("茨城県 +8（22 vs 14）") <
      text.indexOf("香川県 +3（26 vs 23）"),
  );
  // 開拓余地は立憲リードの大きい順。
  assert(
    text.indexOf("神奈川県 -45（14 vs 59）") <
        text.indexOf("北海道 -52（5 vs 57）") === false,
  );
  assert(text.includes("開拓余地(立憲民主リード上位)"));
  assert(text.includes("参考値"));
  // メタデータ契約。
  assertEquals(metadata!.status, "pending_approval");
  assertEquals(metadata!.variant, PARTY_GAP_VARIANT);
  assertEquals(metadata!.content_archetype, "data_report");
  assertEquals(
    metadata!.candidate_key,
    "local-election:party-gap:2026-W29",
  );
  assertEquals(metadata!.requires_human_approval, true);
  assertEquals(metadata!.auto_publish, false);
});

Deno.test("gap ranking replies carry all-47 table, alerts, and final URL", () => {
  const metadata = buildPartyGapCandidateMetadata(snapshot(), OPTIONS);
  assert(metadata !== null);
  const replies = (metadata!.reply_texts as string[]) ?? [];
  assertEquals(replies.length, 3);
  const [table, alerts, cta] = replies;
  assert(table.includes("全都道府県の地力差"));
  // 47 県すべて載る(名簿相当の検索面)。
  assertEquals(table.split("\n").length, 2 + 47);
  assert(alerts.includes("🔴 国民民主 議員不在 1県: 鳥取県"));
  assert(cta.includes("utm_content=party_gap_ranking"));
  assert(!String(metadata!.text).includes("https://my-web-app"));
});

Deno.test("gap ranking self-classifies as data_report", () => {
  const metadata = buildPartyGapCandidateMetadata(snapshot(), OPTIONS);
  assert(metadata !== null);
  const full = [
    String(metadata!.text),
    ...((metadata!.reply_texts as string[]) ?? []),
  ].join("\n");
  assertEquals(classifyPostArchetype(full), "data_report");
});
