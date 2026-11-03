import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  evaluateScheduleCollectionQuality,
  type HubDataRow,
  type HubInsertResult,
  LOCAL_ELECTION_DATASET,
  LOCAL_ELECTION_SNAPSHOT_HUB_SOURCE,
  type LocalElectionHubStore,
  persistLocalElectionSnapshot,
  type ScheduleCollectionQuality,
  type ScheduleSourceFetchHealth,
  X_POST_CANDIDATE_HUB_SOURCE,
} from "./snapshot_history.ts";
import { normalizeCdpBenchmark } from "./party_gap_ranking.ts";
import {
  buildElectionIntelligenceSnapshot,
  type ElectionModeId,
  type ElectionModeRegistry,
  fallbackElectionModeRegistry,
  fallbackOfficialEndorsementSnapshot,
  normalizeElectionModeRegistry,
  normalizeOfficialEndorsementSnapshot,
  type OfficialEndorsementSnapshot,
  parseElectionMode,
  verifyElectionGoalSources,
} from "./election_mode.ts";
import {
  parseGo2SenkyoScheduleHtml,
  parseNewKokuminElectionListHtml,
  type ScheduleOverviewEntry,
} from "./schedule_source_parsers.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OFFICIAL_MEMBER_PAGE_URL = "https://new-kokumin.jp/member";
const OFFICIAL_ELECTION_PAGE_URL = "https://new-kokumin.jp/election";
const OFFICIAL_2023_FIRST_HALF_URL =
  "https://new-kokumin.jp/news/election/20230410_election";
const OFFICIAL_2023_SECOND_HALF_URL =
  "https://new-kokumin.jp/news/election/20230423_1";
const ELECTION_SCHEDULE_URL = "https://go2senkyo.com/schedule";
const CDP_LOCAL_AUTHORITIES_URL =
  "https://cdp-japan.jp/members/house/local_authorities";
// R28: 立憲実数の repo asset(週次 update_cdp_benchmark.mjs が正本)。
const CDP_BENCHMARK_ASSET_URL =
  "https://raw.githubusercontent.com/kanta13jp1/my_web_app/main/assets/data/cdp_local_members.json";
const ELECTION_MODE_REGISTRY_ASSET_URL =
  "https://raw.githubusercontent.com/kanta13jp1/my_web_app/main/assets/data/kokumin_election_modes.json";
const OFFICIAL_ENDORSEMENT_ASSET_URL =
  "https://raw.githubusercontent.com/kanta13jp1/my_web_app/main/assets/data/kokumin_local_endorsements.json";
const NEW_KOKUMIN_ELECTIONS_URL =
  "https://local-elections.new-kokumin.jp/electionslist/";
const NEXT_UNIFIED_LOCAL_ELECTION_INFO_URL =
  "https://senkyo-news.jp/unified-local-elections/";
const TARGET_LOCAL_MEMBERS = 700;
const BASELINE_CURRENT_LOCAL_MEMBERS = 340;
const MINIMUM_EXPECTED_OFFICIAL_ELECTION_PREFECTURE_LINKS = 10;
const SCHEDULE_PAST_DAYS = 14;
const NEXT_UNIFIED_LOCAL_ELECTION_SCHEDULE_END = "2027-04-25";
// ユーザー要件: 最低でも 1ヶ月分 (30日) の地方選予定を取得する。
// new-kokumin は 1,000件超のデータを返すため cap に余裕を持たせる。
// PS版#112: window 60→90 / cap 100→200
// Win版#80: cap 200→300 + SCHEDULE_MIN_WINDOW_DAYS=30 の最低保証を追加
const SCHEDULE_WINDOW_DAYS = 90;
const SCHEDULE_DETAIL_WINDOW_DAYS = 14;
const SCHEDULE_MAX_ENTRIES = 2000;
const AI_ANALYSIS_TIMEOUT_MS = 6000;
// 最低保証日数 (これを下回る window は使わない)
const SCHEDULE_MIN_WINDOW_DAYS = 30;

const JP_LOCAL_ASSEMBLY_MEMBERS = "\u5730\u65b9\u81ea\u6cbb\u4f53\u8b70\u54e1";
const JP_PLANNED_CANDIDATES = "\u5019\u88dc\u4e88\u5b9a\u8005";
const JP_FIELD_CONSTITUENCY = "\u9078\u6319\u533a";
const JP_FIELD_ELECTION_COUNT = "\u5f53\u9078\u56de\u6570";
const JP_FIELD_BIRTH_DATE = "\u751f\u5e74\u6708\u65e5";
const JP_FIELD_GENDER = "\u6027\u5225";
const JP_FIELD_PROFILE = "\u7d4c\u6b74";
const JP_FIELD_ANNOUNCEMENT_DATE = "\u544a\u793a\u65e5";
const JP_FIELD_SEATS_AND_CANDIDATES = "\u5b9a\u6570/\u5019\u88dc\u8005\u6570";
const JP_FIELD_SEATS_AND_CANDIDATES_ALT =
  "\u5b9a\u6570/\u7acb\u5019\u88dc\u8005\u6570";
const JP_UNDECIDED = "\u672a\u5b9a";

const PREFECTURES = [
  "\u5317\u6d77\u9053",
  "\u9752\u68ee\u770c",
  "\u5ca9\u624b\u770c",
  "\u5bae\u57ce\u770c",
  "\u79cb\u7530\u770c",
  "\u5c71\u5f62\u770c",
  "\u798f\u5cf6\u770c",
  "\u8328\u57ce\u770c",
  "\u6803\u6728\u770c",
  "\u7fa4\u99ac\u770c",
  "\u57fc\u7389\u770c",
  "\u5343\u8449\u770c",
  "\u6771\u4eac\u90fd",
  "\u795e\u5948\u5ddd\u770c",
  "\u65b0\u6f5f\u770c",
  "\u5bcc\u5c71\u770c",
  "\u77f3\u5ddd\u770c",
  "\u798f\u4e95\u770c",
  "\u5c71\u68a8\u770c",
  "\u9577\u91ce\u770c",
  "\u5c90\u961c\u770c",
  "\u9759\u5ca1\u770c",
  "\u611b\u77e5\u770c",
  "\u4e09\u91cd\u770c",
  "\u6ecb\u8cc0\u770c",
  "\u4eac\u90fd\u5e9c",
  "\u5927\u962a\u5e9c",
  "\u5175\u5eab\u770c",
  "\u5948\u826f\u770c",
  "\u548c\u6b4c\u5c71\u770c",
  "\u9ce5\u53d6\u770c",
  "\u5cf6\u6839\u770c",
  "\u5ca1\u5c71\u770c",
  "\u5e83\u5cf6\u770c",
  "\u5c71\u53e3\u770c",
  "\u5fb3\u5cf6\u770c",
  "\u9999\u5ddd\u770c",
  "\u611b\u5a9b\u770c",
  "\u9ad8\u77e5\u770c",
  "\u798f\u5ca1\u770c",
  "\u4f50\u8cc0\u770c",
  "\u9577\u5d0e\u770c",
  "\u718a\u672c\u770c",
  "\u5927\u5206\u770c",
  "\u5bae\u5d0e\u770c",
  "\u9e7f\u5150\u5cf6\u770c",
  "\u6c96\u7e04\u770c",
] as const;

type AssemblyCategory = "prefectural" | "municipal" | "other";

interface LocalLegislatorProfile {
  prefecture: string;
  sourceUrl: string;
  detailUrl: string;
  name: string;
  kana: string;
  constituency: string;
  municipality: string;
  assemblyLabel: string;
  assemblyCategory: AssemblyCategory;
  electionCountLabel: string;
  birthDate: string;
  age: number | null;
  gender: string;
  profile: string;
}

interface OfficialScheduledCandidate {
  prefecture: string;
  electionName: string;
  voteDate: string;
  name: string;
  statusLabel: string;
  detailUrl: string;
  sourceUrl: string;
  xHandle: string;
}

interface PrefectureReality {
  prefecture: string;
  sourceUrl: string;
  fetchStatus: "success" | "not_listed" | "failed";
  currentMembers: number;
  prefecturalAssemblyMembers: number;
  municipalAssemblyMembers: number;
  members: LocalLegislatorProfile[];
}

interface HistoricalResult {
  firstHalfWins: number;
  secondHalfWins: number;
  totalWins: number;
}

interface AiAnalysis {
  summary: string;
  alerts: string[];
  strategicNotes: string[];
  scheduleSummary: string;
  scheduleAlerts: string[];
}

interface LocalElectionScheduleEntry {
  electionName: string;
  prefecture: string;
  municipality: string;
  electionCategory: string;
  voteDate: string;
  announcementDate: string;
  detailUrl: string;
  officialCandidateSourceUrl: string;
  seatCount: number;
  totalCandidateCount: number;
  kokuminCandidateCount: number;
  kokuminCandidateNames: string[];
  kokuminCandidateStatuses: string[];
  kokuminCandidateVotes: number[];
  kokuminCandidateXHandles: string[];
  isPast: boolean;
}

interface ScheduleResultCandidate {
  name: string;
  party: string;
  statusLabel: string;
  votes: number;
}

interface ScheduleCandidateRow {
  name: string;
  statusLabel: string;
  votes: number;
  xHandle: string;
}

interface ScheduleSourceEntries {
  entries: ScheduleOverviewEntry[];
  health: ScheduleSourceFetchHealth;
}

interface ScheduleOverviewFetchResult {
  entries: ScheduleOverviewEntry[];
  sources: ScheduleSourceFetchHealth[];
}

interface UpcomingScheduleFetchResult {
  schedules: LocalElectionScheduleEntry[];
  collectionQuality: ScheduleCollectionQuality;
}

interface ManualScheduledCandidate {
  name: string;
  statusLabel?: string;
  xHandle?: string;
}

interface ManualScheduleSupplement {
  prefecture: string;
  municipality: string;
  electionName: string;
  voteDate: string;
  electionCategory?: string;
  detailUrl?: string;
  resultSourceUrls?: string[];
  officialCandidateSourceUrl?: string;
  announcementDate?: string;
  seatCount?: number;
  totalCandidateCount?: number;
  candidates: ManualScheduledCandidate[];
}

interface PrefectureDirectoryEntry {
  prefecture: string;
  sourceUrl: string;
}

const MANUAL_2026_SCHEDULES: ManualScheduleSupplement[] = [
  {
    prefecture: "東京都",
    municipality: "多摩市",
    electionName: "多摩市議会議員補欠選挙",
    voteDate: "2026-04-12",
    electionCategory: "assembly",
    candidates: [
      { name: "やまねひろし", xHandle: "PToksq0rZe12860" },
    ],
  },
  {
    prefecture: "鹿児島県",
    municipality: "出水市",
    electionName: "出水市議会議員選挙",
    voteDate: "2026-04-12",
    electionCategory: "assembly",
    candidates: [{ name: "浜田まさかず" }],
  },
  {
    prefecture: "栃木県",
    municipality: "栃木市",
    electionName: "栃木市議会議員補欠選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [{ name: "こだち 孝之", statusLabel: "推薦" }],
  },
  {
    prefecture: "埼玉県",
    municipality: "久喜市",
    electionName: "久喜市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [
      { name: "はやま 武士", statusLabel: "当選", xHandle: "hymtks0601" },
      {
        name: "坂本 かずひさ",
        statusLabel: "当選",
        xHandle: "Kazuhisa_SakaMT",
      },
    ],
  },
  {
    prefecture: "埼玉県",
    municipality: "春日部市",
    electionName: "春日部市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [
      { name: "えんどう 彩生", statusLabel: "当選", xHandle: "Saiki_Endo" },
    ],
  },
  {
    prefecture: "福井県",
    municipality: "坂井市",
    electionName: "坂井市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [{ name: "川畑たかはる" }],
  },
  {
    prefecture: "静岡県",
    municipality: "藤枝市",
    electionName: "藤枝市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [{ name: "八木勝", xHandle: "yagimasaru7" }],
  },
  {
    prefecture: "愛知県",
    municipality: "北名古屋市",
    electionName: "北名古屋市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    resultSourceUrls: ["https://go2senkyo.com/local/senkyo/26520"],
    candidates: [
      { name: "渡辺 あきら", xHandle: "watanabeakira06" },
      { name: "沢とおる", xHandle: "sawatoru2026" },
    ],
  },
  {
    prefecture: "大阪府",
    municipality: "河内長野市",
    electionName: "河内長野市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [{ name: "二口ゆたか", xHandle: "futakuchiyutaka" }],
  },
  {
    prefecture: "高知県",
    municipality: "土佐市",
    electionName: "土佐市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    resultSourceUrls: ["https://go2senkyo.com/local/senkyo/25823"],
    candidates: [],
  },
  {
    prefecture: "香川県",
    municipality: "綾川町",
    electionName: "綾川町議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [
      { name: "川崎やすふみ", xHandle: "yasurk" },
      { name: "山田やすし" },
    ],
  },
  {
    prefecture: "香川県",
    municipality: "まんのう町",
    electionName: "まんのう町議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [{ name: "橋田あきお" }],
  },
  {
    prefecture: "鹿児島県",
    municipality: "姶良市",
    electionName: "姶良市議会議員選挙",
    voteDate: "2026-04-19",
    electionCategory: "assembly",
    candidates: [{ name: "山下やすし" }],
  },
  {
    prefecture: "長野県",
    municipality: "中野市",
    electionName: "中野市議会議員選挙",
    voteDate: "2026-04-26",
    electionCategory: "assembly",
    candidates: [{ name: "あべ一真", xHandle: "N3yKOgfAqH2619" }],
  },
  {
    prefecture: "山口県",
    municipality: "山口市",
    electionName: "山口市議会議員選挙",
    voteDate: "2026-04-26",
    electionCategory: "assembly",
    resultSourceUrls: [
      "https://yama.minato-yamaguchi.co.jp/election-results/2026/yamaguchi-shigi/",
    ],
    candidates: [
      { name: "関谷拓馬", xHandle: "SekitaniTakuma" },
      { name: "野村ゆうたろう", statusLabel: "推薦", xHandle: "nomura_yutaro" },
    ],
  },
  {
    prefecture: "愛媛県",
    municipality: "松山市",
    electionName: "松山市議会議員選挙",
    voteDate: "2026-04-26",
    electionCategory: "assembly",
    resultSourceUrls: ["https://go2senkyo.com/local/senkyo/23307"],
    candidates: [
      { name: "伊藤 しゅん", xHandle: "itoh_syun0204" },
      { name: "十川 ゆういち", xHandle: "sogawa123" },
    ],
  },
  {
    prefecture: "福岡県",
    municipality: "小郡市",
    electionName: "小郡市議会議員選挙",
    voteDate: "2026-04-26",
    electionCategory: "assembly",
    candidates: [{ name: "高崎ゆうと", xHandle: "yuto_takasaki6" }],
  },
  {
    prefecture: "鹿児島県",
    municipality: "鹿屋市",
    electionName: "鹿屋市議会議員選挙",
    voteDate: "2026-04-26",
    electionCategory: "assembly",
    candidates: [{ name: "下之園政宏" }],
  },
  {
    prefecture: "東京都",
    municipality: "中野区",
    electionName: "中野区議会議員補欠選挙",
    voteDate: "2026-06-07",
    announcementDate: "2026-05-31",
    electionCategory: "assembly",
    detailUrl:
      "https://www.senkyo.metro.tokyo.lg.jp/election/schedule/senkyo2026",
    seatCount: 1,
    candidates: [],
  },
  {
    prefecture: "東京都",
    municipality: "立川市",
    electionName: "立川市議会議員選挙",
    voteDate: "2026-06-21",
    announcementDate: "2026-06-14",
    electionCategory: "assembly",
    detailUrl:
      "https://www.senkyo.metro.tokyo.lg.jp/election/schedule/senkyo2026",
    seatCount: 28,
    candidates: [],
  },
  {
    prefecture: "東京都",
    municipality: "杉並区",
    electionName: "杉並区議会議員補欠選挙",
    voteDate: "2026-06-28",
    announcementDate: "2026-06-21",
    electionCategory: "assembly",
    detailUrl:
      "https://www.senkyo.metro.tokyo.lg.jp/election/schedule/senkyo2026",
    seatCount: 1,
    candidates: [],
  },
  {
    prefecture: "東京都",
    municipality: "あきる野市",
    electionName: "あきる野市議会議員選挙",
    voteDate: "2026-07-19",
    announcementDate: "2026-07-12",
    electionCategory: "assembly",
    detailUrl:
      "https://www.senkyo.metro.tokyo.lg.jp/election/schedule/senkyo2026",
    seatCount: 21,
    candidates: [],
  },
];

// The official per-municipality 2027 unified-local-election calendar is not
// published yet, so upstream schedule pages can legitimately return only 2026.
// Keep the 2027 first/second-half voting windows visible as planning entries
// until the special law and individual election schedules are published.
const NEXT_UNIFIED_LOCAL_ELECTION_PLANNING_SCHEDULES:
  ManualScheduleSupplement[] = [
    {
      prefecture: "\u5168\u56fd",
      municipality: "\u5168\u56fd",
      electionName:
        "\u7b2c21\u56de\u7d71\u4e00\u5730\u65b9\u9078\u6319 \u524d\u534a\u6226\uff08\u9053\u5e9c\u770c\u30fb\u653f\u4ee4\u6307\u5b9a\u90fd\u5e02\u8b70\u4f1a\u8b70\u54e1\u9078\u6319\u30fb\u898b\u8fbc\u307f\uff09",
      voteDate: "2027-04-11",
      electionCategory: "assembly",
      detailUrl: NEXT_UNIFIED_LOCAL_ELECTION_INFO_URL,
      officialCandidateSourceUrl: NEXT_UNIFIED_LOCAL_ELECTION_INFO_URL,
      candidates: [],
    },
    {
      prefecture: "\u5168\u56fd",
      municipality: "\u5168\u56fd",
      electionName:
        "\u7b2c21\u56de\u7d71\u4e00\u5730\u65b9\u9078\u6319 \u5f8c\u534a\u6226\uff08\u5e02\u533a\u753a\u6751\u8b70\u4f1a\u8b70\u54e1\u9078\u6319\u30fb\u898b\u8fbc\u307f\uff09",
      voteDate: "2027-04-25",
      electionCategory: "assembly",
      detailUrl: NEXT_UNIFIED_LOCAL_ELECTION_INFO_URL,
      officialCandidateSourceUrl: NEXT_UNIFIED_LOCAL_ELECTION_INFO_URL,
      candidates: [],
    },
  ];

const MANUAL_SCHEDULE_SUPPLEMENTS: ManualScheduleSupplement[] = [
  ...MANUAL_2026_SCHEDULES,
  ...NEXT_UNIFIED_LOCAL_ELECTION_PLANNING_SCHEDULES,
];

interface SnapshotRequest {
  action: "snapshot" | "snapshotAndQueue";
  includeAiSummary: boolean;
  mode: ElectionModeId;
}

interface MemberDetailRequest {
  action: "memberDetail";
  detailUrl: string;
  prefectureHint: string;
}

type ParsedRequest = SnapshotRequest | MemberDetailRequest;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "GET" && req.method !== "POST") {
      throw new Error("Method not allowed. Use GET or POST.");
    }

    const parsedRequest = await parseRequest(req);
    if (parsedRequest.action === "memberDetail") {
      const profile = await fetchMemberDetail(
        parsedRequest.detailUrl,
        parsedRequest.prefectureHint,
      );
      return jsonResponse({ success: true, profile });
    }
    if (parsedRequest.action === "snapshotAndQueue") {
      requireServiceRole(req);
    }
    if (parsedRequest.mode !== "local") {
      throw new HttpError(
        409,
        `Election mode ${parsedRequest.mode} is registered but its collector is not active.`,
      );
    }

    const memberPageHtml = await fetchText(OFFICIAL_MEMBER_PAGE_URL);
    const officialElectionHtml = await fetchText(OFFICIAL_ELECTION_PAGE_URL);
    const prefectureDirectoryEntries = parsePrefectureDirectoryEntries(
      memberPageHtml,
    );
    const officialElectionPrefectureLinks =
      parseOfficialElectionPrefectureLinks(officialElectionHtml);

    const prefectureResults = await mapWithConcurrency(
      prefectureDirectoryEntries,
      12,
      async (entry) =>
        await fetchPrefectureReality(entry.prefecture, entry.sourceUrl),
    );

    const members = prefectureResults.flatMap((item) => item.members).sort(
      compareMembers,
    );
    const failedPrefectureFetches = prefectureResults
      .filter((item) => item.fetchStatus === "failed")
      .map((item) => item.prefecture);
    const officialCurrentLocalMembers = members.length;
    const linkedPrefectureCount = prefectureDirectoryEntries.filter((item) =>
      item.sourceUrl !== ""
    ).length;
    const minimumExpectedMemberCount = Math.floor(
      BASELINE_CURRENT_LOCAL_MEMBERS / 2,
    );
    const memberCollectionQualityIssues = [
      ...(failedPrefectureFetches.length > 0
        ? [`prefecture_fetch_failed:${failedPrefectureFetches.join(",")}`]
        : []),
      ...(linkedPrefectureCount < 10
        ? [`member_directory_links_too_low:${linkedPrefectureCount}`]
        : []),
      ...(officialCurrentLocalMembers < minimumExpectedMemberCount
        ? [`official_member_count_too_low:${officialCurrentLocalMembers}`]
        : []),
    ];
    // 立憲(CDP)地方議員数は週次 cron (update_cdp_benchmark.mjs → assets/data/
    // cdp_local_members.json → plan) が正本。この EF は取得せず 0 を返し、
    // クライアントは plan のバッチ値を利用する。
    const prefectures = prefectureResults.map((item) => ({
      prefecture: item.prefecture,
      sourceUrl: item.sourceUrl,
      currentMembers: item.currentMembers,
      prefecturalAssemblyMembers: item.prefecturalAssemblyMembers,
      municipalAssemblyMembers: item.municipalAssemblyMembers,
      cdpLocalMembers: 0,
      cdpSourceUrl: CDP_LOCAL_AUTHORITIES_URL,
    }));

    const historical = await fetchHistoricalResult();
    const electionRegistryResult = await loadElectionModeRegistry();
    const officialEndorsementResult = await loadOfficialEndorsementSnapshot();
    const goalVerification = await verifyElectionGoalSources(
      electionRegistryResult.registry,
      fetchText,
    );
    const scrapedScheduledCandidates = (
      await mapWithConcurrency(
        [...officialElectionPrefectureLinks.entries()],
        6,
        async ([prefecture, sourceUrl]) => {
          const html = await fetchText(sourceUrl);
          return parseOfficialScheduledCandidates(prefecture, sourceUrl, html);
        },
      )
    ).flat();
    const officialScheduledCandidates = mergeScheduledCandidates(
      scrapedScheduledCandidates,
      buildManualScheduledCandidates(MANUAL_SCHEDULE_SUPPLEMENTS),
    );
    const scheduleResult = await fetchUpcomingLocalElectionSchedules(
      officialScheduledCandidates,
      MANUAL_SCHEDULE_SUPPLEMENTS,
    );
    const upcomingSchedules = scheduleResult.schedules;
    const officialElectionPrefectureLinkCount =
      officialElectionPrefectureLinks.size;
    const collectionQualityIssues = [
      ...memberCollectionQualityIssues,
      ...(officialElectionPrefectureLinkCount <
          MINIMUM_EXPECTED_OFFICIAL_ELECTION_PREFECTURE_LINKS
        ? [
          `official_election_prefecture_links_too_low:${officialElectionPrefectureLinkCount}`,
        ]
        : []),
      ...scheduleResult.collectionQuality.issues,
      ...electionRegistryResult.issues,
      ...officialEndorsementResult.issues,
      ...goalVerification.issues,
    ];

    const electionIntelligence = buildElectionIntelligenceSnapshot({
      registry: electionRegistryResult.registry,
      selectedMode: parsedRequest.mode,
      verifiedGoalIds: goalVerification.verifiedGoalIds,
      officialEndorsements: officialEndorsementResult.snapshot,
      officialCurrentLocalMembers,
      official2023TotalWins: historical.totalWins,
    });

    const snapshotBase = {
      fetchedAt: new Date().toISOString(),
      baselineCurrentLocalMembers: BASELINE_CURRENT_LOCAL_MEMBERS,
      officialCurrentLocalMembers,
      targetLocalMembers: TARGET_LOCAL_MEMBERS,
      baselineNetIncreaseRequired: TARGET_LOCAL_MEMBERS -
        BASELINE_CURRENT_LOCAL_MEMBERS,
      actualNetIncreaseRequired: Math.max(
        0,
        TARGET_LOCAL_MEMBERS - officialCurrentLocalMembers,
      ),
      official2023FirstHalfWins: historical.firstHalfWins,
      official2023SecondHalfWins: historical.secondHalfWins,
      official2023TotalWins: historical.totalWins,
      electionIntelligence,
      sources: [
        {
          label: "Official members",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_members",
          note: "Official local legislator directory.",
        },
        {
          label: "Official profiles",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_member_profiles",
          note: "Age and profile are enriched from official detail pages.",
        },
        {
          label: "2023 first half",
          url: OFFICIAL_2023_FIRST_HALF_URL,
          category: "official_2023_first_half",
          note: "2023 unified local elections first-half result.",
        },
        {
          label: "2023 second half",
          url: OFFICIAL_2023_SECOND_HALF_URL,
          category: "official_2023_second_half",
          note: "2023 unified local elections second-half result.",
        },
        {
          label: "Official planned candidates",
          url: OFFICIAL_ELECTION_PAGE_URL,
          category: "official_local_elections",
          note: "Official planned-candidate source.",
        },
        {
          label: "Election mode and goal registry",
          url: ELECTION_MODE_REGISTRY_ASSET_URL,
          category: "election_intelligence_registry",
          note:
            "Versioned mode definitions and official goal-source contracts.",
        },
        {
          label: "Official local-election endorsement snapshot",
          url: OFFICIAL_ENDORSEMENT_ASSET_URL,
          category: "official_endorsement_snapshot",
          note:
            "Machine-validated snapshot generated from the party's official PDF.",
        },
        ...electionIntelligence.goals.map((goal) => ({
          label: goal.title,
          url: goal.sourceUrl,
          category: "official_party_goal",
          note: `Official goal source (${goal.verificationStatus}).`,
        })),
        {
          label: "CDP local authorities",
          url: CDP_LOCAL_AUTHORITIES_URL,
          category: "opposition_local_members",
          note:
            "Reference benchmark from Constitutional Democratic Party official local-authorities directory.",
        },
        {
          label: "Election schedule",
          url: ELECTION_SCHEDULE_URL,
          category: "schedule_source",
          note: "Voting date and announcement date source.",
        },
        {
          label: "April 2026 campaign supplement",
          url: OFFICIAL_ELECTION_PAGE_URL,
          category: "manual_campaign_schedule",
          note:
            "Manual supplement for April 2026 local election candidates and X handles shared by the campaign team.",
        },
        {
          label: "2027 unified local election planning",
          url: NEXT_UNIFIED_LOCAL_ELECTION_INFO_URL,
          category: "schedule_planning_placeholder",
          note:
            "Planning placeholder for the expected April 2027 unified local election windows until official dates and individual schedules are published.",
        },
      ],
      prefectures,
      members,
      upcomingSchedules,
      collectionQuality: {
        complete: collectionQualityIssues.length === 0,
        failedPrefectureFetches,
        linkedPrefectureCount,
        minimumExpectedMemberCount,
        officialElectionPrefectureLinkCount,
        minimumExpectedOfficialElectionPrefectureLinks:
          MINIMUM_EXPECTED_OFFICIAL_ELECTION_PREFECTURE_LINKS,
        scheduleSourceCount: scheduleResult.collectionQuality.sourceCount,
        scheduleFetchSuccessCount:
          scheduleResult.collectionQuality.fetchSuccessCount,
        scheduleParsedSourceCount:
          scheduleResult.collectionQuality.parsedSourceCount,
        scheduleParsedEntryCount:
          scheduleResult.collectionQuality.parsedEntryCount,
        scheduleManualEntryCount:
          scheduleResult.collectionQuality.manualEntryCount,
        scheduleManualFallbackOnly:
          scheduleResult.collectionQuality.manualFallbackOnly,
        failedScheduleSourceUrls:
          scheduleResult.collectionQuality.failedSourceUrls,
        parserEmptyScheduleSourceUrls:
          scheduleResult.collectionQuality.parserEmptySourceUrls,
        failedRequiredScheduleSourceUrls:
          scheduleResult.collectionQuality.failedRequiredSourceUrls,
        parserEmptyRequiredScheduleSourceUrls:
          scheduleResult.collectionQuality.parserEmptyRequiredSourceUrls,
        electionModeRegistryLoaded: electionRegistryResult.issues.length === 0,
        officialEndorsementSnapshotLoaded:
          officialEndorsementResult.issues.length === 0,
        verifiedGoalSourceCount: goalVerification.verifiedGoalIds.length,
        expectedGoalSourceCount: electionRegistryResult.registry.modes
          .flatMap((mode) => mode.goals).length,
        electionIntelligenceIssues: [
          ...electionRegistryResult.issues,
          ...officialEndorsementResult.issues,
          ...goalVerification.issues,
        ],
        issues: collectionQualityIssues,
      },
    };

    const aiAnalysis = parsedRequest.includeAiSummary
      ? await buildAiAnalysis(snapshotBase)
      : buildFallbackAnalysis(snapshotBase);

    const snapshot = {
      ...snapshotBase,
      aiSummary: aiAnalysis.summary,
      aiAlerts: aiAnalysis.alerts,
      aiStrategicNotes: aiAnalysis.strategicNotes,
      scheduleAiSummary: aiAnalysis.scheduleSummary,
      scheduleAiAlerts: aiAnalysis.scheduleAlerts,
    };
    if (
      parsedRequest.action === "snapshotAndQueue" &&
      collectionQualityIssues.length > 0
    ) {
      throw new HttpError(
        503,
        `Snapshot persistence skipped by collection quality gate: ${
          collectionQualityIssues.join("; ")
        }`,
      );
    }
    // R28: 立憲実数(週次 update_cdp_benchmark.mjs が正本の repo asset)を
    // EF 側で取得して地力差系列へ渡す。この EF の snapshot は cdpLocalMembers
    // を 0 ハードコードするため、これが本番で唯一の立憲実数源(レビュー F1:
    // これ無しでは系列が一度も候補を生成しない)。取得失敗は null → composer
    // 側の cdpTotal ゲートで自然に見送り(その週の候補を作らないだけで、
    // snapshot 永続化と delta 系列には影響しない)。
    let cdpByPrefecture: Record<string, number> | null = null;
    if (parsedRequest.action === "snapshotAndQueue") {
      try {
        cdpByPrefecture = normalizeCdpBenchmark(
          JSON.parse(await fetchText(CDP_BENCHMARK_ASSET_URL)),
        );
      } catch (_error) {
        cdpByPrefecture = null;
      }
    }
    const persistence = parsedRequest.action === "snapshotAndQueue"
      ? await persistLocalElectionSnapshot(
        createLocalElectionHubStore(),
        snapshot,
        new Date().toISOString(),
        { cdpByPrefecture },
      )
      : null;

    return jsonResponse({
      success: true,
      snapshot,
      ...(persistence
        ? {
          persistence: {
            dataset: persistence.dataset,
            datasetVersion: persistence.datasetVersion,
            snapshotHash: persistence.snapshotHash,
            previousSnapshotId: persistence.previousSnapshotId,
            previousSnapshotHash: persistence.previousSnapshotHash,
            baselineCreated: persistence.baselineCreated,
            snapshotCreated: persistence.snapshotCreated,
            deduplicated: persistence.deduplicated,
            significantKinds: persistence.significantKinds,
            candidateCount: persistence.candidateCount,
            candidatesCreated: persistence.candidatesCreated,
            snapshotId: persistence.snapshotRow.id,
            candidateIds: persistence.candidateRows.map((row) => row.id),
          },
        }
        : {}),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("local-election-intelligence failed:", message);
    const status = error instanceof HttpError ? error.status : 400;
    return jsonResponse({ success: false, error: message }, { status });
  }
});

async function parseRequest(req: Request): Promise<ParsedRequest> {
  let body: Record<string, unknown> = {};
  if (req.method === "POST") {
    try {
      const parsed = await req.json().catch(() => ({}));
      if (parsed && typeof parsed === "object") {
        body = parsed as Record<string, unknown>;
      }
    } catch {
      body = {};
    }
  }

  const requestedAction = typeof body.action === "string"
    ? body.action.trim()
    : "snapshot";
  if (requestedAction === "memberDetail") {
    return {
      action: "memberDetail",
      detailUrl: typeof body.detailUrl === "string"
        ? body.detailUrl.trim()
        : "",
      prefectureHint: typeof body.prefectureHint === "string"
        ? body.prefectureHint.trim()
        : "",
    };
  }

  if (req.method === "GET") {
    const url = new URL(req.url);
    return {
      action: "snapshot",
      includeAiSummary: url.searchParams.get("includeAiSummary") !== "false",
      mode: parseElectionMode(url.searchParams.get("mode")),
    };
  }

  if (
    requestedAction === "snapshotAndQueue" ||
    requestedAction === "snapshot_and_queue"
  ) {
    return {
      action: "snapshotAndQueue",
      // Persistence runs normally do not need request-time AI prose. The
      // canonical dataset excludes AI fields either way.
      includeAiSummary: body.includeAiSummary === true,
      mode: parseElectionMode(body.mode),
    };
  }

  return {
    action: "snapshot",
    includeAiSummary: body.includeAiSummary !== false,
    mode: parseElectionMode(body.mode),
  };
}

class HttpError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
  }
}

function requireServiceRole(req: Request): void {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    throw new HttpError(
      503,
      "Server persistence is not configured.",
    );
  }
  const bearer = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "").trim();
  if (!bearer || bearer !== SERVICE_ROLE_KEY) {
    throw new HttpError(
      401,
      "snapshotAndQueue requires service-role authorization.",
    );
  }
}

function asHubDataRow(value: unknown): HubDataRow {
  const row = value && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
  const id = typeof row.id === "string" ? row.id : "";
  const metadata = row.metadata && typeof row.metadata === "object" &&
      !Array.isArray(row.metadata)
    ? row.metadata as Record<string, unknown>
    : {};
  const createdAt = typeof row.created_at === "string" ? row.created_at : "";
  if (!id) throw new Error("hub_data row is missing id");
  return { id, metadata, created_at: createdAt };
}

function createLocalElectionHubStore(): LocalElectionHubStore {
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const findSnapshotTransition = async (
    dataset: string,
    previousSnapshotId: string | null,
    snapshotHash: string,
  ): Promise<HubDataRow | null> => {
    let query = admin
      .from("hub_data")
      .select("id, metadata, created_at")
      .eq("source", LOCAL_ELECTION_SNAPSHOT_HUB_SOURCE)
      .filter("metadata->>dataset", "eq", dataset)
      .filter("metadata->>snapshot_hash", "eq", snapshotHash);
    query = previousSnapshotId
      ? query.filter(
        "metadata->>previous_snapshot_id",
        "eq",
        previousSnapshotId,
      )
      : query.is("metadata->>previous_snapshot_id", null);
    const { data, error } = await query
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data ? asHubDataRow(data) : null;
  };

  const findCandidateByKey = async (
    candidateKey: string,
  ): Promise<HubDataRow | null> => {
    const { data, error } = await admin
      .from("hub_data")
      .select("id, metadata, created_at")
      .eq("source", X_POST_CANDIDATE_HUB_SOURCE)
      .filter("metadata->>user_id", "eq", "service_role")
      .filter("metadata->>candidate_key", "eq", candidateKey)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data ? asHubDataRow(data) : null;
  };

  const insertRow = async (
    source: string,
    metadata: Record<string, unknown>,
  ): Promise<HubDataRow> => {
    const { data, error } = await admin
      .from("hub_data")
      .insert({ source, metadata })
      .select("id, metadata, created_at")
      .single();
    if (error) {
      const enriched = new Error(error.message) as Error & { code?: string };
      enriched.code = error.code;
      throw enriched;
    }
    return asHubDataRow(data);
  };

  return {
    findSnapshotTransition,
    async findSnapshotById(snapshotId: string): Promise<HubDataRow | null> {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", LOCAL_ELECTION_SNAPSHOT_HUB_SOURCE)
        .eq("id", snapshotId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? asHubDataRow(data) : null;
    },
    async getLatestSnapshot(dataset: string): Promise<HubDataRow | null> {
      const { data, error } = await admin
        .from("hub_data")
        .select("id, metadata, created_at")
        .eq("source", LOCAL_ELECTION_SNAPSHOT_HUB_SOURCE)
        .filter("metadata->>dataset", "eq", dataset)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? asHubDataRow(data) : null;
    },
    async insertSnapshot(
      metadata: Record<string, unknown>,
    ): Promise<HubInsertResult> {
      const snapshotHash = String(metadata.snapshot_hash ?? "");
      const previousSnapshotId = typeof metadata.previous_snapshot_id ===
            "string" && metadata.previous_snapshot_id
        ? metadata.previous_snapshot_id
        : null;
      const existing = await findSnapshotTransition(
        LOCAL_ELECTION_DATASET,
        previousSnapshotId,
        snapshotHash,
      );
      if (existing) return { row: existing, created: false };
      try {
        return {
          row: await insertRow(LOCAL_ELECTION_SNAPSHOT_HUB_SOURCE, metadata),
          created: true,
        };
      } catch (error) {
        if ((error as { code?: string }).code !== "23505") throw error;
        const raced = await findSnapshotTransition(
          LOCAL_ELECTION_DATASET,
          previousSnapshotId,
          snapshotHash,
        );
        if (!raced) throw error;
        return { row: raced, created: false };
      }
    },
    async insertPostCandidate(
      metadata: Record<string, unknown>,
    ): Promise<HubInsertResult> {
      const candidateKey = String(metadata.candidate_key ?? "");
      if (!candidateKey) throw new Error("candidate_key is required");
      const existing = await findCandidateByKey(candidateKey);
      if (existing) return { row: existing, created: false };
      try {
        return {
          row: await insertRow(X_POST_CANDIDATE_HUB_SOURCE, metadata),
          created: true,
        };
      } catch (error) {
        if ((error as { code?: string }).code !== "23505") throw error;
        const raced = await findCandidateByKey(candidateKey);
        if (!raced) throw error;
        return { row: raced, created: false };
      }
    },
  };
}

function jsonResponse(body: unknown, init?: ResponseInit): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
}

async function fetchText(url: string): Promise<string> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "User-Agent":
          "my_web_app local-election-intelligence/2.1 (+https://my-web-app-b67f4.web.app/)",
      },
      redirect: "follow",
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`Fetch failed: ${response.status} ${url}`);
    }
    return await response.text();
  } finally {
    clearTimeout(timeoutId);
  }
}

async function loadElectionModeRegistry(): Promise<{
  registry: ElectionModeRegistry;
  issues: string[];
}> {
  try {
    const registry = normalizeElectionModeRegistry(
      JSON.parse(await fetchText(ELECTION_MODE_REGISTRY_ASSET_URL)),
    );
    return { registry, issues: [] };
  } catch (_error) {
    return {
      registry: fallbackElectionModeRegistry(),
      issues: ["election_mode_registry_fetch_or_validation_failed"],
    };
  }
}

async function loadOfficialEndorsementSnapshot(): Promise<{
  snapshot: OfficialEndorsementSnapshot;
  issues: string[];
}> {
  try {
    const snapshot = normalizeOfficialEndorsementSnapshot(
      JSON.parse(await fetchText(OFFICIAL_ENDORSEMENT_ASSET_URL)),
    );
    return { snapshot, issues: [] };
  } catch (_error) {
    return {
      snapshot: fallbackOfficialEndorsementSnapshot(),
      issues: ["official_endorsement_snapshot_fetch_or_validation_failed"],
    };
  }
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function fetchPrefectureReality(
  prefecture: string,
  sourceUrl: string,
): Promise<PrefectureReality> {
  if (sourceUrl === "") {
    return {
      prefecture,
      sourceUrl,
      fetchStatus: "not_listed",
      currentMembers: 0,
      prefecturalAssemblyMembers: 0,
      municipalAssemblyMembers: 0,
      members: [],
    };
  }

  let lastError: unknown = null;
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const html = await fetchText(sourceUrl);
      const members = parsePrefectureMembers(prefecture, sourceUrl, html);
      return {
        prefecture,
        sourceUrl,
        fetchStatus: "success",
        currentMembers: members.length,
        prefecturalAssemblyMembers: members.filter((item) =>
          item.assemblyCategory === "prefectural"
        ).length,
        municipalAssemblyMembers: members.filter((item) =>
          item.assemblyCategory === "municipal"
        ).length,
        members,
      };
    } catch (error) {
      lastError = error;
      if (attempt < 2) {
        await delay(350);
      }
    }
  }

  console.error(`Failed to fetch ${prefecture}:`, lastError);
  return {
    prefecture,
    sourceUrl,
    fetchStatus: "failed",
    currentMembers: 0,
    prefecturalAssemblyMembers: 0,
    municipalAssemblyMembers: 0,
    members: [],
  };
}

function prefectureSlug(prefecture: string): string {
  if (prefecture === "\u5317\u6d77\u9053") {
    return prefecture;
  }
  return prefecture.replace(/[\u90fd\u5e9c\u770c]$/u, "");
}

function prefectureLookupKey(prefecture: string): string {
  return prefectureSlug(normalizeWhitespace(prefecture).trim());
}

function parsePrefectureDirectoryEntries(
  html: string,
): PrefectureDirectoryEntry[] {
  const links = new Map<string, string>();
  const linkRegex =
    /<a[^>]+href="([^"]*\/member_tag\/[^"]+)"[^>]*>([\s\S]*?)<\/a>/gsi;
  for (const match of html.matchAll(linkRegex)) {
    const rawLabel = normalizeWhitespace(decodeHtml(stripTags(match[2] ?? "")))
      .trim();
    const label = extractPrefectureLabel(rawLabel);
    const rawHref = match[1]?.trim() ?? "";
    if (!isPrefectureName(label) || rawHref === "") {
      continue;
    }
    const sourceUrl = new URL(rawHref, OFFICIAL_MEMBER_PAGE_URL).toString();
    links.set(label, sourceUrl);
    links.set(prefectureLookupKey(label), sourceUrl);
  }
  return PREFECTURES.map((prefecture) => ({
    prefecture,
    sourceUrl: links.get(prefecture) ??
      links.get(prefectureLookupKey(prefecture)) ??
      "",
  }));
}

function parsePrefectureMembers(
  prefecture: string,
  sourceUrl: string,
  html: string,
): LocalLegislatorProfile[] {
  const sections = matchMemberListSections(html).filter((section) =>
    section.heading.includes(prefecture) &&
    section.heading.includes(JP_LOCAL_ASSEMBLY_MEMBERS)
  );
  const members: LocalLegislatorProfile[] = [];

  for (const section of sections) {
    for (const cardHtml of extractListItems(section.listHtml)) {
      const card = parseMemberCard(cardHtml, sourceUrl);
      const assemblyCategory = inferAssemblyCategory(card.assemblyLabel);
      if (card.name === "" || assemblyCategory === "other") {
        continue;
      }
      members.push({
        prefecture,
        sourceUrl,
        detailUrl: card.detailUrl,
        name: card.name,
        kana: card.kana,
        constituency: card.constituency,
        municipality: extractMunicipality(prefecture, card.constituency),
        assemblyLabel: card.assemblyLabel,
        assemblyCategory,
        electionCountLabel: card.electionCountLabel,
        birthDate: "",
        age: null,
        gender: "",
        profile: "",
      });
    }
  }

  const unique = new Map<string, LocalLegislatorProfile>();
  for (const member of members) {
    const key = member.detailUrl || `${member.prefecture}:${member.name}`;
    if (!unique.has(key)) {
      unique.set(key, member);
    }
  }
  return [...unique.values()];
}

async function fetchMemberDetail(
  detailUrl: string,
  prefectureHint = "",
): Promise<LocalLegislatorProfile> {
  validateMemberDetailUrl(detailUrl);
  const html = await fetchText(detailUrl);
  const titleParts = decodeHtml(
    stripTags(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? ""),
  )
    .split("|")
    .map((part) => normalizeWhitespace(part).trim())
    .filter((part) => part !== "");
  const fields = parseSimpleTable(html);
  const constituency = fields.get(JP_FIELD_CONSTITUENCY) ?? "";
  const electionCountLabel = fields.get(JP_FIELD_ELECTION_COUNT) ?? "";
  const birthDate = normalizeBirthDate(fields.get(JP_FIELD_BIRTH_DATE) ?? "");
  const gender = fields.get(JP_FIELD_GENDER) ?? "";
  const profile = fields.get(JP_FIELD_PROFILE) ?? "";
  const assemblyLabel = extractClassText(html, "category");
  const name = titleParts[0] ?? "";
  const kana = extractClassText(html, "kana");
  const titlePrefecture = titleParts.find((part) => isPrefectureName(part)) ??
    "";
  const prefecture = inferPrefectureFromConstituency(constituency) ||
    titlePrefecture || prefectureHint.trim();
  return {
    prefecture,
    sourceUrl: detailUrl,
    detailUrl,
    name,
    kana,
    constituency,
    municipality: extractMunicipality(prefecture, constituency),
    assemblyLabel,
    assemblyCategory: inferAssemblyCategory(assemblyLabel),
    electionCountLabel,
    birthDate,
    age: calculateAge(birthDate),
    gender,
    profile,
  };
}

function validateMemberDetailUrl(detailUrl: string) {
  const normalizedUrl = detailUrl.trim();
  if (normalizedUrl === "") {
    throw new Error("Member detail URL is empty.");
  }
  const parsedUrl = new URL(normalizedUrl);
  if (
    parsedUrl.hostname !== "new-kokumin.jp" ||
    !parsedUrl.pathname.startsWith("/member/")
  ) {
    throw new Error("Only official member detail paths are allowed.");
  }
}

async function fetchHistoricalResult(): Promise<HistoricalResult> {
  const fallback = { firstHalfWins: 62, secondHalfWins: 121, totalWins: 183 };
  try {
    const [firstHalfText, secondHalfText] = await Promise.all([
      fetchText(OFFICIAL_2023_FIRST_HALF_URL).then((html) =>
        normalizeWhitespace(stripHtmlToText(html))
      ),
      fetchText(OFFICIAL_2023_SECOND_HALF_URL).then((html) =>
        normalizeWhitespace(stripHtmlToText(html))
      ),
    ]);
    const firstHalfWins =
      extractCount(firstHalfText, /(\d+)\s*\u4eba[^\n]{0,40}\u5f53\u9078/u) ??
        fallback.firstHalfWins;
    const secondHalfWins =
      extractCount(secondHalfText, /(\d+)\s*\u4eba[^\n]{0,40}\u5f53\u9078/u) ??
        fallback.secondHalfWins;
    const totalWins =
      extractCount(secondHalfText, /\u5408\u8a08[^\d]*(\d+)\s*\u4eba/u) ??
        firstHalfWins + secondHalfWins;
    return { firstHalfWins, secondHalfWins, totalWins };
  } catch {
    return fallback;
  }
}

function parseOfficialElectionPrefectureLinks(
  html: string,
): Map<string, string> {
  const links = new Map<string, string>();
  const linkRegex =
    /<a[^>]+href="([^"]*post_type=election[^"]*prefectures=[^"]+)"[^>]*>(.*?)<\/a>/gsi;
  for (const match of html.matchAll(linkRegex)) {
    const label = normalizeWhitespace(decodeHtml(stripTags(match[2] ?? "")))
      .trim();
    const rawHref = match[1]?.trim() ?? "";
    if (!isPrefectureName(label) || rawHref === "") {
      continue;
    }
    links.set(label, new URL(rawHref, OFFICIAL_ELECTION_PAGE_URL).toString());
  }
  return links;
}

function parseOfficialScheduledCandidates(
  prefecture: string,
  sourceUrl: string,
  html: string,
): OfficialScheduledCandidate[] {
  const candidates: OfficialScheduledCandidate[] = [];
  const sections = matchMemberListSections(html).filter((section) =>
    section.heading.includes(prefecture) &&
    section.heading.includes(JP_PLANNED_CANDIDATES)
  );

  for (const section of sections) {
    for (const cardHtml of extractListItems(section.listHtml)) {
      const card = parseMemberCard(cardHtml, sourceUrl);
      const electionName = card.electionCountLabel;
      const voteDate = normalizeOfficialVoteDate(
        extractClassText(cardHtml, "m_category"),
      );
      const statusLabel = extractClassText(cardHtml, "wins");
      if (
        card.name === "" || electionName === "" || statusLabel === "" ||
        !isLocalElectionName(electionName)
      ) {
        continue;
      }
      candidates.push({
        prefecture,
        electionName,
        voteDate,
        name: card.name,
        statusLabel,
        detailUrl: card.detailUrl,
        sourceUrl,
        xHandle: "",
      });
    }
  }
  return candidates;
}

async function fetchUpcomingLocalElectionSchedules(
  officialCandidates: OfficialScheduledCandidate[],
  manualSupplements: ManualScheduleSupplement[],
): Promise<UpcomingScheduleFetchResult> {
  const today = startOfDay(new Date());
  const earliestDate = addDays(today, -SCHEDULE_PAST_DAYS);
  const windowDays = Math.max(SCHEDULE_WINDOW_DAYS, SCHEDULE_MIN_WINDOW_DAYS);
  // 最低保証日数 (SCHEDULE_MIN_WINDOW_DAYS) を下限として最終日を決定
  const latestDate = resolveScheduleLatestDate(today, windowDays);
  const detailCutoffDate = addDays(today, SCHEDULE_DETAIL_WINDOW_DAYS);
  const overviewFetch = await fetchScheduleOverviewEntries(
    earliestDate,
    latestDate,
  );
  const manualOverviewEntries = buildManualOverviewEntries(manualSupplements);
  const collectionQuality = evaluateScheduleCollectionQuality(
    overviewFetch.sources,
    manualOverviewEntries.length,
  );
  const overviewEntries = mergeScheduleOverviewEntries(
    overviewFetch.entries,
    manualOverviewEntries,
  ).filter(isTargetScheduleOverviewEntry);
  const upcomingEntries = overviewEntries
    .filter((entry) => {
      const voteDate = parseIsoDate(entry.voteDate);
      return voteDate != null &&
        voteDate.getTime() >= earliestDate.getTime() &&
        voteDate.getTime() <= latestDate.getTime();
    })
    .sort((left, right) => {
      const leftDate = parseIsoDate(left.voteDate);
      const rightDate = parseIsoDate(right.voteDate);
      if (leftDate != null && rightDate != null) {
        const dateCompare = leftDate.getTime() - rightDate.getTime();
        if (dateCompare !== 0) {
          return dateCompare;
        }
      }
      return left.electionName.localeCompare(right.electionName, "ja");
    })
    .slice(0, SCHEDULE_MAX_ENTRIES);
  const detailed = await mapWithConcurrency(
    upcomingEntries,
    16,
    async (entry) => {
      const voteDate = parseIsoDate(entry.voteDate);
      const shouldFetchDetail = voteDate != null &&
        voteDate.getTime() <= detailCutoffDate.getTime();
      const supplement = findManualScheduleSupplement(
        entry,
        manualSupplements,
      );
      const baseEntry = await enrichScheduleEntry(
        entry,
        officialCandidates,
        shouldFetchDetail,
      );
      const supplementedEntry = applyManualScheduleSupplement(
        baseEntry,
        supplement,
      );
      return await applyScheduleResultSources(supplementedEntry, supplement);
    },
  );
  const schedules = detailed.sort((left, right) => {
    const leftDate = parseIsoDate(left.voteDate);
    const rightDate = parseIsoDate(right.voteDate);
    if (leftDate != null && rightDate != null) {
      const dateCompare = leftDate.getTime() - rightDate.getTime();
      if (dateCompare !== 0) {
        return dateCompare;
      }
    }
    const severityCompare = scheduleSeverity(left) - scheduleSeverity(right);
    if (severityCompare !== 0) {
      return severityCompare;
    }
    return left.electionName.localeCompare(right.electionName, "ja");
  });
  return { schedules, collectionQuality };
}

function resolveScheduleLatestDate(today: Date, windowDays: number): Date {
  const rollingLatestDate = addDays(today, windowDays);
  const unifiedElectionEndDate = parseIsoDate(
    NEXT_UNIFIED_LOCAL_ELECTION_SCHEDULE_END,
  );
  if (
    unifiedElectionEndDate == null ||
    unifiedElectionEndDate.getTime() < today.getTime()
  ) {
    return rollingLatestDate;
  }
  return unifiedElectionEndDate.getTime() > rollingLatestDate.getTime()
    ? unifiedElectionEndDate
    : rollingLatestDate;
}

async function fetchScheduleOverviewEntries(
  earliestDate: Date,
  latestDate: Date,
): Promise<ScheduleOverviewFetchResult> {
  const years = new Set<number>();
  for (
    let year = earliestDate.getFullYear();
    year <= latestDate.getFullYear();
    year += 1
  ) {
    years.add(year);
  }

  // Fetch both the base URL (guaranteed to work) and year-specific URLs.
  // mergeScheduleOverviewEntries handles deduplication downstream.
  const urls = [
    ELECTION_SCHEDULE_URL,
    ...[...years].map(scheduleUrlForYear),
  ];

  const [go2senkyoSources, newKokuminSource] = await Promise.all([
    Promise.all(
      urls.map(async (url) => {
        try {
          const html = await fetchText(url);
          const entries = parseGo2SenkyoScheduleHtml(html);
          return {
            entries,
            health: {
              url,
              requiredForPersistence: url === ELECTION_SCHEDULE_URL,
              fetchSucceeded: true,
              parsedEntryCount: entries.length,
            },
          } satisfies ScheduleSourceEntries;
        } catch (error) {
          console.error(`Failed to fetch schedule page ${url}:`, error);
          return {
            entries: [],
            health: {
              url,
              requiredForPersistence: url === ELECTION_SCHEDULE_URL,
              fetchSucceeded: false,
              parsedEntryCount: 0,
            },
          } satisfies ScheduleSourceEntries;
        }
      }),
    ),
    fetchNewKokuminScheduleEntries(),
  ]);

  return {
    entries: mergeScheduleOverviewEntries(
      go2senkyoSources.flatMap((source) => source.entries),
      newKokuminSource.entries,
    ),
    sources: [
      ...go2senkyoSources.map((source) => source.health),
      newKokuminSource.health,
    ],
  };
}

function scheduleUrlForYear(year: number): string {
  return `${ELECTION_SCHEDULE_URL}/${year}`;
}

async function fetchNewKokuminScheduleEntries(): Promise<
  ScheduleSourceEntries
> {
  let html: string;
  try {
    html = await fetchText(NEW_KOKUMIN_ELECTIONS_URL);
  } catch (error) {
    console.error("Failed to fetch new-kokumin elections page:", error);
    return {
      entries: [],
      health: {
        url: NEW_KOKUMIN_ELECTIONS_URL,
        requiredForPersistence: true,
        fetchSucceeded: false,
        parsedEntryCount: 0,
      },
    };
  }
  const entries = parseNewKokuminElectionListHtml(html);
  return {
    entries,
    health: {
      url: NEW_KOKUMIN_ELECTIONS_URL,
      requiredForPersistence: true,
      fetchSucceeded: true,
      parsedEntryCount: entries.length,
    },
  };
}

function buildManualScheduledCandidates(
  supplements: ManualScheduleSupplement[],
): OfficialScheduledCandidate[] {
  return supplements.filter(isTargetManualScheduleSupplement).flatMap(
    (entry) => {
      const sourceUrl = entry.officialCandidateSourceUrl?.trim() ||
        OFFICIAL_ELECTION_PAGE_URL;
      return entry.candidates.map((candidate) => ({
        prefecture: entry.prefecture,
        electionName: entry.electionName,
        voteDate: entry.voteDate,
        name: normalizeMemberName(candidate.name),
        statusLabel: candidate.statusLabel?.trim() ?? "",
        detailUrl: entry.detailUrl?.trim() ?? "",
        sourceUrl,
        xHandle: normalizeXHandle(candidate.xHandle),
      }));
    },
  );
}

function buildManualOverviewEntries(
  supplements: ManualScheduleSupplement[],
): ScheduleOverviewEntry[] {
  return supplements.filter(isTargetManualScheduleSupplement).map((entry) => ({
    electionName: entry.electionName,
    prefecture: entry.prefecture,
    voteDate: entry.voteDate,
    detailUrl: entry.detailUrl?.trim() ?? "",
  }));
}

function isTargetManualScheduleSupplement(
  entry: ManualScheduleSupplement,
): boolean {
  const category = entry.electionCategory?.trim() ?? "";
  if (category === "chief" || category.includes("首長")) {
    return false;
  }
  if (category === "assembly") {
    return true;
  }
  return inferElectionCategory(entry.electionName) === "assembly";
}

function isTargetScheduleOverviewEntry(entry: ScheduleOverviewEntry): boolean {
  return inferElectionCategory(entry.electionName) === "assembly";
}

function mergeScheduleOverviewEntries(
  scrapedEntries: ScheduleOverviewEntry[],
  manualEntries: ScheduleOverviewEntry[],
): ScheduleOverviewEntry[] {
  const merged = new Map<string, ScheduleOverviewEntry>();
  for (const entry of [...scrapedEntries, ...manualEntries]) {
    const key = scheduleMatchKey(
      entry.prefecture,
      entry.electionName,
      entry.voteDate,
    );
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, entry);
      continue;
    }
    merged.set(key, {
      electionName: existing.electionName.length >= entry.electionName.length
        ? existing.electionName
        : entry.electionName,
      prefecture: existing.prefecture,
      voteDate: existing.voteDate,
      detailUrl: existing.detailUrl !== ""
        ? existing.detailUrl
        : entry.detailUrl,
    });
  }
  return [...merged.values()];
}

function mergeScheduledCandidates(
  scrapedCandidates: OfficialScheduledCandidate[],
  manualCandidates: OfficialScheduledCandidate[],
): OfficialScheduledCandidate[] {
  const merged = new Map<string, OfficialScheduledCandidate>();
  for (const candidate of [...scrapedCandidates, ...manualCandidates]) {
    const key = scheduledCandidateKey(candidate);
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, candidate);
      continue;
    }
    merged.set(key, {
      prefecture: existing.prefecture,
      electionName:
        existing.electionName.length >= candidate.electionName.length
          ? existing.electionName
          : candidate.electionName,
      voteDate: existing.voteDate !== ""
        ? existing.voteDate
        : candidate.voteDate,
      name: existing.name,
      statusLabel: existing.statusLabel !== ""
        ? existing.statusLabel
        : candidate.statusLabel,
      detailUrl: existing.detailUrl !== ""
        ? existing.detailUrl
        : candidate.detailUrl,
      sourceUrl: existing.sourceUrl !== ""
        ? existing.sourceUrl
        : candidate.sourceUrl,
      xHandle: existing.xHandle !== "" ? existing.xHandle : candidate.xHandle,
    });
  }
  return [...merged.values()];
}

async function enrichScheduleEntry(
  entry: ScheduleOverviewEntry,
  officialCandidates: OfficialScheduledCandidate[],
  includeDetail = true,
): Promise<LocalElectionScheduleEntry> {
  const matchedCandidates = matchOfficialCandidatesForSchedule(
    entry.prefecture,
    entry.electionName,
    entry.voteDate,
    officialCandidates,
  );
  let announcementDate = "";
  let seatCount = 0;
  let totalCandidateCount = 0;
  let resultCandidates: ScheduleResultCandidate[] = [];
  if (includeDetail && entry.detailUrl !== "") {
    try {
      const html = await fetchText(entry.detailUrl);
      const detail = parseScheduleDetail(html);
      announcementDate = detail.announcementDate;
      seatCount = detail.seatCount;
      totalCandidateCount = detail.totalCandidateCount;
      resultCandidates = detail.candidateResults;
    } catch (error) {
      console.error(
        `Failed to fetch schedule detail ${entry.detailUrl}:`,
        error,
      );
    }
  }
  const candidateRows = applyScheduleResultCandidateRows(
    matchedCandidates.map((item) => ({
      name: item.name,
      statusLabel: item.statusLabel,
      votes: 0,
      xHandle: item.xHandle,
    })),
    resultCandidates,
  );
  const voteDateParsed = parseIsoDate(entry.voteDate);
  const isPast = voteDateParsed != null &&
    voteDateParsed.getTime() < startOfDay(new Date()).getTime();
  return {
    electionName: entry.electionName,
    prefecture: entry.prefecture,
    municipality: extractScheduleMunicipality(
      entry.electionName,
      entry.prefecture,
    ),
    electionCategory: inferElectionCategory(entry.electionName),
    voteDate: entry.voteDate,
    announcementDate,
    detailUrl: entry.detailUrl,
    officialCandidateSourceUrl: matchedCandidates[0]?.sourceUrl ??
      OFFICIAL_ELECTION_PAGE_URL,
    seatCount,
    totalCandidateCount,
    kokuminCandidateCount: candidateRows.length,
    kokuminCandidateNames: candidateRows.map((item) => item.name),
    kokuminCandidateStatuses: candidateRows.map((item) => item.statusLabel),
    kokuminCandidateVotes: candidateRows.map((item) => item.votes),
    kokuminCandidateXHandles: candidateRows.map((item) => item.xHandle),
    isPast,
  };
}

function findManualScheduleSupplement(
  entry: ScheduleOverviewEntry | LocalElectionScheduleEntry,
  supplements: ManualScheduleSupplement[],
): ManualScheduleSupplement | undefined {
  const key = scheduleMatchKey(
    entry.prefecture,
    entry.electionName,
    entry.voteDate,
  );
  return supplements.find(
    (item) =>
      scheduleMatchKey(item.prefecture, item.electionName, item.voteDate) ===
        key,
  );
}

function applyManualScheduleSupplement(
  entry: LocalElectionScheduleEntry,
  supplement?: ManualScheduleSupplement,
): LocalElectionScheduleEntry {
  if (!supplement) {
    return entry;
  }
  const mergedCandidates = mergeScheduleCandidateRows(
    entry.kokuminCandidateNames.map((name, index) => ({
      name,
      statusLabel: entry.kokuminCandidateStatuses[index] ?? "",
      votes: entry.kokuminCandidateVotes[index] ?? 0,
      xHandle: entry.kokuminCandidateXHandles[index] ?? "",
    })),
    supplement.candidates.map((candidate) => ({
      name: candidate.name,
      statusLabel: candidate.statusLabel?.trim() ?? "",
      votes: 0,
      xHandle: normalizeXHandle(candidate.xHandle),
    })),
  );
  return {
    electionName: entry.electionName,
    prefecture: entry.prefecture,
    municipality: supplement.municipality.trim() || entry.municipality,
    electionCategory: supplement.electionCategory?.trim() ||
      entry.electionCategory,
    voteDate: entry.voteDate,
    announcementDate: entry.announcementDate !== ""
      ? entry.announcementDate
      : (supplement.announcementDate?.trim() ?? ""),
    detailUrl: entry.detailUrl !== ""
      ? entry.detailUrl
      : (supplement.detailUrl?.trim() ?? ""),
    officialCandidateSourceUrl: entry.officialCandidateSourceUrl !== ""
      ? entry.officialCandidateSourceUrl
      : (supplement.officialCandidateSourceUrl?.trim() ??
        OFFICIAL_ELECTION_PAGE_URL),
    seatCount: entry.seatCount > 0
      ? entry.seatCount
      : (supplement.seatCount ?? 0),
    totalCandidateCount: entry.totalCandidateCount > 0
      ? entry.totalCandidateCount
      : (supplement.totalCandidateCount ?? 0),
    kokuminCandidateCount: mergedCandidates.length,
    kokuminCandidateNames: mergedCandidates.map((item) => item.name),
    kokuminCandidateStatuses: mergedCandidates.map((item) => item.statusLabel),
    kokuminCandidateVotes: mergedCandidates.map((item) => item.votes),
    kokuminCandidateXHandles: mergedCandidates.map((item) => item.xHandle),
    isPast: entry.isPast,
  };
}

function mergeScheduleCandidateRows(
  base: ScheduleCandidateRow[],
  supplement: ScheduleCandidateRow[],
): ScheduleCandidateRow[] {
  const merged = new Map<string, ScheduleCandidateRow>();
  for (const candidate of [...base, ...supplement]) {
    const normalizedName = normalizeMemberName(candidate.name);
    if (normalizedName === "") {
      continue;
    }
    const key = normalizeCandidateNameForKey(normalizedName);
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, {
        name: normalizedName,
        statusLabel: candidate.statusLabel.trim(),
        votes: Math.max(0, Math.trunc(candidate.votes)),
        xHandle: normalizeXHandle(candidate.xHandle),
      });
      continue;
    }
    merged.set(key, {
      name: existing.name,
      statusLabel: existing.statusLabel !== ""
        ? existing.statusLabel
        : candidate.statusLabel.trim(),
      votes: existing.votes > 0
        ? existing.votes
        : Math.max(0, Math.trunc(candidate.votes)),
      xHandle: existing.xHandle !== ""
        ? existing.xHandle
        : normalizeXHandle(candidate.xHandle),
    });
  }
  return [...merged.values()];
}

async function applyScheduleResultSources(
  entry: LocalElectionScheduleEntry,
  supplement?: ManualScheduleSupplement,
): Promise<LocalElectionScheduleEntry> {
  if (!entry.isPast || !needsScheduleResultRecovery(entry, supplement)) {
    return entry;
  }
  const urls = uniqueStrings([
    entry.detailUrl,
    ...(supplement?.resultSourceUrls ?? []),
  ]);
  if (urls.length === 0) {
    return entry;
  }

  const candidateResults = (
    await mapWithConcurrency(urls, 4, async (url) => {
      try {
        const html = await fetchText(url);
        return parseScheduleResultDocument(html, entry.seatCount);
      } catch (error) {
        console.error(`Failed to fetch schedule result ${url}:`, error);
        return [] as ScheduleResultCandidate[];
      }
    })
  ).flat();
  if (candidateResults.length === 0) {
    return entry;
  }

  const candidateRows = recoverScheduleCandidateRows(entry, candidateResults);

  return {
    ...entry,
    kokuminCandidateCount: candidateRows.length,
    kokuminCandidateNames: candidateRows.map((item) => item.name),
    kokuminCandidateStatuses: candidateRows.map((item) => item.statusLabel),
    kokuminCandidateVotes: candidateRows.map((item) => item.votes),
    kokuminCandidateXHandles: candidateRows.map((item) => item.xHandle),
  };
}

function needsScheduleResultRecovery(
  entry: LocalElectionScheduleEntry,
  supplement?: ManualScheduleSupplement,
) {
  if (hasUnresolvedScheduleCandidate(entry)) {
    return true;
  }
  const hasResultSource = entry.detailUrl.trim() !== "" ||
    (supplement?.resultSourceUrls ?? []).length > 0;
  return entry.kokuminCandidateNames.length === 0 &&
    hasResultSource &&
    isLocalElectionName(entry.electionName);
}

function hasUnresolvedScheduleCandidate(entry: LocalElectionScheduleEntry) {
  return entry.kokuminCandidateNames.some((name, index) =>
    name.trim() !== "" &&
    !isResolvedScheduleOutcomeStatus(
      entry.kokuminCandidateStatuses[index] ?? "",
    )
  );
}

function recoverScheduleCandidateRows(
  entry: LocalElectionScheduleEntry,
  resultCandidates: ScheduleResultCandidate[],
): ScheduleCandidateRow[] {
  const baseRows = entry.kokuminCandidateNames.map((name, index) => ({
    name,
    statusLabel: entry.kokuminCandidateStatuses[index] ?? "",
    votes: entry.kokuminCandidateVotes[index] ?? 0,
    xHandle: entry.kokuminCandidateXHandles[index] ?? "",
  }));
  if (baseRows.length > 0) {
    return applyScheduleResultCandidateRows(baseRows, resultCandidates);
  }
  const recoveredRows = resultCandidates
    .filter(isKokuminResultCandidate)
    .map((candidate) => ({
      name: candidate.name,
      statusLabel: candidate.statusLabel,
      votes: candidate.votes,
      xHandle: "",
    }));
  return mergeScheduleCandidateRows([], recoveredRows);
}

function isKokuminResultCandidate(candidate: ScheduleResultCandidate): boolean {
  const party = normalizeWhitespace(candidate.party).replace(/[ \u3000]/g, "");
  return party.includes("国民民主党") || party === "国民民主";
}

function isResolvedScheduleOutcomeStatus(value: string): boolean {
  const normalized = normalizeWhitespace(value);
  return normalized.includes("当選") ||
    normalized.includes("トップ") ||
    normalized.includes("再選") ||
    normalized.includes("無投票") ||
    normalized.includes("落選") ||
    normalized.includes("次点") ||
    normalized.includes("敗");
}

function parseScheduleDetail(
  html: string,
): {
  announcementDate: string;
  seatCount: number;
  totalCandidateCount: number;
  candidateResults: ScheduleResultCandidate[];
} {
  const fields = parseSimpleTable(html);
  const countsValue = fields.get(JP_FIELD_SEATS_AND_CANDIDATES) ??
    fields.get(JP_FIELD_SEATS_AND_CANDIDATES_ALT) ?? "";
  const countsMatch = toAsciiDigits(countsValue).match(/(\d+)\s*\/\s*(\d+)/);
  const seatCount = countsMatch ? Number.parseInt(countsMatch[1], 10) : 0;
  return {
    announcementDate: normalizeJapaneseDate(
      fields.get(JP_FIELD_ANNOUNCEMENT_DATE) ?? "",
    ),
    seatCount,
    totalCandidateCount: countsMatch ? Number.parseInt(countsMatch[2], 10) : 0,
    candidateResults: parseScheduleResultDocument(html, seatCount),
  };
}

function parseScheduleResultDocument(
  html: string,
  seatCount: number,
): ScheduleResultCandidate[] {
  return mergeScheduleResultCandidates([
    ...parseGo2SenkyoCandidateResults(html, seatCount),
    ...parseFlatScheduleResultRows(html, seatCount),
  ], seatCount);
}

function parseGo2SenkyoCandidateResults(
  html: string,
  seatCount: number,
): ScheduleResultCandidate[] {
  const headings = [...html.matchAll(/<h2\b[^>]*>([\s\S]*?)<\/h2>/gsi)].map((
    match,
  ) => ({
    html: match[0] ?? "",
    innerHtml: match[1] ?? "",
    index: match.index ?? 0,
  }));
  const candidates: ScheduleResultCandidate[] = [];

  for (let index = 0; index < headings.length; index += 1) {
    const current = headings[index];
    const next = headings[index + 1];
    const previous = headings[index - 1];
    const headingEnd = current.index + current.html.length;
    const nextStart = next?.index ?? html.length;
    const previousEnd = previous ? previous.index + previous.html.length : 0;
    const rawName = normalizeWhitespace(
      decodeHtml(stripTags(current.innerHtml)),
    );
    const name = extractGo2SenkyoCandidateName(rawName);
    if (name === "") {
      continue;
    }

    const bodyHtml = html.slice(headingEnd, nextStart);
    const votes = extractGo2SenkyoCandidateVotes(bodyHtml);
    const party = extractGo2SenkyoCandidateParty(bodyHtml);
    const statusLabel = extractGo2SenkyoCandidateStatus(
      html.slice(previousEnd, current.index),
    );
    if (votes <= 0 && party === "" && statusLabel === "") {
      continue;
    }
    candidates.push({ name, party, statusLabel, votes });
  }

  return inferMissingResultStatuses(candidates, seatCount);
}

function parseFlatScheduleResultRows(
  html: string,
  seatCount: number,
): ScheduleResultCandidate[] {
  const rows = stripHtmlToText(html)
    .split(/\n+/)
    .map((line) => normalizeWhitespace(line).trim())
    .filter((line) => line !== "");
  const candidates = rows.flatMap(parseFlatScheduleResultRow);
  return inferMissingResultStatuses(candidates, seatCount);
}

function parseFlatScheduleResultRow(line: string): ScheduleResultCandidate[] {
  const normalized = toAsciiDigits(line)
    .replace(/[,，]/g, "")
    .replace(/．/g, ".")
    .replace(/\s+/g, " ")
    .trim();
  const tokens = normalized.split(" ").filter((token) => token !== "");
  if (tokens.length < 4 || !/[0-9]/.test(tokens[tokens.length - 1] ?? "")) {
    return [];
  }
  const statusToken = normalizeScheduleResultStatus(tokens[0] ?? "");
  const startIndex = statusToken === "" ? 0 : 1;
  const ageIndex = tokens.findIndex((token, index) =>
    index >= startIndex && /^(?:-|－|\d{1,3})$/.test(token)
  );
  if (ageIndex <= startIndex || ageIndex + 2 >= tokens.length) {
    return [];
  }
  const name = normalizeMemberName(
    tokens.slice(startIndex, ageIndex).join(" "),
  );
  const party = tokens[ageIndex + 1] ?? "";
  const votes = parseVoteCount(tokens[tokens.length - 1] ?? "");
  if (name === "" || votes <= 0) {
    return [];
  }
  return [
    {
      name,
      party,
      statusLabel: statusToken,
      votes,
    },
  ];
}

function mergeScheduleResultCandidates(
  candidates: ScheduleResultCandidate[],
  seatCount: number,
): ScheduleResultCandidate[] {
  const merged = new Map<string, ScheduleResultCandidate>();
  for (const candidate of inferMissingResultStatuses(candidates, seatCount)) {
    const key = normalizeCandidateNameForKey(candidate.name);
    if (key === "") {
      continue;
    }
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, candidate);
      continue;
    }
    merged.set(key, {
      name: existing.name,
      party: existing.party !== "" ? existing.party : candidate.party,
      statusLabel: existing.statusLabel !== ""
        ? existing.statusLabel
        : candidate.statusLabel,
      votes: existing.votes > 0 ? existing.votes : candidate.votes,
    });
  }
  return [...merged.values()];
}

function inferMissingResultStatuses(
  candidates: ScheduleResultCandidate[],
  seatCount: number,
): ScheduleResultCandidate[] {
  if (
    seatCount <= 0 ||
    candidates.filter((item) => item.votes > 0).length <= seatCount
  ) {
    return candidates;
  }
  const rankedCandidates = [...candidates]
    .filter((candidate) => candidate.votes > 0)
    .sort((left, right) => right.votes - left.votes);
  const winningKeys = new Set(
    rankedCandidates
      .slice(0, seatCount)
      .map((candidate) => normalizeCandidateNameForKey(candidate.name)),
  );
  const runnerUpKey = normalizeCandidateNameForKey(
    rankedCandidates[seatCount]?.name ?? "",
  );

  return candidates.map((candidate) => {
    if (candidate.statusLabel !== "" || candidate.votes <= 0) {
      return candidate;
    }
    const key = normalizeCandidateNameForKey(candidate.name);
    if (key === runnerUpKey) {
      return {
        ...candidate,
        statusLabel: "次点",
      };
    }
    return {
      ...candidate,
      statusLabel: winningKeys.has(key) ? "当選" : "落選",
    };
  });
}

function extractGo2SenkyoCandidateName(raw: string): string {
  const value = normalizeWhitespace(raw).replace(/\s+/g, " ").trim();
  if (
    value === "" ||
    value.includes("選挙情報") ||
    value.includes("候補者") ||
    value.includes("掲載内容")
  ) {
    return "";
  }
  const kanaMatch = value.match(/^(.+?)\s+[ァ-ヴー・\s]+$/u);
  return normalizeMemberName(kanaMatch?.[1] ?? value);
}

function extractGo2SenkyoCandidateStatus(prefixHtml: string): string {
  const attrMatches = [
    ...prefixHtml.matchAll(
      /\b(?:alt|title)="([^"]*(?:当選|落選|次点|無投票)[^"]*)"/giu,
    ),
  ];
  if (attrMatches.length > 0) {
    return normalizeScheduleResultStatus(
      attrMatches[attrMatches.length - 1]?.[1] ?? "",
    );
  }
  const text = normalizeWhitespace(stripHtmlToText(prefixHtml));
  const textMatches = [...text.matchAll(/(当選|落選|次点|無投票)/gu)];
  if (textMatches.length === 0) {
    return "";
  }
  return normalizeScheduleResultStatus(
    textMatches[textMatches.length - 1]?.[1] ?? "",
  );
}

function extractGo2SenkyoCandidateVotes(bodyHtml: string): number {
  const text = normalizeWhitespace(stripHtmlToText(bodyHtml));
  const match = text.match(/([0-9０-９,，.．]+)\s*票/u);
  return match?.[1] ? parseVoteCount(match[1]) : 0;
}

function extractGo2SenkyoCandidateParty(bodyHtml: string): string {
  const lines = stripHtmlToText(bodyHtml)
    .split(/\n+/)
    .map((line) => normalizeWhitespace(line).trim())
    .filter((line) => line !== "");
  return lines.find((line) => /党|会|無所属/u.test(line)) ?? "";
}

function parseVoteCount(value: string): number {
  const normalized = toAsciiDigits(value)
    .replace(/[,\uff0c]/g, "")
    .replace(/\uff0e/g, ".")
    .trim();
  const parsed = Number.parseFloat(normalized);
  return Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : 0;
}

function normalizeScheduleResultStatus(value: string): string {
  const normalized = normalizeWhitespace(value);
  if (normalized === "当") {
    return "当選";
  }
  if (normalized === "落") {
    return "落選";
  }
  if (normalized === "次") {
    return "次点";
  }
  if (normalized.includes("無投票")) {
    return "無投票当選";
  }
  if (normalized.includes("当選")) {
    return "当選";
  }
  if (normalized.includes("次点")) {
    return "次点";
  }
  if (normalized.includes("落選") || normalized.includes("惜敗")) {
    return "落選";
  }
  return "";
}

function applyScheduleResultCandidateRows(
  candidateRows: ScheduleCandidateRow[],
  resultCandidates: ScheduleResultCandidate[],
): ScheduleCandidateRow[] {
  if (resultCandidates.length === 0) {
    return candidateRows;
  }
  return candidateRows.map((candidate) => {
    const result = findMatchingResultCandidate(
      candidate.name,
      resultCandidates,
    );
    if (!result) {
      return candidate;
    }
    return {
      ...candidate,
      name: result.name || candidate.name,
      statusLabel: result.statusLabel || candidate.statusLabel,
      votes: result.votes > 0 ? result.votes : candidate.votes,
    };
  });
}

function findMatchingResultCandidate(
  name: string,
  resultCandidates: ScheduleResultCandidate[],
): ScheduleResultCandidate | undefined {
  const targetKey = normalizeCandidateNameForKey(name);
  const exact = resultCandidates.find((candidate) =>
    normalizeCandidateNameForKey(candidate.name) === targetKey
  );
  if (exact) {
    return exact;
  }
  const contains = resultCandidates.find((candidate) => {
    const candidateKey = normalizeCandidateNameForKey(candidate.name);
    return candidateKey.includes(targetKey) || targetKey.includes(candidateKey);
  });
  if (contains) {
    return contains;
  }
  const targetSurname = candidateSurnameKey(name);
  if (targetSurname === "") {
    return undefined;
  }
  const surnameMatches = resultCandidates.filter((candidate) =>
    candidateSurnameKey(candidate.name) === targetSurname
  );
  return surnameMatches.length === 1 ? surnameMatches[0] : undefined;
}

function matchOfficialCandidatesForSchedule(
  prefecture: string,
  electionName: string,
  voteDate: string,
  officialCandidates: OfficialScheduledCandidate[],
): OfficialScheduledCandidate[] {
  const targetKey = scheduleMatchKey(prefecture, electionName, voteDate);
  const normalizedPrefecture = prefecture.trim();
  const byPrefecture = officialCandidates.filter((item) =>
    item.prefecture === normalizedPrefecture
  );
  const exact = byPrefecture.filter(
    (item) =>
      scheduleMatchKey(item.prefecture, item.electionName, item.voteDate) ===
        targetKey,
  );
  if (exact.length > 0) {
    return exact;
  }
  const normalizedElectionName = normalizeElectionNameForMatch(electionName);
  const sameName = byPrefecture.filter((item) =>
    normalizeElectionNameForMatch(item.electionName) === normalizedElectionName
  );
  if (sameName.length > 0) {
    return sameName;
  }
  return byPrefecture.filter((item) => {
    const candidateName = normalizeElectionNameForMatch(item.electionName);
    return candidateName.includes(normalizedElectionName) ||
      normalizedElectionName.includes(candidateName);
  });
}

async function buildAiAnalysis(snapshot: {
  baselineCurrentLocalMembers: number;
  officialCurrentLocalMembers: number;
  targetLocalMembers: number;
  baselineNetIncreaseRequired: number;
  actualNetIncreaseRequired: number;
  official2023FirstHalfWins: number;
  official2023SecondHalfWins: number;
  official2023TotalWins: number;
  prefectures: Array<
    {
      prefecture: string;
      sourceUrl: string;
      currentMembers: number;
      prefecturalAssemblyMembers: number;
      municipalAssemblyMembers: number;
      cdpLocalMembers: number;
      cdpSourceUrl: string;
    }
  >;
  members: LocalLegislatorProfile[];
  upcomingSchedules?: LocalElectionScheduleEntry[];
}): Promise<AiAnalysis> {
  if (OPENAI_API_KEY === "") {
    return buildFallbackAnalysis(snapshot);
  }
  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    AI_ANALYSIS_TIMEOUT_MS,
  );
  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.2,
        max_tokens: 500,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "You analyze a Japanese local election dashboard. Reply in concise Japanese. Return JSON with keys summary, alerts, strategicNotes, scheduleSummary, scheduleAlerts.",
          },
          {
            role: "user",
            content: JSON.stringify({
              officialCurrentLocalMembers: snapshot.officialCurrentLocalMembers,
              actualNetIncreaseRequired: snapshot.actualNetIncreaseRequired,
              official2023TotalWins: snapshot.official2023TotalWins,
              topPrefectures: [...snapshot.prefectures].sort((a, b) =>
                b.currentMembers - a.currentMembers
              ).slice(0, 10),
              topCdpGaps: [...snapshot.prefectures].sort((a, b) =>
                (b.cdpLocalMembers - b.currentMembers) -
                (a.cdpLocalMembers - a.currentMembers)
              ).slice(0, 10),
              rosterCount: snapshot.members.length,
              upcomingSchedules: snapshot.upcomingSchedules?.slice(0, 10) ?? [],
            }),
          },
        ],
      }),
    });
    if (!response.ok) {
      return buildFallbackAnalysis(snapshot);
    }
    const json = await response.json();
    const content = json.choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.trim() === "") {
      return buildFallbackAnalysis(snapshot);
    }
    const parsed = JSON.parse(content);
    const fallback = buildFallbackAnalysis(snapshot);
    const parsedScheduleAlerts = sanitizeLines(parsed.scheduleAlerts, 4);
    return {
      summary: sanitizeLine(parsed.summary) || fallback.summary,
      alerts: sanitizeLines(parsed.alerts, 3),
      strategicNotes: sanitizeLines(parsed.strategicNotes, 3),
      scheduleSummary: sanitizeLine(parsed.scheduleSummary) ||
        fallback.scheduleSummary,
      scheduleAlerts: parsedScheduleAlerts.length > 0
        ? parsedScheduleAlerts
        : fallback.scheduleAlerts,
    };
  } catch {
    return buildFallbackAnalysis(snapshot);
  } finally {
    clearTimeout(timeoutId);
  }
}

function buildFallbackAnalysis(snapshot: {
  baselineCurrentLocalMembers: number;
  officialCurrentLocalMembers: number;
  targetLocalMembers: number;
  baselineNetIncreaseRequired: number;
  actualNetIncreaseRequired: number;
  official2023FirstHalfWins: number;
  official2023SecondHalfWins: number;
  official2023TotalWins: number;
  prefectures: Array<
    {
      prefecture: string;
      sourceUrl: string;
      currentMembers: number;
      prefecturalAssemblyMembers: number;
      municipalAssemblyMembers: number;
      cdpLocalMembers: number;
      cdpSourceUrl: string;
    }
  >;
  members: LocalLegislatorProfile[];
  upcomingSchedules?: LocalElectionScheduleEntry[];
}): AiAnalysis {
  const scheduleEntries = snapshot.upcomingSchedules ?? [];
  const delta = snapshot.officialCurrentLocalMembers -
    snapshot.baselineCurrentLocalMembers;
  const deltaLabel = delta === 0
    ? "基準340と同水準。"
    : delta > 0
    ? `基準340比 +${delta}人。`
    : `基準340比 ${delta}人。`;
  const topPrefectures = [...snapshot.prefectures].sort((a, b) =>
    b.currentMembers - a.currentMembers
  ).slice(0, 3).map((item) => `${item.prefecture}${item.currentMembers}人`);
  const cdpBenchmarked = snapshot.prefectures.filter((item) =>
    item.cdpLocalMembers > 0
  );
  const topCdpGaps = cdpBenchmarked.sort((a, b) =>
    (b.cdpLocalMembers - b.currentMembers) -
    (a.cdpLocalMembers - a.currentMembers)
  ).slice(0, 3).map((item) => {
    const gap = item.cdpLocalMembers - item.currentMembers;
    return `${item.prefecture}${gap >= 0 ? "+" : ""}${gap}`;
  });
  const redSchedules = scheduleEntries.filter((item) =>
    item.kokuminCandidateCount === 0
  );
  const yellowSchedules = scheduleEntries.filter((item) =>
    item.kokuminCandidateCount === 1
  );
  const nearSchedules = scheduleEntries.slice(0, 3).map((item) =>
    `${item.voteDate} ${item.prefecture} ${item.electionName}（候補${item.kokuminCandidateCount}人）`
  );
  return {
    summary:
      `公式地方議員数 ${snapshot.officialCurrentLocalMembers}人。700まで残り ${snapshot.actualNetIncreaseRequired}人。${deltaLabel}`,
    alerts: [
      `2023年統一地方選の実績：前半 ${snapshot.official2023FirstHalfWins}、後半 ${snapshot.official2023SecondHalfWins}、合計 ${snapshot.official2023TotalWins}。`,
      `現職名簿の確定件数：${snapshot.members.length}人。`,
      topPrefectures.length === 0
        ? "上位都道府県のデータがありません。"
        : `上位都道府県：${topPrefectures.join(" / ")}。`,
      topCdpGaps.length === 0
        ? "立憲民主党との地方議員数の比較は今回取得していません。"
        : `立憲民主党との地力差（上位）：${topCdpGaps.join(" / ")}。`,
    ],
    strategicNotes: [
      "現職の維持、新人の擁立、重点自治体の管理を一つの月次計画で進める。",
      "候補者0件の選挙は赤、1件のみの選挙は黄として優先的に対応する。",
      "公開名簿・都道府県別集計・選挙日程を一つの運用ビューで共有する。",
    ],
    scheduleSummary: scheduleEntries.length === 0
      ? "直近の地方選日程は見つかりませんでした。"
      : `予定されている地方選：${scheduleEntries.length}件。赤 ${redSchedules.length}件、黄 ${yellowSchedules.length}件。`,
    scheduleAlerts: [
      ...(redSchedules.length > 0
        ? [
          `赤 ${redSchedules.length}件：${
            redSchedules.slice(0, 3).map((item) =>
              `${item.prefecture} ${item.electionName}`
            ).join(" / ")
          }`,
        ]
        : []),
      ...(yellowSchedules.length > 0
        ? [
          `黄 ${yellowSchedules.length}件：${
            yellowSchedules.slice(0, 3).map((item) =>
              `${item.prefecture} ${item.electionName}`
            ).join(" / ")
          }`,
        ]
        : []),
      ...(nearSchedules.length > 0
        ? [`直近：${nearSchedules.join(" / ")}`]
        : []),
    ],
  };
}

function compareMembers(
  left: LocalLegislatorProfile,
  right: LocalLegislatorProfile,
): number {
  const prefectureCompare = left.prefecture.localeCompare(
    right.prefecture,
    "ja",
  );
  if (prefectureCompare !== 0) {
    return prefectureCompare;
  }
  const rank = (value: AssemblyCategory) =>
    value === "prefectural" ? 0 : value === "municipal" ? 1 : 2;
  const assemblyCompare = rank(left.assemblyCategory) -
    rank(right.assemblyCategory);
  if (assemblyCompare !== 0) {
    return assemblyCompare;
  }
  return left.name.localeCompare(right.name, "ja");
}

function matchMemberListSections(
  html: string,
): Array<{ heading: string; listHtml: string }> {
  const sections: Array<{ heading: string; listHtml: string }> = [];
  const sectionRegex =
    /<h2[^>]*class="[^"]*\bmember_sec_ttl\b[^"]*"[^>]*>([\s\S]*?)<\/h2>\s*<ul[^>]*class="[^"]*\bmember_list\b[^"]*"[^>]*>([\s\S]*?)<\/ul>/gsi;
  for (const match of html.matchAll(sectionRegex)) {
    sections.push({
      heading: normalizeWhitespace(decodeHtml(stripTags(match[1] ?? "")))
        .trim(),
      listHtml: match[2] ?? "",
    });
  }
  return sections;
}

function extractListItems(listHtml: string): string[] {
  const items: string[] = [];
  const itemRegex = /<li\b[^>]*>([\s\S]*?)<\/li>/gsi;
  for (const match of listHtml.matchAll(itemRegex)) {
    items.push(match[1] ?? "");
  }
  return items;
}

function parseMemberCard(
  cardHtml: string,
  baseUrl: string,
): {
  name: string;
  kana: string;
  constituency: string;
  assemblyLabel: string;
  electionCountLabel: string;
  detailUrl: string;
} {
  const nameLinkMatch = cardHtml.match(
    /<dt[^>]*class="[^"]*\bname\b[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/i,
  );
  return {
    name: normalizeMemberName(decodeHtml(stripTags(nameLinkMatch?.[2] ?? ""))),
    kana: extractClassText(cardHtml, "kana"),
    constituency: extractClassText(cardHtml, "kind"),
    assemblyLabel: extractClassText(cardHtml, "area") ||
      extractClassText(cardHtml, "category"),
    electionCountLabel: extractClassText(cardHtml, "times"),
    detailUrl: nameLinkMatch?.[1]
      ? new URL(nameLinkMatch[1], baseUrl).toString()
      : "",
  };
}

function extractClassText(html: string, className: string): string {
  const pattern = new RegExp(
    `<[^>]+class="[^"]*\\b${
      escapeRegExp(className)
    }\\b[^"]*"[^>]*>([\\s\\S]*?)<\\/[^>]+>`,
    "i",
  );
  return normalizeWhitespace(
    decodeHtml(stripTags(html.match(pattern)?.[1] ?? "")),
  ).trim();
}

function inferAssemblyCategory(assemblyLabel: string): AssemblyCategory {
  if (
    /(\u90fd|\u9053|\u5e9c|\u770c)\u8b70\u4f1a\u8b70\u54e1/u.test(assemblyLabel)
  ) {
    return "prefectural";
  }
  if (
    /(\u5e02|\u533a|\u753a|\u6751)\u8b70\u4f1a\u8b70\u54e1/u.test(assemblyLabel)
  ) {
    return "municipal";
  }
  return "other";
}

function extractMunicipality(prefecture: string, constituency: string): string {
  const normalizedPrefecture = prefecture.trim();
  const normalizedConstituency = constituency.trim();
  if (normalizedConstituency === "") {
    return normalizedPrefecture;
  }
  if (
    normalizedPrefecture !== "" &&
    normalizedConstituency.startsWith(normalizedPrefecture)
  ) {
    const sliced = normalizedConstituency.slice(normalizedPrefecture.length)
      .trim();
    return sliced === "" ? normalizedPrefecture : sliced;
  }
  return normalizedConstituency;
}

function inferPrefectureFromConstituency(constituency: string): string {
  const normalized = constituency.trim();
  for (const prefecture of PREFECTURES) {
    if (normalized.startsWith(prefecture) || normalized.includes(prefecture)) {
      return prefecture;
    }
  }
  return "";
}

function parseSimpleTable(html: string): Map<string, string> {
  const fields = new Map<string, string>();
  const rowRegex =
    /<tr[^>]*>\s*<th[^>]*>([\s\S]*?)<\/th>\s*<td[^>]*>([\s\S]*?)<\/td>\s*<\/tr>/gsi;
  for (const match of html.matchAll(rowRegex)) {
    const key = normalizeWhitespace(decodeHtml(stripTags(match[1] ?? "")))
      .trim();
    const value = normalizeWhitespace(decodeHtml(stripTags(match[2] ?? "")))
      .trim();
    if (key !== "" && value !== "" && !fields.has(key)) {
      fields.set(key, value);
    }
  }
  return fields;
}

function normalizeOfficialVoteDate(value: string): string {
  return extractIsoDate(value);
}
function normalizeJapaneseDate(value: string): string {
  return extractIsoDate(value);
}
function normalizeSlashedDate(value: string): string {
  return extractIsoDate(value);
}
function normalizeBirthDate(value: string): string {
  const iso = extractIsoDate(value);
  return iso === ""
    ? normalizeWhitespace(value).trim()
    : iso.replace(/-/g, "/");
}

function calculateAge(birthDate: string): number | null {
  if (!/^\d{4}\/\d{2}\/\d{2}$/.test(birthDate)) return null;
  const [year, month, day] = birthDate.split("/").map((item) =>
    Number.parseInt(item, 10)
  );
  const today = new Date();
  let age = today.getFullYear() - year;
  const passed = today.getMonth() + 1 > month ||
    (today.getMonth() + 1 === month && today.getDate() >= day);
  if (!passed) age -= 1;
  return age >= 0 ? age : null;
}

function extractIsoDate(value: string): string {
  const normalized = toAsciiDigits(value).replace(/\./g, "/").replace(
    /\u5e74/g,
    "/",
  ).replace(/\u6708/g, "/").replace(/\u65e5/g, "").replace(/\s+/g, "").trim();
  if (normalized === "" || normalized === JP_UNDECIDED) return "";
  const match = normalized.match(/(20\d{2})[\/-](\d{1,2})[\/-](\d{1,2})/);
  if (!match) return normalized.replace(/\//g, "-");
  return `${match[1]}-${match[2].padStart(2, "0")}-${
    match[3].padStart(2, "0")
  }`;
}

function parseIsoDate(value: string): Date | null {
  const normalized = normalizeSlashedDate(value);
  if (normalized === "") return null;
  const parsed = new Date(`${normalized}T00:00:00+09:00`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function startOfDay(value: Date): Date {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}
function addDays(value: Date, days: number): Date {
  const next = new Date(value.getTime());
  next.setDate(next.getDate() + days);
  return next;
}
function isPrefectureName(value: string): boolean {
  return PREFECTURES.includes(value as (typeof PREFECTURES)[number]);
}
function extractPrefectureLabel(value: string): string {
  const normalized = normalizeWhitespace(value).trim();
  for (const prefecture of PREFECTURES) {
    if (normalized.includes(prefecture)) return prefecture;
  }
  return normalized;
}

function extractScheduleMunicipality(
  electionName: string,
  prefecture: string,
): string {
  const patterns = [
    /^(.*?)(?:\u90fd|\u9053|\u5e9c|\u770c)\u77e5\u4e8b\u9078\u6319$/,
    /^(.*?)(?:\u90fd|\u9053|\u5e9c|\u770c)\u8b70\u4f1a\u8b70\u54e1\u9078\u6319$/,
    /^(.*?)\u5e02\u9577\u9078\u6319$/,
    /^(.*?)\u5e02\u8b70\u4f1a\u8b70\u54e1\u9078\u6319$/,
    /^(.*?)\u533a\u9577\u9078\u6319$/,
    /^(.*?)\u533a\u8b70\u4f1a\u8b70\u54e1\u9078\u6319$/,
    /^(.*?)\u753a\u9577\u9078\u6319$/,
    /^(.*?)\u753a\u8b70\u4f1a\u8b70\u54e1\u9078\u6319$/,
    /^(.*?)\u6751\u9577\u9078\u6319$/,
    /^(.*?)\u6751\u8b70\u4f1a\u8b70\u54e1\u9078\u6319$/,
  ];
  for (const pattern of patterns) {
    const match = electionName.match(pattern);
    if (match) {
      const municipality = match[1]?.trim() ?? "";
      return municipality === "" ? prefecture : municipality;
    }
  }
  return prefecture;
}

function inferElectionCategory(electionName: string): string {
  if (
    /(\u77e5\u4e8b|\u5e02\u9577|\u533a\u9577|\u753a\u9577|\u6751\u9577)\u9078\u6319/u
      .test(electionName)
  ) return "chief";
  if (
    /(?:\u90fd|\u9053|\u5e9c|\u770c|\u5e02|\u533a|\u753a|\u6751)\u8b70\u4f1a\u8b70\u54e1(?:\u88dc\u6b20|\u518d)?\u9078\u6319/u
      .test(electionName) ||
    /\u8b70\u4f1a\u8b70\u54e1(?:\u88dc\u6b20|\u518d)?\u9078\u6319/u.test(
      electionName,
    )
  ) {
    return "assembly";
  }
  return "other";
}

function normalizeElectionNameForMatch(value: string): string {
  return normalizeWhitespace(value)
    .replace(/[ \u3000]/g, "")
    .replace(/[\u30fb\uff65]/g, "")
    .replace(/[()\uff08\uff09\u300c\u300d\u300e\u300f]/g, "")
    .replace(/\u6295\u958b\u7968/g, "")
    .replace(/\u63a8\u85a6/g, "")
    .replace(/\u8b70\u4f1a\u8b70\u54e1/g, "\u8b70")
    .replace(/\u88dc\u9078/g, "\u88dc\u6b20")
    .replace(/\u9078\u6319/g, "")
    .replace(/\u9078/g, "")
    .replace(/(\u88dc\u6b20)+/g, "\u88dc\u6b20")
    .trim();
}

function scheduleSeverity(entry: LocalElectionScheduleEntry): number {
  if (entry.kokuminCandidateCount === 0) return 0;
  if (entry.kokuminCandidateCount === 1) return 1;
  return 2;
}

function normalizeMemberName(value: string): string {
  return normalizeWhitespace(value).trim();
}
function normalizeCandidateNameForKey(value: string): string {
  return normalizeMemberName(value).replace(/[ \u3000]/g, "");
}
function candidateSurnameKey(value: string): string {
  const normalized = normalizeMemberName(value);
  const firstToken = normalized.split(/[ \u3000]+/)[0] ?? "";
  const key = normalizeCandidateNameForKey(firstToken);
  return key.length >= 2 ? key.slice(0, 2) : "";
}
function normalizeXHandle(value: string | undefined): string {
  return typeof value === "string" ? value.trim().replace(/^@+/, "") : "";
}
function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}
function scheduleMatchKey(
  prefecture: string,
  electionName: string,
  voteDate: string,
): string {
  return `${prefecture.trim()}::${normalizeSlashedDate(voteDate)}::${
    normalizeElectionNameForMatch(electionName)
  }`;
}
function scheduledCandidateKey(candidate: OfficialScheduledCandidate): string {
  return `${
    scheduleMatchKey(
      candidate.prefecture,
      candidate.electionName,
      candidate.voteDate,
    )
  }::${normalizeCandidateNameForKey(candidate.name)}`;
}
function extractCount(text: string, pattern: RegExp): number | null {
  const match = text.match(pattern);
  return !match || match.length < 2 ? null : toInt(match[1]);
}
function toInt(value: string): number {
  const normalized = toAsciiDigits(value).replace(/[^0-9]/g, "");
  return normalized === "" ? 0 : Number.parseInt(normalized, 10);
}
function toAsciiDigits(value: string): string {
  return value.replace(
    /[\uff10-\uff19]/g,
    (digit) => String.fromCharCode(digit.charCodeAt(0) - 0xfee0),
  );
}
function stripTags(value: string): string {
  return value.replace(/<[^>]+>/g, " ");
}

function stripHtmlToText(html: string): string {
  return decodeHtml(
    html.replace(/<script[\s\S]*?<\/script>/gi, " ").replace(
      /<style[\s\S]*?<\/style>/gi,
      " ",
    ).replace(/<noscript[\s\S]*?<\/noscript>/gi, " ").replace(/<[^>]+>/g, "\n"),
  );
}

function decodeHtml(value: string): string {
  return value.replace(/&nbsp;/g, " ").replace(/&#038;/g, "&").replace(
    /&amp;/g,
    "&",
  ).replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/&ensp;/g, " ").replace(/&emsp;/g, " ")
    .replace(/&#x2f;/gi, "/");
}

function normalizeWhitespace(value: string): string {
  return value.replace(/\r/g, "\n").replace(/[ \t\u3000]+/g, " ").replace(
    /\n{2,}/g,
    "\n",
  ).trim();
}
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
function isLocalElectionName(value: string): boolean {
  return /\u9078\u6319/u.test(value) &&
    !/(\u8846\u8b70\u9662|\u53c2\u8b70\u9662|\u6bd4\u4f8b|\u653f\u515a|\u4ee3\u8868\u9078|\u515a\u5927\u4f1a)/u
      .test(value);
}
function sanitizeLine(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
function sanitizeLines(value: unknown, limit: number): string[] {
  return !Array.isArray(value)
    ? []
    : value.map((item) => sanitizeLine(item)).filter((item) => item.length > 0)
      .slice(0, limit);
}

async function mapWithConcurrency<T, U>(
  items: T[],
  limit: number,
  mapper: (item: T) => Promise<U>,
): Promise<U[]> {
  const results = new Array<U>(items.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < items.length) {
      const current = nextIndex;
      nextIndex += 1;
      results[current] = await mapper(items[current]);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, () => worker()),
  );
  return results;
}
