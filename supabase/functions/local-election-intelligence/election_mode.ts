export const ELECTION_MODE_IDS = [
  "local",
  "house_of_representatives",
  "house_of_councillors",
] as const;

export type ElectionModeId = typeof ELECTION_MODE_IDS[number];
export type ElectionModeAvailability = "active" | "registered";
export type GoalVerificationStatus =
  | "verified"
  | "source_unverified"
  | "awaiting_official_target";

export interface ElectionGoalDefinition {
  id: string;
  title: string;
  metric: string;
  targetValue: number | null;
  unit: string;
  deadlineLabel: string;
  sourceUrl: string;
  sourcePublishedAt: string;
  verificationTerms: string[];
}

export interface ElectionAchievementDefinition {
  id: string;
  title: string;
  metric: string;
  unit: string;
  periodLabel: string;
  sourceUrls: string[];
}

export interface ElectionModeDefinition {
  id: ElectionModeId;
  label: string;
  shortLabel: string;
  availability: ElectionModeAvailability;
  description: string;
  collectors: string[];
  goals: ElectionGoalDefinition[];
  achievements: ElectionAchievementDefinition[];
}

export interface ElectionModeRegistry {
  schemaVersion: number;
  defaultMode: ElectionModeId;
  modes: ElectionModeDefinition[];
}

export interface ElectionModeSnapshot {
  id: ElectionModeId;
  label: string;
  shortLabel: string;
  availability: ElectionModeAvailability;
  description: string;
  collectors: string[];
}

export interface ElectionGoalSnapshot {
  id: string;
  mode: ElectionModeId;
  title: string;
  metric: string;
  currentValue: number | null;
  targetValue: number | null;
  unit: string;
  deadlineLabel: string;
  sourceUrl: string;
  sourcePublishedAt: string;
  verificationStatus: GoalVerificationStatus;
}

export interface ElectionAchievementSnapshot {
  id: string;
  mode: ElectionModeId;
  title: string;
  metric: string;
  value: number | null;
  unit: string;
  periodLabel: string;
  sourceUrls: string[];
}

export interface OfficialEndorsementPrefectureSnapshot {
  prefecture: string;
  totalCount: number;
  incumbentCount: number;
  newcomerCount: number;
  formerCount: number;
}

export interface OfficialEndorsementSnapshot {
  sourceUrl: string;
  sourceAsOf: string;
  sourceDocumentSha256: string;
  totalCount: number;
  incumbentCount: number;
  newcomerCount: number;
  formerCount: number;
  recommendationCount: number;
  prefectureCount: number;
  prefectures: OfficialEndorsementPrefectureSnapshot[];
}

export interface ElectionIntelligenceSnapshot {
  schemaVersion: number;
  selectedMode: ElectionModeId;
  modes: ElectionModeSnapshot[];
  goals: ElectionGoalSnapshot[];
  achievements: ElectionAchievementSnapshot[];
  officialEndorsements: OfficialEndorsementSnapshot;
}

export interface GoalSourceVerification {
  verifiedGoalIds: string[];
  issues: string[];
}

type JsonRecord = Record<string, unknown>;

function asRecord(value: unknown): JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function asUrl(value: unknown): string {
  const valueString = asString(value);
  return /^https:\/\//i.test(valueString) ? valueString : "";
}

function asNumber(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function asNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.map(asString).filter((item) => item !== "")
    : [];
}

function isElectionModeId(value: string): value is ElectionModeId {
  return (ELECTION_MODE_IDS as readonly string[]).includes(value);
}

export function parseElectionMode(value: unknown): ElectionModeId {
  const normalized = asString(value);
  return isElectionModeId(normalized) ? normalized : "local";
}

function parseAvailability(value: unknown): ElectionModeAvailability {
  return value === "active" ? "active" : "registered";
}

function compareById<T extends { id: string }>(left: T, right: T): number {
  return left.id.localeCompare(right.id);
}

export function normalizeElectionModeRegistry(
  value: unknown,
): ElectionModeRegistry {
  const raw = asRecord(value);
  const rawModes = Array.isArray(raw.modes) ? raw.modes : [];
  const modes = rawModes.flatMap((item): ElectionModeDefinition[] => {
    const row = asRecord(item);
    const id = asString(row.id);
    if (!isElectionModeId(id)) return [];
    const goals = (Array.isArray(row.goals) ? row.goals : []).map((goal) => {
      const goalRow = asRecord(goal);
      return {
        id: asString(goalRow.id),
        title: asString(goalRow.title),
        metric: asString(goalRow.metric),
        targetValue: asNullableNumber(goalRow.targetValue),
        unit: asString(goalRow.unit),
        deadlineLabel: asString(goalRow.deadlineLabel),
        sourceUrl: asUrl(goalRow.sourceUrl),
        sourcePublishedAt: asString(goalRow.sourcePublishedAt),
        verificationTerms: asStringArray(goalRow.verificationTerms),
      };
    }).filter((goal) => goal.id !== "").sort(compareById);
    const achievements = (
      Array.isArray(row.achievements) ? row.achievements : []
    ).map((achievement) => {
      const achievementRow = asRecord(achievement);
      return {
        id: asString(achievementRow.id),
        title: asString(achievementRow.title),
        metric: asString(achievementRow.metric),
        unit: asString(achievementRow.unit),
        periodLabel: asString(achievementRow.periodLabel),
        sourceUrls: asStringArray(achievementRow.sourceUrls).map(asUrl).filter(
          (url) => url !== "",
        ).sort(),
      };
    }).filter((achievement) => achievement.id !== "").sort(compareById);
    return [{
      id,
      label: asString(row.label),
      shortLabel: asString(row.shortLabel),
      availability: parseAvailability(row.availability),
      description: asString(row.description),
      collectors: asStringArray(row.collectors).sort(),
      goals,
      achievements,
    }];
  });

  const modeIds = new Set(modes.map((mode) => mode.id));
  const missingModes = ELECTION_MODE_IDS.filter((id) => !modeIds.has(id));
  if (missingModes.length > 0) {
    throw new Error(
      `election mode registry missing: ${missingModes.join(",")}`,
    );
  }
  if (modes.filter((mode) => mode.availability === "active").length === 0) {
    throw new Error("election mode registry has no active mode");
  }
  const defaultMode = parseElectionMode(raw.defaultMode);
  if (!modeIds.has(defaultMode)) {
    throw new Error(
      `election mode registry default is missing: ${defaultMode}`,
    );
  }
  return {
    schemaVersion: Math.max(1, asNumber(raw.schemaVersion)),
    defaultMode,
    modes: ELECTION_MODE_IDS.map((id) => modes.find((mode) => mode.id === id)!),
  };
}

export async function verifyElectionGoalSources(
  registry: ElectionModeRegistry,
  fetchSourceText: (url: string) => Promise<string>,
): Promise<GoalSourceVerification> {
  const goals = registry.modes.flatMap((mode) => mode.goals);
  const results = await Promise.all(goals.map(async (goal) => {
    if (!goal.sourceUrl || goal.verificationTerms.length === 0) {
      return {
        id: goal.id,
        verified: false,
        issue: `goal_source_contract_incomplete:${goal.id}`,
      };
    }
    try {
      const text = (await fetchSourceText(goal.sourceUrl))
        .replace(/<[^>]+>/g, " ").replace(/\s+/g, " ");
      const missingTerms = goal.verificationTerms.filter((term) =>
        !text.includes(term)
      );
      return missingTerms.length === 0
        ? { id: goal.id, verified: true, issue: "" }
        : {
          id: goal.id,
          verified: false,
          issue: `goal_source_terms_missing:${goal.id}:${
            missingTerms.join(",")
          }`,
        };
    } catch (_error) {
      return {
        id: goal.id,
        verified: false,
        issue: `goal_source_fetch_failed:${goal.id}`,
      };
    }
  }));
  return {
    verifiedGoalIds: results.filter((result) => result.verified).map((result) =>
      result.id
    ).sort(),
    issues: results.map((result) => result.issue).filter((issue) =>
      issue !== ""
    )
      .sort(),
  };
}

export function normalizeOfficialEndorsementSnapshot(
  value: unknown,
): OfficialEndorsementSnapshot {
  const raw = asRecord(value);
  const summary = asRecord(raw.officialEndorsements);
  const recommendations = asRecord(raw.recommendations);
  const prefectures = (Array.isArray(raw.prefectures) ? raw.prefectures : [])
    .map((item): OfficialEndorsementPrefectureSnapshot => {
      const row = asRecord(item);
      return {
        prefecture: asString(row.prefecture),
        totalCount: asNumber(row.totalCount),
        incumbentCount: asNumber(row.incumbentCount),
        newcomerCount: asNumber(row.newcomerCount),
        formerCount: asNumber(row.formerCount),
      };
    }).filter((row) => row.prefecture !== "")
    .sort((left, right) =>
      left.prefecture.localeCompare(right.prefecture, "ja")
    );
  const snapshot: OfficialEndorsementSnapshot = {
    sourceUrl: asUrl(raw.sourceUrl),
    sourceAsOf: asString(raw.sourceAsOf),
    sourceDocumentSha256: asString(raw.sourceDocumentSha256),
    totalCount: asNumber(summary.totalCount),
    incumbentCount: asNumber(summary.incumbentCount),
    newcomerCount: asNumber(summary.newcomerCount),
    formerCount: asNumber(summary.formerCount),
    recommendationCount: asNumber(recommendations.totalCount),
    prefectureCount: asNumber(summary.prefectureCount),
    prefectures,
  };
  const breakdown = snapshot.incumbentCount + snapshot.newcomerCount +
    snapshot.formerCount;
  if (
    !snapshot.sourceUrl || !/^\d{4}-\d{2}-\d{2}$/.test(snapshot.sourceAsOf) ||
    !/^[a-f0-9]{64}$/i.test(snapshot.sourceDocumentSha256) ||
    snapshot.totalCount < 30 || breakdown !== snapshot.totalCount ||
    snapshot.prefectureCount !== snapshot.prefectures.length
  ) {
    throw new Error("official endorsement snapshot failed validation");
  }
  for (const row of snapshot.prefectures) {
    if (
      row.totalCount !== row.incumbentCount + row.newcomerCount +
          row.formerCount
    ) {
      throw new Error(
        `official endorsement prefecture breakdown invalid: ${row.prefecture}`,
      );
    }
  }
  return snapshot;
}

export function emptyOfficialEndorsementSnapshot(): OfficialEndorsementSnapshot {
  return {
    sourceUrl: "",
    sourceAsOf: "",
    sourceDocumentSha256: "",
    totalCount: 0,
    incumbentCount: 0,
    newcomerCount: 0,
    formerCount: 0,
    recommendationCount: 0,
    prefectureCount: 0,
    prefectures: [],
  };
}

export function fallbackElectionModeRegistry(): ElectionModeRegistry {
  return normalizeElectionModeRegistry({
    schemaVersion: 1,
    defaultMode: "local",
    modes: [
      {
        id: "local",
        label: "地方選",
        shortLabel: "地方",
        availability: "active",
        description: "地方議員数、公認予定候補、地方選実績を追跡します。",
        collectors: [
          "local_members",
          "official_endorsements",
          "local_results",
        ],
        goals: [{
          id: "local_members_700",
          title: "地方議員700人",
          metric: "local_member_count",
          targetValue: 700,
          unit: "人",
          deadlineLabel: "次期統一地方選終了時",
          sourceUrl: "https://new-kokumin.jp/news/business/20260714_1",
          sourcePublishedAt: "2026-07-14",
          verificationTerms: ["地方自治体議員", "700"],
        }],
        achievements: [{
          id: "unified_local_election_wins_2023",
          title: "2023年統一地方選 当選者",
          metric: "unified_local_election_wins_2023",
          unit: "人",
          periodLabel: "2023年統一地方選",
          sourceUrls: [
            "https://new-kokumin.jp/news/election/20230410_election",
            "https://new-kokumin.jp/news/election/20230423_1",
          ],
        }],
      },
      {
        id: "house_of_representatives",
        label: "衆院選",
        shortLabel: "衆院",
        availability: "registered",
        description: "公式目標と候補者ソースの確定後に有効化します。",
        collectors: [],
        goals: [],
        achievements: [],
      },
      {
        id: "house_of_councillors",
        label: "参院選",
        shortLabel: "参院",
        availability: "registered",
        description: "公式目標と候補者ソースの確定後に有効化します。",
        collectors: [],
        goals: [],
        achievements: [],
      },
    ],
  });
}

export function fallbackOfficialEndorsementSnapshot(): OfficialEndorsementSnapshot {
  return {
    sourceUrl: "https://new-kokumin.jp/local-election-list",
    sourceAsOf: "2026-08-12",
    sourceDocumentSha256: "",
    totalCount: 218,
    incumbentCount: 102,
    newcomerCount: 107,
    formerCount: 9,
    recommendationCount: 9,
    prefectureCount: 33,
    prefectures: [],
  };
}

export function buildElectionIntelligenceSnapshot(options: {
  registry: ElectionModeRegistry;
  selectedMode: ElectionModeId;
  verifiedGoalIds: string[];
  officialEndorsements: OfficialEndorsementSnapshot;
  officialCurrentLocalMembers: number;
  official2023TotalWins: number;
}): ElectionIntelligenceSnapshot {
  const selected = options.registry.modes.find((mode) =>
    mode.id === options.selectedMode
  );
  if (!selected) {
    throw new Error(`unsupported election mode: ${options.selectedMode}`);
  }
  if (selected.availability !== "active") {
    throw new Error(
      `election mode is registered but not active: ${selected.id}`,
    );
  }
  const verified = new Set(options.verifiedGoalIds);
  const metricValue = (metric: string): number | null => {
    if (metric === "local_member_count") {
      return options.officialCurrentLocalMembers;
    }
    if (metric === "unified_local_election_wins_2023") {
      return options.official2023TotalWins;
    }
    return null;
  };
  return {
    schemaVersion: options.registry.schemaVersion,
    selectedMode: selected.id,
    modes: options.registry.modes.map((mode) => ({
      id: mode.id,
      label: mode.label,
      shortLabel: mode.shortLabel,
      availability: mode.availability,
      description: mode.description,
      collectors: [...mode.collectors].sort(),
    })),
    goals: selected.goals.map((goal): ElectionGoalSnapshot => ({
      id: goal.id,
      mode: selected.id,
      title: goal.title,
      metric: goal.metric,
      currentValue: metricValue(goal.metric),
      targetValue: goal.targetValue,
      unit: goal.unit,
      deadlineLabel: goal.deadlineLabel,
      sourceUrl: goal.sourceUrl,
      sourcePublishedAt: goal.sourcePublishedAt,
      verificationStatus: goal.targetValue === null
        ? "awaiting_official_target"
        : verified.has(goal.id)
        ? "verified"
        : "source_unverified",
    })).sort(compareById),
    achievements: selected.achievements.map((achievement) => ({
      id: achievement.id,
      mode: selected.id,
      title: achievement.title,
      metric: achievement.metric,
      value: metricValue(achievement.metric),
      unit: achievement.unit,
      periodLabel: achievement.periodLabel,
      sourceUrls: [...achievement.sourceUrls].sort(),
    })).sort(compareById),
    officialEndorsements: selected.id === "local"
      ? options.officialEndorsements
      : emptyOfficialEndorsementSnapshot(),
  };
}

export function canonicalizeElectionIntelligenceSnapshot(
  value: unknown,
): ElectionIntelligenceSnapshot {
  const raw = asRecord(value);
  const selectedMode = parseElectionMode(raw.selectedMode);
  const modes = (Array.isArray(raw.modes) ? raw.modes : []).flatMap(
    (item): ElectionModeSnapshot[] => {
      const row = asRecord(item);
      const id = asString(row.id);
      if (!isElectionModeId(id)) return [];
      return [{
        id,
        label: asString(row.label),
        shortLabel: asString(row.shortLabel),
        availability: parseAvailability(row.availability),
        description: asString(row.description),
        collectors: asStringArray(row.collectors).sort(),
      }];
    },
  ).sort(compareById);
  const goals = (Array.isArray(raw.goals) ? raw.goals : []).flatMap(
    (item): ElectionGoalSnapshot[] => {
      const row = asRecord(item);
      const mode = parseElectionMode(row.mode);
      const status = asString(row.verificationStatus);
      const verificationStatus: GoalVerificationStatus =
        status === "verified" || status === "awaiting_official_target"
          ? status
          : "source_unverified";
      const id = asString(row.id);
      return id === "" ? [] : [{
        id,
        mode,
        title: asString(row.title),
        metric: asString(row.metric),
        currentValue: asNullableNumber(row.currentValue),
        targetValue: asNullableNumber(row.targetValue),
        unit: asString(row.unit),
        deadlineLabel: asString(row.deadlineLabel),
        sourceUrl: asUrl(row.sourceUrl),
        sourcePublishedAt: asString(row.sourcePublishedAt),
        verificationStatus,
      }];
    },
  ).sort(compareById);
  const achievements = (
    Array.isArray(raw.achievements) ? raw.achievements : []
  ).flatMap((item): ElectionAchievementSnapshot[] => {
    const row = asRecord(item);
    const id = asString(row.id);
    return id === "" ? [] : [{
      id,
      mode: parseElectionMode(row.mode),
      title: asString(row.title),
      metric: asString(row.metric),
      value: asNullableNumber(row.value),
      unit: asString(row.unit),
      periodLabel: asString(row.periodLabel),
      sourceUrls: asStringArray(row.sourceUrls).map(asUrl).filter(Boolean)
        .sort(),
    }];
  }).sort(compareById);
  let officialEndorsements = emptyOfficialEndorsementSnapshot();
  const rawEndorsements = asRecord(raw.officialEndorsements);
  if (Object.keys(rawEndorsements).length > 0) {
    const prefectures = (
      Array.isArray(rawEndorsements.prefectures)
        ? rawEndorsements.prefectures
        : []
    ).map((item): OfficialEndorsementPrefectureSnapshot => {
      const row = asRecord(item);
      return {
        prefecture: asString(row.prefecture),
        totalCount: asNumber(row.totalCount),
        incumbentCount: asNumber(row.incumbentCount),
        newcomerCount: asNumber(row.newcomerCount),
        formerCount: asNumber(row.formerCount),
      };
    }).filter((row) => row.prefecture !== "").sort((left, right) =>
      left.prefecture.localeCompare(right.prefecture, "ja")
    );
    officialEndorsements = {
      sourceUrl: asUrl(rawEndorsements.sourceUrl),
      sourceAsOf: asString(rawEndorsements.sourceAsOf),
      sourceDocumentSha256: asString(rawEndorsements.sourceDocumentSha256),
      totalCount: asNumber(rawEndorsements.totalCount),
      incumbentCount: asNumber(rawEndorsements.incumbentCount),
      newcomerCount: asNumber(rawEndorsements.newcomerCount),
      formerCount: asNumber(rawEndorsements.formerCount),
      recommendationCount: asNumber(rawEndorsements.recommendationCount),
      prefectureCount: asNumber(rawEndorsements.prefectureCount),
      prefectures,
    };
  }
  return {
    schemaVersion: Math.max(1, asNumber(raw.schemaVersion)),
    selectedMode,
    modes,
    goals,
    achievements,
    officialEndorsements,
  };
}
