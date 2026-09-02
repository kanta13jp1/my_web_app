import {
  buildXPostCandidateMetadata,
  X_POST_CANDIDATE_SOURCE,
} from "../growth-hub/x_post_candidate.ts";
import { buildPartyGapCandidateMetadata } from "./party_gap_ranking.ts";
import {
  canonicalizeElectionIntelligenceSnapshot,
  type ElectionAchievementSnapshot,
  type ElectionGoalSnapshot,
  type ElectionIntelligenceSnapshot,
  type OfficialEndorsementSnapshot,
} from "./election_mode.ts";

export const LOCAL_ELECTION_DATASET = "kokumin_local_election_intelligence";
export const LOCAL_ELECTION_DATASET_SOURCE = "local-election-intelligence";
export const LOCAL_ELECTION_SNAPSHOT_HUB_SOURCE =
  "local_election_dataset_snapshot";
export const X_POST_CANDIDATE_HUB_SOURCE = X_POST_CANDIDATE_SOURCE;
export const LOCAL_ELECTION_SNAPSHOT_SCHEMA_VERSION = 2;

export type JsonRecord = Record<string, unknown>;

export interface ScheduleSourceFetchHealth {
  url: string;
  requiredForPersistence: boolean;
  fetchSucceeded: boolean;
  parsedEntryCount: number;
}

export interface ScheduleCollectionQuality {
  sourceCount: number;
  fetchSuccessCount: number;
  parsedSourceCount: number;
  parsedEntryCount: number;
  manualEntryCount: number;
  manualFallbackOnly: boolean;
  failedSourceUrls: string[];
  parserEmptySourceUrls: string[];
  failedRequiredSourceUrls: string[];
  parserEmptyRequiredSourceUrls: string[];
  issues: string[];
}

/**
 * Manual supplements keep the public snapshot useful, but must not hide a
 * total upstream outage or a parser contract break from persisted history.
 */
export function evaluateScheduleCollectionQuality(
  sources: ScheduleSourceFetchHealth[],
  manualEntryCount: number,
): ScheduleCollectionQuality {
  const fetchSuccessCount =
    sources.filter((source) => source.fetchSucceeded).length;
  const parsedSourceCount =
    sources.filter((source) =>
      source.fetchSucceeded && source.parsedEntryCount > 0
    ).length;
  const parsedEntryCount = sources.reduce(
    (sum, source) => sum + Math.max(0, source.parsedEntryCount),
    0,
  );
  const failedSourceUrls = sources.filter((source) => !source.fetchSucceeded)
    .map((source) => source.url).sort();
  const parserEmptySourceUrls = sources.filter((source) =>
    source.fetchSucceeded && source.parsedEntryCount === 0
  ).map((source) => source.url).sort();
  const failedRequiredSourceUrls = sources.filter((source) =>
    source.requiredForPersistence && !source.fetchSucceeded
  ).map((source) => source.url).sort();
  const parserEmptyRequiredSourceUrls = sources.filter((source) =>
    source.requiredForPersistence && source.fetchSucceeded &&
    source.parsedEntryCount === 0
  ).map((source) => source.url).sort();
  const requiredSources = sources.filter((source) =>
    source.requiredForPersistence
  );
  const parsedRequiredSourceCount =
    requiredSources.filter((source) =>
      source.fetchSucceeded && source.parsedEntryCount > 0
    ).length;
  // Required schedule sources are independent, redundant providers. Persist
  // when at least one remains healthy, while retaining the per-source arrays
  // above for observability. A total required-source outage still blocks.
  const requiredSourcesUnavailable = requiredSources.length > 0 &&
    parsedRequiredSourceCount === 0;
  const issues = [
    ...(fetchSuccessCount === 0 ? ["schedule_sources_all_failed"] : []),
    ...(fetchSuccessCount > 0 && parsedSourceCount === 0
      ? ["schedule_sources_parser_empty"]
      : []),
    ...(requiredSourcesUnavailable && failedRequiredSourceUrls.length > 0
      ? [
        `required_schedule_source_fetch_failed:${
          failedRequiredSourceUrls.join(",")
        }`,
      ]
      : []),
    ...(requiredSourcesUnavailable && parserEmptyRequiredSourceUrls.length > 0
      ? [
        `required_schedule_source_parser_empty:${
          parserEmptyRequiredSourceUrls.join(",")
        }`,
      ]
      : []),
  ];
  return {
    sourceCount: sources.length,
    fetchSuccessCount,
    parsedSourceCount,
    parsedEntryCount,
    manualEntryCount: Math.max(0, manualEntryCount),
    manualFallbackOnly: manualEntryCount > 0 && parsedEntryCount === 0,
    failedSourceUrls,
    parserEmptySourceUrls,
    failedRequiredSourceUrls,
    parserEmptyRequiredSourceUrls,
    issues,
  };
}

export interface HubDataRow {
  id: string;
  metadata: JsonRecord;
  created_at: string;
}

export interface HubInsertResult {
  row: HubDataRow;
  created: boolean;
}

/**
 * Minimal persistence contract used by the snapshot workflow. Keeping the
 * Supabase client behind this interface makes retries and crash recovery
 * testable without a database.
 */
export interface LocalElectionHubStore {
  findSnapshotTransition(
    dataset: string,
    previousSnapshotId: string | null,
    snapshotHash: string,
  ): Promise<HubDataRow | null>;
  findSnapshotById(snapshotId: string): Promise<HubDataRow | null>;
  getLatestSnapshot(dataset: string): Promise<HubDataRow | null>;
  insertSnapshot(metadata: JsonRecord): Promise<HubInsertResult>;
  insertPostCandidate(metadata: JsonRecord): Promise<HubInsertResult>;
}

export interface CanonicalSource {
  label: string;
  url: string;
  category: string;
  note: string;
}

export interface CanonicalPrefecture {
  prefecture: string;
  sourceUrl: string;
  currentMembers: number;
  prefecturalAssemblyMembers: number;
  municipalAssemblyMembers: number;
  cdpLocalMembers: number;
  cdpSourceUrl: string;
}

export interface CanonicalMember {
  prefecture: string;
  sourceUrl: string;
  detailUrl: string;
  name: string;
  kana: string;
  constituency: string;
  municipality: string;
  assemblyLabel: string;
  assemblyCategory: string;
  electionCountLabel: string;
  birthDate: string;
  age: number | null;
  gender: string;
  profile: string;
}

export interface CanonicalScheduledCandidate {
  name: string;
  statusLabel: string;
  votes: number;
  xHandle: string;
}

export interface CanonicalSchedule {
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
  isPast: boolean;
  candidates: CanonicalScheduledCandidate[];
}

export interface CanonicalLocalElectionSnapshot {
  metrics: {
    baselineCurrentLocalMembers: number;
    officialCurrentLocalMembers: number;
    targetLocalMembers: number;
    baselineNetIncreaseRequired: number;
    actualNetIncreaseRequired: number;
    official2023FirstHalfWins: number;
    official2023SecondHalfWins: number;
    official2023TotalWins: number;
  };
  collectionQuality: {
    complete: boolean;
    failedPrefectureFetches: string[];
    linkedPrefectureCount: number;
    minimumExpectedMemberCount: number;
    officialElectionPrefectureLinkCount: number;
    minimumExpectedOfficialElectionPrefectureLinks: number;
    scheduleSourceCount: number;
    scheduleFetchSuccessCount: number;
    scheduleParsedSourceCount: number;
    scheduleParsedEntryCount: number;
    scheduleManualEntryCount: number;
    scheduleManualFallbackOnly: boolean;
    failedScheduleSourceUrls: string[];
    parserEmptyScheduleSourceUrls: string[];
    failedRequiredScheduleSourceUrls: string[];
    parserEmptyRequiredScheduleSourceUrls: string[];
    electionModeRegistryLoaded: boolean;
    officialEndorsementSnapshotLoaded: boolean;
    verifiedGoalSourceCount: number;
    expectedGoalSourceCount: number;
    electionIntelligenceIssues: string[];
    issues: string[];
  };
  electionIntelligence: ElectionIntelligenceSnapshot;
  sources: CanonicalSource[];
  prefectures: CanonicalPrefecture[];
  members: CanonicalMember[];
  upcomingSchedules: CanonicalSchedule[];
}

interface ChangedEntity<T> {
  before: T;
  after: T;
  changedFields: string[];
}

export interface LocalElectionSnapshotDiff {
  metrics: {
    before: CanonicalLocalElectionSnapshot["metrics"];
    after: CanonicalLocalElectionSnapshot["metrics"];
    changedFields: string[];
  };
  prefectures: {
    added: CanonicalPrefecture[];
    removed: CanonicalPrefecture[];
    changed: Array<ChangedEntity<CanonicalPrefecture>>;
  };
  members: {
    added: CanonicalMember[];
    removed: CanonicalMember[];
    changed: Array<ChangedEntity<CanonicalMember>>;
    significantChanged: Array<ChangedEntity<CanonicalMember>>;
  };
  schedules: {
    added: CanonicalSchedule[];
    removed: CanonicalSchedule[];
    changed: Array<ChangedEntity<CanonicalSchedule>>;
  };
  candidates: {
    added: Array<CanonicalScheduledCandidate & ScheduleIdentity>;
    removed: Array<CanonicalScheduledCandidate & ScheduleIdentity>;
    changed: Array<
      ChangedEntity<CanonicalScheduledCandidate> & ScheduleIdentity
    >;
  };
  electionIntelligence: {
    selectedModeChanged: boolean;
    goals: {
      added: ElectionGoalSnapshot[];
      removed: ElectionGoalSnapshot[];
      changed: Array<ChangedEntity<ElectionGoalSnapshot>>;
    };
    achievements: {
      added: ElectionAchievementSnapshot[];
      removed: ElectionAchievementSnapshot[];
      changed: Array<ChangedEntity<ElectionAchievementSnapshot>>;
    };
    officialEndorsements: {
      before: OfficialEndorsementSnapshot;
      after: OfficialEndorsementSnapshot;
      changedFields: string[];
    };
  };
  significantKinds: Array<
    | "member_delta"
    | "candidate_delta"
    | "schedule_delta"
    | "goal_delta"
    | "achievement_delta"
    | "endorsement_delta"
  >;
}

interface ScheduleIdentity {
  electionName: string;
  prefecture: string;
  municipality: string;
  voteDate: string;
  sourceUrl: string;
}

export interface PersistSnapshotResult {
  dataset: string;
  datasetVersion: string;
  snapshotHash: string;
  previousSnapshotId: string | null;
  previousSnapshotHash: string | null;
  baselineCreated: boolean;
  snapshotCreated: boolean;
  deduplicated: boolean;
  significantKinds: LocalElectionSnapshotDiff["significantKinds"];
  candidateCount: number;
  candidatesCreated: number;
  snapshotRow: HubDataRow;
  candidateRows: HubDataRow[];
}

function asRecord(value: unknown): JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function asUrl(value: unknown): string {
  const candidate = asString(value);
  return /^https?:\/\//i.test(candidate) ? candidate : "";
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

function asBoolean(value: unknown): boolean {
  return value === true;
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map(asString) : [];
}

function asNumberArray(value: unknown): number[] {
  return Array.isArray(value) ? value.map(asNumber) : [];
}

function compareStable(a: unknown, b: unknown): number {
  const first = stableStringify(a);
  const second = stableStringify(b);
  return first < second ? -1 : first > second ? 1 : 0;
}

/**
 * Removes request-time and AI prose fields and normalizes unordered entity
 * lists. The resulting value is the content-addressed dataset persisted in
 * history.
 */
export function canonicalizeLocalElectionSnapshot(
  rawSnapshot: unknown,
): CanonicalLocalElectionSnapshot {
  const raw = asRecord(rawSnapshot);
  const rawCollectionQuality = asRecord(raw.collectionQuality);
  const sourceRows = Array.isArray(raw.sources) ? raw.sources : [];
  const prefectureRows = Array.isArray(raw.prefectures) ? raw.prefectures : [];
  const memberRows = Array.isArray(raw.members) ? raw.members : [];
  const scheduleRows = Array.isArray(raw.upcomingSchedules)
    ? raw.upcomingSchedules
    : [];

  const sources = sourceRows.map((value): CanonicalSource => {
    const row = asRecord(value);
    return {
      label: asString(row.label),
      url: asUrl(row.url),
      category: asString(row.category),
      note: asString(row.note),
    };
  }).sort(compareStable);

  const prefectures = prefectureRows.map((value): CanonicalPrefecture => {
    const row = asRecord(value);
    return {
      prefecture: asString(row.prefecture),
      sourceUrl: asUrl(row.sourceUrl),
      currentMembers: asNumber(row.currentMembers),
      prefecturalAssemblyMembers: asNumber(row.prefecturalAssemblyMembers),
      municipalAssemblyMembers: asNumber(row.municipalAssemblyMembers),
      cdpLocalMembers: asNumber(row.cdpLocalMembers),
      cdpSourceUrl: asUrl(row.cdpSourceUrl),
    };
  }).sort(compareStable);

  const members = memberRows.map((value): CanonicalMember => {
    const row = asRecord(value);
    return {
      prefecture: asString(row.prefecture),
      sourceUrl: asUrl(row.sourceUrl),
      detailUrl: asUrl(row.detailUrl),
      name: asString(row.name),
      kana: asString(row.kana),
      constituency: asString(row.constituency),
      municipality: asString(row.municipality),
      assemblyLabel: asString(row.assemblyLabel),
      assemblyCategory: asString(row.assemblyCategory),
      electionCountLabel: asString(row.electionCountLabel),
      birthDate: asString(row.birthDate),
      age: asNullableNumber(row.age),
      gender: asString(row.gender),
      profile: asString(row.profile),
    };
  }).sort(compareStable);

  const upcomingSchedules = scheduleRows.map((value): CanonicalSchedule => {
    const row = asRecord(value);
    const canonicalCandidateRows = Array.isArray(row.candidates)
      ? row.candidates
      : [];
    const candidates = canonicalCandidateRows.length > 0
      ? canonicalCandidateRows.map((value): CanonicalScheduledCandidate => {
        const candidate = asRecord(value);
        return {
          name: asString(candidate.name),
          statusLabel: asString(candidate.statusLabel),
          votes: asNumber(candidate.votes),
          xHandle: asString(candidate.xHandle),
        };
      }).filter((candidate) => candidate.name !== "").sort(compareStable)
      : (() => {
        const names = asStringArray(row.kokuminCandidateNames);
        const statuses = asStringArray(row.kokuminCandidateStatuses);
        const votes = asNumberArray(row.kokuminCandidateVotes);
        const handles = asStringArray(row.kokuminCandidateXHandles);
        return names.map((name, index) => ({
          name,
          statusLabel: statuses[index] ?? "",
          votes: votes[index] ?? 0,
          xHandle: handles[index] ?? "",
        })).filter((candidate) => candidate.name !== "").sort(compareStable);
      })();
    return {
      electionName: asString(row.electionName),
      prefecture: asString(row.prefecture),
      municipality: asString(row.municipality),
      electionCategory: asString(row.electionCategory),
      voteDate: asString(row.voteDate),
      announcementDate: asString(row.announcementDate),
      detailUrl: asUrl(row.detailUrl),
      officialCandidateSourceUrl: asUrl(row.officialCandidateSourceUrl),
      seatCount: asNumber(row.seatCount),
      totalCandidateCount: asNumber(row.totalCandidateCount),
      isPast: asBoolean(row.isPast),
      candidates,
    };
  }).sort(compareStable);

  return {
    metrics: {
      baselineCurrentLocalMembers: asNumber(raw.baselineCurrentLocalMembers),
      officialCurrentLocalMembers: asNumber(raw.officialCurrentLocalMembers),
      targetLocalMembers: asNumber(raw.targetLocalMembers),
      baselineNetIncreaseRequired: asNumber(raw.baselineNetIncreaseRequired),
      actualNetIncreaseRequired: asNumber(raw.actualNetIncreaseRequired),
      official2023FirstHalfWins: asNumber(raw.official2023FirstHalfWins),
      official2023SecondHalfWins: asNumber(raw.official2023SecondHalfWins),
      official2023TotalWins: asNumber(raw.official2023TotalWins),
    },
    collectionQuality: {
      complete: asBoolean(rawCollectionQuality.complete),
      failedPrefectureFetches: asStringArray(
        rawCollectionQuality.failedPrefectureFetches,
      ).sort(),
      linkedPrefectureCount: asNumber(
        rawCollectionQuality.linkedPrefectureCount,
      ),
      minimumExpectedMemberCount: asNumber(
        rawCollectionQuality.minimumExpectedMemberCount,
      ),
      officialElectionPrefectureLinkCount: asNumber(
        rawCollectionQuality.officialElectionPrefectureLinkCount,
      ),
      minimumExpectedOfficialElectionPrefectureLinks: asNumber(
        rawCollectionQuality.minimumExpectedOfficialElectionPrefectureLinks,
      ),
      scheduleSourceCount: asNumber(
        rawCollectionQuality.scheduleSourceCount,
      ),
      scheduleFetchSuccessCount: asNumber(
        rawCollectionQuality.scheduleFetchSuccessCount,
      ),
      scheduleParsedSourceCount: asNumber(
        rawCollectionQuality.scheduleParsedSourceCount,
      ),
      scheduleParsedEntryCount: asNumber(
        rawCollectionQuality.scheduleParsedEntryCount,
      ),
      scheduleManualEntryCount: asNumber(
        rawCollectionQuality.scheduleManualEntryCount,
      ),
      scheduleManualFallbackOnly: asBoolean(
        rawCollectionQuality.scheduleManualFallbackOnly,
      ),
      failedScheduleSourceUrls: asStringArray(
        rawCollectionQuality.failedScheduleSourceUrls,
      ).sort(),
      parserEmptyScheduleSourceUrls: asStringArray(
        rawCollectionQuality.parserEmptyScheduleSourceUrls,
      ).sort(),
      failedRequiredScheduleSourceUrls: asStringArray(
        rawCollectionQuality.failedRequiredScheduleSourceUrls,
      ).sort(),
      parserEmptyRequiredScheduleSourceUrls: asStringArray(
        rawCollectionQuality.parserEmptyRequiredScheduleSourceUrls,
      ).sort(),
      electionModeRegistryLoaded: asBoolean(
        rawCollectionQuality.electionModeRegistryLoaded,
      ),
      officialEndorsementSnapshotLoaded: asBoolean(
        rawCollectionQuality.officialEndorsementSnapshotLoaded,
      ),
      verifiedGoalSourceCount: asNumber(
        rawCollectionQuality.verifiedGoalSourceCount,
      ),
      expectedGoalSourceCount: asNumber(
        rawCollectionQuality.expectedGoalSourceCount,
      ),
      electionIntelligenceIssues: asStringArray(
        rawCollectionQuality.electionIntelligenceIssues,
      ).sort(),
      issues: asStringArray(rawCollectionQuality.issues).sort(),
    },
    electionIntelligence: canonicalizeElectionIntelligenceSnapshot(
      raw.electionIntelligence,
    ),
    sources,
    prefectures,
    members,
    upcomingSchedules,
  };
}

export function stableStringify(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const record = value as JsonRecord;
    return `{${
      Object.keys(record).sort().map((key) =>
        `${JSON.stringify(key)}:${stableStringify(record[key])}`
      ).join(",")
    }}`;
  }
  return JSON.stringify(value) ?? "null";
}

export async function hashLocalElectionSnapshot(
  snapshot: CanonicalLocalElectionSnapshot,
): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(stableStringify(snapshot)),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function memberKey(member: CanonicalMember): string {
  return member.detailUrl || [
    member.prefecture,
    member.municipality,
    member.assemblyLabel,
    member.name,
  ].join("::");
}

function prefectureKey(prefecture: CanonicalPrefecture): string {
  return prefecture.prefecture;
}

function scheduleKey(schedule: CanonicalSchedule): string {
  return [
    schedule.prefecture,
    schedule.municipality,
    schedule.electionName,
    schedule.voteDate,
  ].join("::");
}

function candidateKey(
  schedule: CanonicalSchedule,
  candidate: CanonicalScheduledCandidate,
): string {
  return `${scheduleKey(schedule)}::${candidate.name}`;
}

function changedFields(before: object, after: object): string[] {
  const beforeRecord = before as JsonRecord;
  const afterRecord = after as JsonRecord;
  return [
    ...new Set([...Object.keys(beforeRecord), ...Object.keys(afterRecord)]),
  ]
    .filter((key) =>
      stableStringify(beforeRecord[key]) !== stableStringify(afterRecord[key])
    )
    .sort();
}

function diffEntities<T extends object>(
  before: T[],
  after: T[],
  keyFor: (item: T) => string,
): {
  added: T[];
  removed: T[];
  changed: Array<ChangedEntity<T>>;
} {
  const beforeMap = new Map(before.map((item) => [keyFor(item), item]));
  const afterMap = new Map(after.map((item) => [keyFor(item), item]));
  const added = [...afterMap.entries()]
    .filter(([key]) => !beforeMap.has(key)).map(([, value]) => value)
    .sort(compareStable);
  const removed = [...beforeMap.entries()]
    .filter(([key]) => !afterMap.has(key)).map(([, value]) => value)
    .sort(compareStable);
  const changed = [...afterMap.entries()].flatMap(([key, afterValue]) => {
    const beforeValue = beforeMap.get(key);
    if (!beforeValue) return [];
    const fields = changedFields(beforeValue, afterValue);
    return fields.length === 0
      ? []
      : [{ before: beforeValue, after: afterValue, changedFields: fields }];
  }).sort(compareStable);
  return { added, removed, changed };
}

const SIGNIFICANT_MEMBER_FIELDS = new Set([
  "prefecture",
  "name",
  "constituency",
  "municipality",
  "assemblyLabel",
  "assemblyCategory",
]);

const SCHEDULE_COMPARISON_FIELDS: Array<keyof CanonicalSchedule> = [
  "electionName",
  "prefecture",
  "municipality",
  "electionCategory",
  "voteDate",
  "announcementDate",
  "detailUrl",
  "officialCandidateSourceUrl",
  "seatCount",
  "totalCandidateCount",
  "isPast",
];

function scheduleWithoutCandidates(schedule: CanonicalSchedule): JsonRecord {
  return Object.fromEntries(
    SCHEDULE_COMPARISON_FIELDS.map((field) => [field, schedule[field]]),
  );
}

function scheduleIdentity(schedule: CanonicalSchedule): ScheduleIdentity {
  return {
    electionName: schedule.electionName,
    prefecture: schedule.prefecture,
    municipality: schedule.municipality,
    voteDate: schedule.voteDate,
    sourceUrl: schedule.officialCandidateSourceUrl || schedule.detailUrl,
  };
}

export function computeLocalElectionDiff(
  before: CanonicalLocalElectionSnapshot,
  after: CanonicalLocalElectionSnapshot,
): LocalElectionSnapshotDiff {
  const metricsChangedFields = changedFields(before.metrics, after.metrics);
  const prefectures = diffEntities(
    before.prefectures,
    after.prefectures,
    prefectureKey,
  );
  const members = diffEntities(
    before.members,
    after.members,
    memberKey,
  );
  const significantChanged = members.changed.filter((item) =>
    item.changedFields.some((field) => SIGNIFICANT_MEMBER_FIELDS.has(field))
  );

  const beforeScheduleMap = new Map(
    before.upcomingSchedules.map((item) => [scheduleKey(item), item]),
  );
  const afterScheduleMap = new Map(
    after.upcomingSchedules.map((item) => [scheduleKey(item), item]),
  );
  const addedSchedules = [...afterScheduleMap.entries()]
    .filter(([key]) => !beforeScheduleMap.has(key)).map(([, item]) => item)
    .sort(compareStable);
  const removedSchedules = [...beforeScheduleMap.entries()]
    .filter(([key]) => !afterScheduleMap.has(key)).map(([, item]) => item)
    .sort(compareStable);
  const changedSchedules = [...afterScheduleMap.entries()].flatMap(
    ([key, afterSchedule]) => {
      const beforeSchedule = beforeScheduleMap.get(key);
      if (!beforeSchedule) return [];
      const fields = changedFields(
        scheduleWithoutCandidates(beforeSchedule),
        scheduleWithoutCandidates(afterSchedule),
      );
      return fields.length === 0 ? [] : [{
        before: beforeSchedule,
        after: afterSchedule,
        changedFields: fields,
      }];
    },
  ).sort(compareStable);

  type CandidateWithSchedule = CanonicalScheduledCandidate & ScheduleIdentity;
  const flattenCandidates = (
    schedules: CanonicalSchedule[],
  ): Array<
    {
      key: string;
      candidate: CanonicalScheduledCandidate;
      identity: ScheduleIdentity;
    }
  > =>
    schedules.flatMap((schedule) =>
      schedule.candidates.map((candidate) => ({
        key: candidateKey(schedule, candidate),
        candidate,
        identity: scheduleIdentity(schedule),
      }))
    );
  const beforeCandidates = new Map(
    flattenCandidates(before.upcomingSchedules).map((item) => [item.key, item]),
  );
  const afterCandidates = new Map(
    flattenCandidates(after.upcomingSchedules).map((item) => [item.key, item]),
  );
  const addedCandidates: CandidateWithSchedule[] = [
    ...afterCandidates.entries(),
  ]
    .filter(([key]) => !beforeCandidates.has(key))
    .map(([, item]) => ({ ...item.candidate, ...item.identity }))
    .sort(compareStable);
  const removedCandidates: CandidateWithSchedule[] = [
    ...beforeCandidates.entries(),
  ]
    .filter(([key]) => !afterCandidates.has(key))
    .map(([, item]) => ({ ...item.candidate, ...item.identity }))
    .sort(compareStable);
  const changedCandidates = [...afterCandidates.entries()].flatMap(
    ([key, afterItem]) => {
      const beforeItem = beforeCandidates.get(key);
      if (!beforeItem) return [];
      const fields = changedFields(beforeItem.candidate, afterItem.candidate);
      return fields.length === 0 ? [] : [{
        before: beforeItem.candidate,
        after: afterItem.candidate,
        changedFields: fields,
        ...afterItem.identity,
      }];
    },
  ).sort(compareStable);

  const goals = diffEntities(
    before.electionIntelligence.goals,
    after.electionIntelligence.goals,
    (goal) => goal.id,
  );
  const achievements = diffEntities(
    before.electionIntelligence.achievements,
    after.electionIntelligence.achievements,
    (achievement) => achievement.id,
  );
  const officialEndorsementChangedFields = changedFields(
    before.electionIntelligence.officialEndorsements,
    after.electionIntelligence.officialEndorsements,
  );
  const selectedModeChanged = before.electionIntelligence.selectedMode !==
    after.electionIntelligence.selectedMode;

  const memberMetricFields = new Set([
    "officialCurrentLocalMembers",
    "targetLocalMembers",
    "actualNetIncreaseRequired",
  ]);
  const hasMemberDelta = members.added.length > 0 ||
    members.removed.length > 0 || significantChanged.length > 0 ||
    prefectures.added.length > 0 || prefectures.removed.length > 0 ||
    prefectures.changed.some((item) =>
      item.changedFields.some((field) =>
        field === "currentMembers" ||
        field === "prefecturalAssemblyMembers" ||
        field === "municipalAssemblyMembers"
      )
    ) || metricsChangedFields.some((field) => memberMetricFields.has(field));
  const hasCandidateDelta = addedCandidates.length > 0 ||
    removedCandidates.length > 0 || changedCandidates.length > 0;
  const hasScheduleDelta = addedSchedules.length > 0 ||
    removedSchedules.length > 0 || changedSchedules.length > 0;
  const hasGoalDelta = selectedModeChanged || goals.added.length > 0 ||
    goals.removed.length > 0 || goals.changed.length > 0;
  const hasAchievementDelta = achievements.added.length > 0 ||
    achievements.removed.length > 0 || achievements.changed.length > 0;
  const hasEndorsementDelta = officialEndorsementChangedFields.length > 0;
  const significantKinds: LocalElectionSnapshotDiff["significantKinds"] = [];
  if (hasMemberDelta) significantKinds.push("member_delta");
  if (hasCandidateDelta) significantKinds.push("candidate_delta");
  if (hasScheduleDelta) significantKinds.push("schedule_delta");
  if (hasGoalDelta) significantKinds.push("goal_delta");
  if (hasAchievementDelta) significantKinds.push("achievement_delta");
  if (hasEndorsementDelta) significantKinds.push("endorsement_delta");

  return {
    metrics: {
      before: before.metrics,
      after: after.metrics,
      changedFields: metricsChangedFields,
    },
    prefectures,
    members: { ...members, significantChanged },
    schedules: {
      added: addedSchedules,
      removed: removedSchedules,
      changed: changedSchedules,
    },
    candidates: {
      added: addedCandidates,
      removed: removedCandidates,
      changed: changedCandidates,
    },
    electionIntelligence: {
      selectedModeChanged,
      goals,
      achievements,
      officialEndorsements: {
        before: before.electionIntelligence.officialEndorsements,
        after: after.electionIntelligence.officialEndorsements,
        changedFields: officialEndorsementChangedFields,
      },
    },
    significantKinds,
  };
}

function uniqueUrls(values: unknown[]): string[] {
  return [...new Set(values.map(asUrl).filter((url) => url !== ""))];
}

function sourceUrlsForCategories(
  snapshot: CanonicalLocalElectionSnapshot,
  categories: string[],
): string[] {
  const categorySet = new Set(categories);
  return uniqueUrls(
    snapshot.sources.filter((source) => categorySet.has(source.category))
      .map((source) => source.url),
  );
}

function signed(value: number): string {
  return value > 0 ? `+${value}` : String(value);
}

function namesLine(label: string, names: string[], limit = 5): string {
  const normalized = [...new Set(names.filter((name) => name !== ""))];
  if (normalized.length === 0) return "";
  const suffix = normalized.length > limit
    ? ` ほか${normalized.length - limit}人`
    : "";
  return `${label}: ${normalized.slice(0, limit).join("、")}${suffix}`;
}

function fitPostText(
  requiredLines: string[],
  optionalLines: string[],
  sourceUrl: string,
  hashtags: string,
): string {
  const tail = [sourceUrl, hashtags].filter((line) => line !== "");
  const lines = requiredLines.filter((line) => line !== "");
  for (const line of optionalLines.filter((item) => item !== "")) {
    const candidate = [...lines, line, ...tail].join("\n");
    if (Array.from(candidate).length <= 280) lines.push(line);
  }
  const combined = [...lines, ...tail].join("\n");
  if (Array.from(combined).length <= 280) return combined;
  const tailText = tail.join("\n");
  const available = Math.max(0, 279 - Array.from(tailText).length);
  const head = Array.from(lines.join("\n")).slice(0, available).join("")
    .replace(/[、,\s]+$/u, "");
  return [head ? `${head}…` : "", tailText].filter(Boolean).join("\n");
}

function diffCountSummary(diff: LocalElectionSnapshotDiff): JsonRecord {
  return {
    significant_kinds: diff.significantKinds,
    metrics_changed: diff.metrics.changedFields,
    prefectures_added: diff.prefectures.added.length,
    prefectures_removed: diff.prefectures.removed.length,
    prefectures_changed: diff.prefectures.changed.length,
    members_added: diff.members.added.length,
    members_removed: diff.members.removed.length,
    members_changed: diff.members.changed.length,
    schedules_added: diff.schedules.added.length,
    schedules_removed: diff.schedules.removed.length,
    schedules_changed: diff.schedules.changed.length,
    candidates_added: diff.candidates.added.length,
    candidates_removed: diff.candidates.removed.length,
    candidates_changed: diff.candidates.changed.length,
    goals_added: diff.electionIntelligence.goals.added.length,
    goals_removed: diff.electionIntelligence.goals.removed.length,
    goals_changed: diff.electionIntelligence.goals.changed.length,
    achievements_added: diff.electionIntelligence.achievements.added.length,
    achievements_removed: diff.electionIntelligence.achievements.removed.length,
    achievements_changed: diff.electionIntelligence.achievements.changed.length,
    endorsement_fields_changed:
      diff.electionIntelligence.officialEndorsements.changedFields,
  };
}

function commonCandidateMetadata(
  snapshotObservationId: string,
  snapshotHash: string,
  previousSnapshotId: string,
  previousSnapshotHash: string,
  datasetVersion: string,
  observedAt: string,
  diffKind: LocalElectionSnapshotDiff["significantKinds"][number],
  variant: string,
  text: string,
  sourceUrls: string[],
  diff: JsonRecord,
): JsonRecord {
  const contentArchetype = "data_report";
  const candidateKeyValue = [
    "local-election",
    snapshotObservationId,
    previousSnapshotHash.slice(0, 12),
    snapshotHash.slice(0, 12),
    diffKind,
  ].join(":");
  const common = buildXPostCandidateMetadata({
    action: "x.post",
    text,
    replyTexts: [],
    source: LOCAL_ELECTION_DATASET_SOURCE,
    route: "local-election-intelligence.snapshotAndQueue",
    variant,
    contentKind: "local_election_delta",
    contentArchetype,
    ownerUserId: "service_role",
  }, {
    candidateKey: candidateKeyValue,
    candidateType: "local_election_delta",
    sourceKind: "local_election_snapshot_diff",
    sourceUrls,
    createdBy: LOCAL_ELECTION_DATASET_SOURCE,
    now: new Date(observedAt),
  });
  return {
    ...common,
    dataset: LOCAL_ELECTION_DATASET,
    dataset_source: LOCAL_ELECTION_DATASET_SOURCE,
    dataset_version: datasetVersion,
    dataset_schema_version: LOCAL_ELECTION_SNAPSHOT_SCHEMA_VERSION,
    snapshot_observation_id: snapshotObservationId,
    dataset_snapshot_hash: snapshotHash,
    previous_snapshot_id: previousSnapshotId,
    previous_snapshot_hash: previousSnapshotHash,
    diff_kind: diffKind,
    observed_at: observedAt,
    requires_human_approval: true,
    auto_publish: false,
    diff,
  };
}

export function buildLocalElectionPostCandidates(
  snapshot: CanonicalLocalElectionSnapshot,
  diff: LocalElectionSnapshotDiff,
  snapshotObservationId: string,
  snapshotHash: string,
  previousSnapshotId: string,
  previousSnapshotHash: string,
  datasetVersion: string,
  observedAt: string,
  partyGapOptions?: {
    /// wall-clock の今回実行時刻。isConsecutiveRetry 経路の observedAt は
    /// 「hash が最初に現れた時刻」で stale のため、週次系列の ISO 週キーに
    /// そのまま使うとデータ無変化週に候補が一度も作られない(レビュー F3)。
    queueObservedAt?: string;
    cdpByPrefecture?: Record<string, number> | null;
  },
): JsonRecord[] {
  const rows: JsonRecord[] = [];

  if (diff.significantKinds.includes("member_delta")) {
    const before = diff.metrics.before.officialCurrentLocalMembers;
    const after = diff.metrics.after.officialCurrentLocalMembers;
    const target = diff.metrics.after.targetLocalMembers;
    const remaining = Math.max(0, target - after);
    const sourceUrls = uniqueUrls([
      ...diff.members.added.flatMap((
        member,
      ) => [member.sourceUrl, member.detailUrl]),
      ...diff.members.removed.flatMap((
        member,
      ) => [member.sourceUrl, member.detailUrl]),
      ...sourceUrlsForCategories(snapshot, [
        "official_members",
        "official_member_profiles",
      ]),
    ]);
    const text = fitPostText(
      [
        "【国民民主党・地方議員データ更新】",
        `公式掲載の地方議員は ${before}→${after}人（${
          signed(after - before)
        }）。`,
        `${target}人目標まであと${remaining}人です。`,
      ],
      [
        namesLine("新規掲載", diff.members.added.map((member) => member.name)),
        namesLine(
          "掲載終了",
          diff.members.removed.map((member) => member.name),
        ),
        namesLine(
          "更新地域",
          diff.prefectures.changed.map((item) => item.after.prefecture),
        ),
      ],
      sourceUrls[0] ?? "",
      "#国民民主党 #地方政治",
    );
    rows.push(commonCandidateMetadata(
      snapshotObservationId,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      datasetVersion,
      observedAt,
      "member_delta",
      "member_delta_national_progress",
      text,
      sourceUrls,
      {
        type: "member_delta",
        before_count: before,
        after_count: after,
        delta: after - before,
        target_count: target,
        remaining_count: remaining,
        added: diff.members.added,
        removed: diff.members.removed,
        changed: diff.members.significantChanged,
        prefectures: diff.prefectures,
      },
    ));
  }

  if (diff.significantKinds.includes("candidate_delta")) {
    const sourceUrls = uniqueUrls([
      ...diff.candidates.added.map((candidate) => candidate.sourceUrl),
      ...diff.candidates.removed.map((candidate) => candidate.sourceUrl),
      ...diff.candidates.changed.map((candidate) => candidate.sourceUrl),
      ...sourceUrlsForCategories(snapshot, ["official_local_elections"]),
    ]);
    const affectedPrefectures = [
      ...diff.candidates.added,
      ...diff.candidates.removed,
      ...diff.candidates.changed,
    ].map((candidate) => candidate.prefecture);
    const text = fitPostText(
      [
        "【公認・候補予定者データ更新】",
        "公式選挙情報の前回取得分との差分を検知しました。",
        `追加${diff.candidates.added.length}人 / 掲載終了${diff.candidates.removed.length}人 / 内容更新${diff.candidates.changed.length}件`,
      ],
      [
        namesLine(
          "追加",
          diff.candidates.added.map((candidate) => candidate.name),
        ),
        namesLine(
          "掲載終了",
          diff.candidates.removed.map((candidate) => candidate.name),
        ),
        namesLine("対象", affectedPrefectures),
      ],
      sourceUrls[0] ?? "",
      "#国民民主党 #地方選挙",
    );
    rows.push(commonCandidateMetadata(
      snapshotObservationId,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      datasetVersion,
      observedAt,
      "candidate_delta",
      "scheduled_candidate_delta",
      text,
      sourceUrls,
      {
        type: "candidate_delta",
        added: diff.candidates.added,
        removed: diff.candidates.removed,
        changed: diff.candidates.changed,
      },
    ));
  }

  if (diff.significantKinds.includes("schedule_delta")) {
    const changedSchedules = [
      ...diff.schedules.added,
      ...diff.schedules.removed,
      ...diff.schedules.changed.map((item) => item.after),
    ];
    const sourceUrls = uniqueUrls([
      ...changedSchedules.flatMap((schedule) => [
        schedule.detailUrl,
        schedule.officialCandidateSourceUrl,
      ]),
      ...sourceUrlsForCategories(snapshot, ["schedule_source"]),
    ]);
    const text = fitPostText(
      [
        "【今後の地方選挙データ更新】",
        `追加${diff.schedules.added.length}件 / 掲載終了${diff.schedules.removed.length}件 / 内容更新${diff.schedules.changed.length}件`,
      ],
      [
        namesLine(
          "対象",
          changedSchedules.map((schedule) => schedule.electionName),
          3,
        ),
        namesLine(
          "投票日",
          changedSchedules.map((schedule) => schedule.voteDate),
          3,
        ),
      ],
      sourceUrls[0] ?? "",
      "#地方選挙 #国民民主党",
    );
    rows.push(commonCandidateMetadata(
      snapshotObservationId,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      datasetVersion,
      observedAt,
      "schedule_delta",
      "local_election_schedule_delta",
      text,
      sourceUrls,
      {
        type: "schedule_delta",
        added: diff.schedules.added,
        removed: diff.schedules.removed,
        changed: diff.schedules.changed,
      },
    ));
  }

  // R28: 週次の両党地力差ランキング(diff 非依存の定点観測系列)。日次 cron
  // から毎回呼ばれるが candidate_key が ISO 週キーなので insertPostCandidate
  // の冪等性により週1回だけ候補が作られる。生成不能条件(立憲実数源の欠落等)
  // は composer 側で null。observedAt は wall-clock(queueObservedAt)を使う:
  // snapshot 行の observed_at はデータ無変化週に前週のまま止まり、週キーが
  // 過去週で冪等スキップされ続ける(レビュー F3)。
  if (diff.significantKinds.includes("goal_delta")) {
    const goalDiff = diff.electionIntelligence.goals;
    const changedGoals = [
      ...goalDiff.added,
      ...goalDiff.removed,
      ...goalDiff.changed.map((item) => item.after),
    ];
    const sourceUrls = uniqueUrls([
      ...changedGoals.map((goal) => goal.sourceUrl),
      ...sourceUrlsForCategories(snapshot, ["official_party_goal"]),
    ]);
    const goalTitles = [...new Set(changedGoals.map((goal) => goal.title))]
      .filter(Boolean).slice(0, 3).join(" / ");
    const text = fitPostText(
      [
        "【国民民主党 公式目標データ更新】",
        `追加${goalDiff.added.length}件 / 終了${goalDiff.removed.length}件 / 更新${goalDiff.changed.length}件`,
      ],
      [goalTitles ? `対象: ${goalTitles}` : ""],
      sourceUrls[0] ?? "",
      "#国民民主党 #選挙",
    );
    rows.push(commonCandidateMetadata(
      snapshotObservationId,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      datasetVersion,
      observedAt,
      "goal_delta",
      "official_party_goal_delta",
      text,
      sourceUrls,
      {
        type: "goal_delta",
        selected_mode_changed: diff.electionIntelligence.selectedModeChanged,
        added: goalDiff.added,
        removed: goalDiff.removed,
        changed: goalDiff.changed,
      },
    ));
  }

  if (diff.significantKinds.includes("achievement_delta")) {
    const achievementDiff = diff.electionIntelligence.achievements;
    const changedAchievements = [
      ...achievementDiff.added,
      ...achievementDiff.removed,
      ...achievementDiff.changed.map((item) => item.after),
    ];
    const sourceUrls = uniqueUrls(
      changedAchievements.flatMap((achievement) => achievement.sourceUrls),
    );
    const titles = [
      ...new Set(changedAchievements.map((achievement) => achievement.title)),
    ].filter(Boolean).slice(0, 3).join(" / ");
    const text = fitPostText(
      [
        "【国民民主党 選挙実績データ更新】",
        `追加${achievementDiff.added.length}件 / 終了${achievementDiff.removed.length}件 / 更新${achievementDiff.changed.length}件`,
      ],
      [titles ? `対象: ${titles}` : ""],
      sourceUrls[0] ?? "",
      "#国民民主党 #選挙",
    );
    rows.push(commonCandidateMetadata(
      snapshotObservationId,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      datasetVersion,
      observedAt,
      "achievement_delta",
      "official_election_achievement_delta",
      text,
      sourceUrls,
      {
        type: "achievement_delta",
        added: achievementDiff.added,
        removed: achievementDiff.removed,
        changed: achievementDiff.changed,
      },
    ));
  }

  if (diff.significantKinds.includes("endorsement_delta")) {
    const endorsementDiff = diff.electionIntelligence.officialEndorsements;
    const before = endorsementDiff.before;
    const after = endorsementDiff.after;
    const sourceUrls = uniqueUrls([
      after.sourceUrl,
      before.sourceUrl,
      ...sourceUrlsForCategories(snapshot, ["official_endorsement_snapshot"]),
    ]);
    const text = fitPostText(
      [
        "【国民民主党 公認予定候補データ更新】",
        `公認掲載 ${before.totalCount}→${after.totalCount}件 (${
          signed(after.totalCount - before.totalCount)
        })`,
      ],
      [
        `現職${after.incumbentCount} / 新人${after.newcomerCount} / 元職${after.formerCount}`,
        `${after.prefectureCount}/47都道府県・${after.sourceAsOf}現在`,
      ],
      sourceUrls[0] ?? "",
      "#国民民主党 #地方選",
    );
    rows.push(commonCandidateMetadata(
      snapshotObservationId,
      snapshotHash,
      previousSnapshotId,
      previousSnapshotHash,
      datasetVersion,
      observedAt,
      "endorsement_delta",
      "official_local_endorsement_delta",
      text,
      sourceUrls,
      {
        type: "endorsement_delta",
        changed_fields: endorsementDiff.changedFields,
        before,
        after,
      },
    ));
  }

  const partyGap = buildPartyGapCandidateMetadata(snapshot, {
    snapshotObservationId,
    snapshotHash,
    datasetVersion,
    observedAt: partyGapOptions?.queueObservedAt ?? observedAt,
    datasetSource: LOCAL_ELECTION_DATASET_SOURCE,
    dataset: LOCAL_ELECTION_DATASET,
    cdpByPrefecture: partyGapOptions?.cdpByPrefecture ?? null,
  });
  if (partyGap !== null) rows.push(partyGap);

  return rows;
}

function parseCanonicalSnapshot(
  value: unknown,
): CanonicalLocalElectionSnapshot | null {
  const record = asRecord(value);
  if (!record.metrics || !Array.isArray(record.members)) return null;
  return canonicalizeLocalElectionSnapshot({
    ...record,
    ...asRecord(record.metrics),
  });
}

function snapshotVersion(snapshotHash: string): string {
  return `v${LOCAL_ELECTION_SNAPSHOT_SCHEMA_VERSION}-${
    snapshotHash.slice(0, 16)
  }`;
}

/**
 * Saves an observation transition and ensures every significant transition
 * has its pending approval candidates. Consecutive retries reuse the latest
 * row, while a non-consecutive return to an old content hash creates a new
 * observation linked to its actual predecessor.
 */
export async function persistLocalElectionSnapshot(
  store: LocalElectionHubStore,
  rawSnapshot: unknown,
  observedAt = new Date().toISOString(),
  partyGapOptions?: {
    cdpByPrefecture?: Record<string, number> | null;
  },
): Promise<PersistSnapshotResult> {
  const snapshot = canonicalizeLocalElectionSnapshot(rawSnapshot);
  if (!snapshot.collectionQuality.complete) {
    throw new Error(
      `incomplete local-election snapshot cannot be persisted: ${
        snapshot.collectionQuality.issues.join("; ") || "quality gate failed"
      }`,
    );
  }
  const snapshotHash = await hashLocalElectionSnapshot(snapshot);
  const datasetVersion = snapshotVersion(snapshotHash);
  const latestRow = await store.getLatestSnapshot(LOCAL_ELECTION_DATASET);
  const isConsecutiveRetry = latestRow != null &&
    asString(latestRow.metadata.snapshot_hash) === snapshotHash;
  let snapshotRow: HubDataRow;
  let snapshotCreated = false;
  let previousSnapshotId: string | null = null;
  let previousSnapshotHash: string | null = null;
  let previousRow: HubDataRow | null = null;

  if (isConsecutiveRetry && latestRow) {
    snapshotRow = latestRow;
    previousSnapshotId = asString(
      snapshotRow.metadata.previous_snapshot_id,
    ) || null;
    previousSnapshotHash = asString(
      snapshotRow.metadata.previous_snapshot_hash,
    ) || null;
    if (previousSnapshotId) {
      previousRow = await store.findSnapshotById(previousSnapshotId);
    }
  } else {
    previousRow = latestRow;
    previousSnapshotId = previousRow?.id ?? null;
    previousSnapshotHash = previousRow
      ? asString(previousRow.metadata.snapshot_hash) || null
      : null;
    const previousSnapshot = previousRow
      ? parseCanonicalSnapshot(previousRow.metadata.snapshot)
      : null;
    const initialDiff = previousSnapshot
      ? computeLocalElectionDiff(previousSnapshot, snapshot)
      : null;
    const insertion = await store.insertSnapshot({
      record_type: "dataset_snapshot",
      dataset: LOCAL_ELECTION_DATASET,
      dataset_source: LOCAL_ELECTION_DATASET_SOURCE,
      dataset_version: datasetVersion,
      dataset_schema_version: LOCAL_ELECTION_SNAPSHOT_SCHEMA_VERSION,
      snapshot_hash: snapshotHash,
      previous_snapshot_id: previousSnapshotId,
      previous_snapshot_hash: previousSnapshotHash,
      observed_at: observedAt,
      snapshot,
      change_summary: initialDiff ? diffCountSummary(initialDiff) : null,
      is_baseline: previousSnapshot === null,
      created_by: LOCAL_ELECTION_DATASET_SOURCE,
      user_id: "service_role",
    });
    snapshotRow = insertion.row;
    snapshotCreated = insertion.created;
    // A concurrent writer may have won the same predecessor/current
    // transition. Use its persisted predecessor so both callers repair the
    // exact same candidate set.
    previousSnapshotId = asString(
      snapshotRow.metadata.previous_snapshot_id,
    ) || null;
    previousSnapshotHash = asString(
      snapshotRow.metadata.previous_snapshot_hash,
    ) || null;
    if (
      previousSnapshotId &&
      (!previousRow || previousRow.id !== previousSnapshotId)
    ) {
      previousRow = await store.findSnapshotById(previousSnapshotId);
    } else if (!previousSnapshotId) {
      previousRow = null;
    }
  }

  const previousSnapshot = previousRow
    ? parseCanonicalSnapshot(previousRow.metadata.snapshot)
    : null;
  if (!previousSnapshot || !previousSnapshotId || !previousSnapshotHash) {
    return {
      dataset: LOCAL_ELECTION_DATASET,
      datasetVersion,
      snapshotHash,
      previousSnapshotId: null,
      previousSnapshotHash: null,
      baselineCreated: snapshotCreated && previousSnapshotId === null,
      snapshotCreated,
      deduplicated: !snapshotCreated,
      significantKinds: [],
      candidateCount: 0,
      candidatesCreated: 0,
      snapshotRow,
      candidateRows: [],
    };
  }

  const diff = computeLocalElectionDiff(previousSnapshot, snapshot);
  const candidateMetadata = buildLocalElectionPostCandidates(
    snapshot,
    diff,
    snapshotRow.id,
    snapshotHash,
    previousSnapshotId,
    previousSnapshotHash,
    datasetVersion,
    asString(snapshotRow.metadata.observed_at) || observedAt,
    {
      queueObservedAt: observedAt,
      cdpByPrefecture: partyGapOptions?.cdpByPrefecture ?? null,
    },
  );
  const insertions: HubInsertResult[] = [];
  for (const metadata of candidateMetadata) {
    insertions.push(
      await store.insertPostCandidate({
        ...metadata,
        user_id: "service_role",
      }),
    );
  }

  return {
    dataset: LOCAL_ELECTION_DATASET,
    datasetVersion,
    snapshotHash,
    previousSnapshotId,
    previousSnapshotHash,
    baselineCreated: false,
    snapshotCreated,
    deduplicated: !snapshotCreated,
    significantKinds: diff.significantKinds,
    candidateCount: insertions.length,
    candidatesCreated: insertions.filter((item) => item.created).length,
    snapshotRow,
    candidateRows: insertions.map((item) => item.row),
  };
}
