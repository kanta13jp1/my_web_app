import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

const OFFICIAL_MEMBER_PAGE_URL = "https://new-kokumin.jp/member";
const OFFICIAL_ELECTION_PAGE_URL = "https://new-kokumin.jp/election";
const OFFICIAL_2023_FIRST_HALF_URL =
  "https://new-kokumin.jp/news/election/20230410_election";
const OFFICIAL_2023_SECOND_HALF_URL =
  "https://new-kokumin.jp/news/election/20230423_1";
const ELECTION_SCHEDULE_URL = "https://go2senkyo.com/schedule";

const TARGET_LOCAL_MEMBERS = 700;
const BASELINE_CURRENT_LOCAL_MEMBERS = 340;
const SCHEDULE_WINDOW_DAYS = 120;
const SCHEDULE_MAX_ENTRIES = 60;

const PREFECTURES = [
  "北海道",
  "青森県",
  "岩手県",
  "宮城県",
  "秋田県",
  "山形県",
  "福島県",
  "茨城県",
  "栃木県",
  "群馬県",
  "埼玉県",
  "千葉県",
  "東京都",
  "神奈川県",
  "新潟県",
  "富山県",
  "石川県",
  "福井県",
  "山梨県",
  "長野県",
  "岐阜県",
  "静岡県",
  "愛知県",
  "三重県",
  "滋賀県",
  "京都府",
  "大阪府",
  "兵庫県",
  "奈良県",
  "和歌山県",
  "鳥取県",
  "島根県",
  "岡山県",
  "広島県",
  "山口県",
  "徳島県",
  "香川県",
  "愛媛県",
  "高知県",
  "福岡県",
  "佐賀県",
  "長崎県",
  "熊本県",
  "大分県",
  "宮崎県",
  "鹿児島県",
  "沖縄県",
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
}

interface PrefectureReality {
  prefecture: string;
  sourceUrl: string;
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
}

interface ScheduleOverviewEntry {
  electionName: string;
  prefecture: string;
  voteDate: string;
  detailUrl: string;
}

interface SnapshotRequest {
  action: "snapshot";
  includeAiSummary: boolean;
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
      return jsonResponse({
        success: true,
        profile,
      });
    }

    const memberPageHtml = await fetchText(OFFICIAL_MEMBER_PAGE_URL);
    const officialElectionHtml = await fetchText(OFFICIAL_ELECTION_PAGE_URL);
    const prefectureLinkMap = parsePrefectureLinks(memberPageHtml);
    const officialElectionPrefectureLinks = parseOfficialElectionPrefectureLinks(
      officialElectionHtml,
    );
    const prefectureResults = await mapWithConcurrency(
      [...PREFECTURES],
      6,
      async (prefecture) => {
        const sourceUrl = prefectureLinkMap.get(prefecture) ?? "";
        return await fetchPrefectureReality(prefecture, sourceUrl);
      },
    );

    const prefectures = prefectureResults.map((item) => ({
      prefecture: item.prefecture,
      sourceUrl: item.sourceUrl,
      currentMembers: item.currentMembers,
      prefecturalAssemblyMembers: item.prefecturalAssemblyMembers,
      municipalAssemblyMembers: item.municipalAssemblyMembers,
    }));
    const members = prefectureResults
      .flatMap((item) => item.members)
      .sort(compareMembers);
    const officialCurrentLocalMembers = members.length;
    const historical = await fetchHistoricalResult();
    const officialScheduledCandidates = (
      await mapWithConcurrency(
        [...officialElectionPrefectureLinks.entries()],
        6,
        async ([prefecture, sourceUrl]) => {
          const html = await fetchText(sourceUrl);
          return parseOfficialScheduledCandidates(prefecture, sourceUrl, html);
        },
      )
    ).flat();
    const upcomingSchedules = await fetchUpcomingLocalElectionSchedules(
      officialScheduledCandidates,
    );

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
      official2023TotalWins: historical.totalWins,      sources: [
        {
          label: "地方議員一覧",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_members",
          note: "党公式の地方議員一覧ページです。",
        },
        {
          label: "地方議員プロフィール",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_member_profiles",
          note: "年齢やプロフィールは党公式の議員詳細ページから補完します。",
        },
        {
          label: "2023 統一地方選 前半",
          url: OFFICIAL_2023_FIRST_HALF_URL,
          category: "official_2023_first_half",
          note: "2023年統一地方選の前半戦実績です。",
        },
        {
          label: "2023 統一地方選 後半",
          url: OFFICIAL_2023_SECOND_HALF_URL,
          category: "official_2023_second_half",
          note: "2023年統一地方選の後半戦実績です。",
        },
        {
          label: "党公式 地方選挙候補予定者",
          url: OFFICIAL_ELECTION_PAGE_URL,
          category: "official_local_elections",
          note: "国民民主党の候補予定者ページです。",
        },
        {
          label: "地方選挙スケジュール",
          url: ELECTION_SCHEDULE_URL,
          category: "schedule_source",
          note: "投票日と告示日を確認するための日程ソースです。",
        },
      ],      prefectures,
      members,
      upcomingSchedules,
    };

    const aiAnalysis = parsedRequest.includeAiSummary
      ? await buildAiAnalysis(snapshotBase)
      : buildFallbackAnalysis(snapshotBase);

    return jsonResponse({
      success: true,
      snapshot: {
        ...snapshotBase,
        aiSummary: aiAnalysis.summary,
        aiAlerts: aiAnalysis.alerts,
        aiStrategicNotes: aiAnalysis.strategicNotes,
        scheduleAiSummary: aiAnalysis.scheduleSummary,
        scheduleAiAlerts: aiAnalysis.scheduleAlerts,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("local-election-intelligence failed:", message);
    return jsonResponse(
      { success: false, error: message },
      { status: 400 },
    );
  }
});

async function parseRequest(req: Request): Promise<ParsedRequest> {
  let body: Record<string, unknown> = {};

  if (req.method === "POST") {
    try {
      const parsed = await req.json();
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
    };
  }

  return {
    action: "snapshot",
    includeAiSummary: body.includeAiSummary !== false,
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
          "my_web_app local-election-intelligence/1.1 (+https://my-web-app-b67f4.web.app/)",
      },
      signal: controller.signal,
      redirect: "follow",
    });
    if (!response.ok) {
      throw new Error(`Fetch failed: ${response.status} ${url}`);
    }
    return await response.text();
  } finally {
    clearTimeout(timeoutId);
  }
}

function parsePrefectureLinks(html: string): Map<string, string> {
  const section = html.includes("蝨ｰ譁ｹ閾ｪ豐ｻ菴楢ｭｰ蜩｡ LOCAL ASSEMBLY MEMBERS")
    ? html.split("蝨ｰ譁ｹ閾ｪ豐ｻ菴楢ｭｰ蜩｡ LOCAL ASSEMBLY MEMBERS")[1]
    : html;
  const links = new Map<string, string>();
  const linkRegex =
    /<a[^>]+href="([^"]*\/member_tag\/[^"]+)"[^>]*>(.*?)<\/a>/gsi;

  for (const match of section.matchAll(linkRegex)) {
    const rawHref = match[1]?.trim() ?? "";
    const label = decodeHtml(stripTags(match[2] ?? "")).trim();
    if (!PREFECTURES.includes(label as (typeof PREFECTURES)[number])) {
      continue;
    }
    links.set(label, new URL(rawHref, OFFICIAL_MEMBER_PAGE_URL).toString());
  }

  return links;
}

async function fetchPrefectureReality(
  prefecture: string,
  sourceUrl: string,
): Promise<PrefectureReality> {
  if (sourceUrl === "") {
    return {
      prefecture,
      sourceUrl: "",
      currentMembers: 0,
      prefecturalAssemblyMembers: 0,
      municipalAssemblyMembers: 0,
      members: [],
    };
  }

  try {
    const html = await fetchText(sourceUrl);
    const members = parsePrefectureMembers(prefecture, sourceUrl, html);
    const prefecturalAssemblyMembers = members.filter((member) =>
      member.assemblyCategory === "prefectural"
    ).length;
    const municipalAssemblyMembers = members.filter((member) =>
      member.assemblyCategory === "municipal"
    ).length;

    return {
      prefecture,
      sourceUrl,
      currentMembers: members.length,
      prefecturalAssemblyMembers,
      municipalAssemblyMembers,
      members,
    };
  } catch (error) {
    console.error(`Failed to fetch ${prefecture}:`, error);
    return {
      prefecture,
      sourceUrl,
      currentMembers: 0,
      prefecturalAssemblyMembers: 0,
      municipalAssemblyMembers: 0,
      members: [],
    };
  }
}

function parsePrefectureMembers(
  prefecture: string,
  sourceUrl: string,
  html: string,
): LocalLegislatorProfile[] {
  const detailUrlByName = parseMemberDetailLinks(html);
  const lines = extractPrefectureMemberLines(prefecture, html);
  const members: LocalLegislatorProfile[] = [];

  for (let index = 0; index <= lines.length - 5; index += 1) {
    const name = normalizeMemberName(lines[index]);
    const kana = lines[index + 1]?.trim() ?? "";
    const constituency = lines[index + 2]?.trim() ?? "";
    const assemblyLabel = lines[index + 3]?.trim() ?? "";
    const electionCountLabel = lines[index + 4]?.trim() ?? "";

    if (
      !looksLikeMemberBlock(
        name,
        kana,
        constituency,
        assemblyLabel,
        electionCountLabel,
      )
    ) {
      continue;
    }

    const assemblyCategory = inferAssemblyCategory(assemblyLabel);
    if (assemblyCategory === "other") {
      continue;
    }

    members.push({
      prefecture,
      sourceUrl,
      detailUrl: detailUrlByName.get(name) ?? "",
      name,
      kana,
      constituency,
      municipality: extractMunicipality(prefecture, constituency),
      assemblyLabel,
      assemblyCategory,
      electionCountLabel,
      birthDate: "",
      age: null,
      gender: "",
      profile: "",
    });
    index += 4;
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

function parseMemberDetailLinks(html: string): Map<string, string> {
  const links = new Map<string, string>();
  const linkRegex = /<a[^>]+href="([^"]*\/member\/[^"]+)"[^>]*>(.*?)<\/a>/gsi;

  for (const match of html.matchAll(linkRegex)) {
    const rawHref = match[1]?.trim() ?? "";
    const label = normalizeMemberName(decodeHtml(stripTags(match[2] ?? "")));
    if (rawHref === "" || label === "") {
      continue;
    }
    if (!links.has(label)) {
      links.set(label, new URL(rawHref, OFFICIAL_MEMBER_PAGE_URL).toString());
    }
  }

  return links;
}

function extractPrefectureMemberLines(
  prefecture: string,
  html: string,
): string[] {
  const text = normalizeWhitespace(stripHtmlToText(html));
  const section = sliceBetweenMarkers(
    text,
    [`${prefecture}縺ｮ蝨ｰ譁ｹ閾ｪ豐ｻ菴楢ｭｰ蜩｡`, "蝨ｰ譁ｹ閾ｪ豐ｻ菴楢ｭｰ蜩｡"],
    [
      `${prefecture}騾｣縺ｮ諠・ｱ`,
      "蝨ｰ譁ｹ閾ｪ豐ｻ菴楢ｭｰ蜩｡ LOCAL ASSEMBLY MEMBERS",
      "繧ｷ繧ｧ繧｢縺吶ｋ",
      "蝗ｽ豌第ｰ台ｸｻ蜈壼・蠑輯NS",
    ],
  );

  return section
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .filter((line) => !line.includes("顔写真"))
    .filter((line) => !line.includes("検索する"));
}

async function fetchMemberDetail(
  detailUrl: string,
  prefectureHint = "",
): Promise<LocalLegislatorProfile> {
  const normalizedUrl = detailUrl.trim();
  validateMemberDetailUrl(normalizedUrl);

  const html = await fetchText(normalizedUrl);
  const lines = normalizeWhitespace(stripHtmlToText(html))
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const constituency = extractField(lines, "驕ｸ謖吝玄");
  const electionCountLabel = extractField(lines, "蠖馴∈蝗樊焚");
  const birthDate = normalizeBirthDate(extractField(lines, "逕溷ｹｴ譛域律"));
  const gender = extractField(lines, "諤ｧ蛻･");
  const profile = extractMultilineField(lines, "邨梧ｭｴ", [
    "繧ｷ繧ｧ繧｢縺吶ｋ",
    "蝗ｽ豌第ｰ台ｸｻ蜈壼・蠑輯NS",
    "Copyright",
  ]);
  const constituencyIndex = lines.findIndex((line) =>
    line.startsWith("驕ｸ謖吝玄")
  );
  const assemblyLabel = findAssemblyLabel(lines, constituencyIndex);
  const name = "";
  const kana = "";
  const inferredPrefecture = inferPrefectureFromConstituency(constituency);
  const prefecture = inferredPrefecture || prefectureHint.trim();

  return {
    prefecture,
    sourceUrl: normalizedUrl,
    detailUrl: normalizedUrl,
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
  if (detailUrl === "") {
    throw new Error("Member detail URL is empty.");
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(detailUrl);
  } catch {
    throw new Error("Member detail URL is invalid.");
  }

  if (parsedUrl.hostname !== "new-kokumin.jp") {
    throw new Error("Only official new-kokumin.jp member pages are allowed.");
  }
  if (!parsedUrl.pathname.startsWith("/member/")) {
    throw new Error("Only official member detail paths are allowed.");
  }
}

async function fetchHistoricalResult(): Promise<HistoricalResult> {
  const [firstHalfText, secondHalfText] = await Promise.all([
    fetchText(OFFICIAL_2023_FIRST_HALF_URL).then((html) =>
      normalizeWhitespace(stripHtmlToText(html))
    ),
    fetchText(OFFICIAL_2023_SECOND_HALF_URL).then((html) =>
      normalizeWhitespace(stripHtmlToText(html))
    ),
  ]);

  const firstHalfWins = extractCount(
    firstHalfText,
    /([0-9０-９]+)\s*人[^\n]{0,40}当選/u,
  ) ?? 62;
  const secondHalfWins = extractCount(
    secondHalfText,
    /([0-9０-９]+)\s*人[^\n]{0,40}当選/u,
  ) ?? 121;
  const totalWins = extractCount(
    secondHalfText,
    /合計[^\d０-９]*([0-9０-９]+)\s*人/u,
  ) ?? firstHalfWins + secondHalfWins;

  return {
    firstHalfWins,
    secondHalfWins,
    totalWins,
  };
}

function parseOfficialElectionPrefectureLinks(html: string): Map<string, string> {
  const links = new Map<string, string>();
  const marker = "地方自治体選挙 候補予定者";
  const section = html.includes(marker)
    ? html.split(marker)[1]
    : html;
  const linkRegex =
    /<a[^>]+href="([^"]*post_type=election[^"]*prefectures=[^"]+)"[^>]*>(.*?)<\/a>/gsi;

  for (const match of section.matchAll(linkRegex)) {
    const rawHref = match[1]?.trim() ?? "";
    const label = decodeHtml(stripTags(match[2] ?? "")).trim();
    if (!PREFECTURES.includes(label as (typeof PREFECTURES)[number])) {
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
  const detailUrls = parseOfficialCandidateDetailLinks(sourceUrl, html);
  const lines = stripHtmlToText(html)
    .split("\n")
    .map((line) => normalizeWhitespace(line).trim())
    .filter((line) => line !== "");
  const startIndex = lines.findIndex((line) => line.includes(`${prefecture}縺ｮ蛟呵｣應ｺ亥ｮ夊・));
  if (startIndex < 0) {
    return [];
  }
  const endIndex = lines.findIndex((line, index) =>
    index > startIndex &&
    (line.includes("逵碁｣縺ｮ諠・ｱ") || line.includes("驛ｽ驕灘ｺ懃恁繧､繝ｳ繝・ャ繧ｯ繧ｹ"))
  );
  const sectionLines = lines.slice(
    startIndex + 1,
    endIndex > startIndex ? endIndex : lines.length,
  );
  const candidates: OfficialScheduledCandidate[] = [];

  for (let index = 0; index <= sectionLines.length - 5; index += 1) {
    const name = sectionLines[index];
    const kana = sectionLines[index + 1];
    const electionName = sectionLines[index + 2];
    const voteDate = normalizeOfficialVoteDate(sectionLines[index + 3]);
    const statusLabel = sectionLines[index + 4];
    if (
      !looksLikeOfficialCandidateBlock(
        name,
        kana,
        electionName,
        voteDate,
        statusLabel,
      )
    ) {
      continue;
    }

    candidates.push({
      prefecture,
      electionName,
      voteDate,
      name,
      statusLabel,
      detailUrl: detailUrls.get(name) ?? "",
      sourceUrl,
    });
  }

  return candidates;
}

function parseOfficialCandidateDetailLinks(
  sourceUrl: string,
  html: string,
): Map<string, string> {
  const links = new Map<string, string>();
  const linkRegex = /<a[^>]+href="([^"]*\/election\/[^"]+)"[^>]*>(.*?)<\/a>/gsi;
  for (const match of html.matchAll(linkRegex)) {
    const rawHref = match[1]?.trim() ?? "";
    const label = decodeHtml(stripTags(match[2] ?? "")).trim();
    if (label === "" || label.includes("鬘泌・逵・)) {
      continue;
    }
    links.set(label, new URL(rawHref, sourceUrl).toString());
  }
  return links;
}

function looksLikeOfficialCandidateBlock(
  name: string,
  kana: string,
  electionName: string,
  voteDate: string,
  statusLabel: string,
): boolean {
  if (
    name === "" ||
    kana === "" ||
    electionName === "" ||
    voteDate === "" ||
    statusLabel === ""
  ) {
    return false;
  }
  if (!looksLikeKanaLine(kana)) {
    return false;
  }
  if (!electionName.includes("驕ｸ謖・)) {
    return false;
  }
  if (!voteDate.startsWith("20")) {
    return false;
  }
  return statusLabel.includes("蜈ｬ隱・) || statusLabel.includes("謗ｨ阮ｦ");
}

async function fetchUpcomingLocalElectionSchedules(
  officialCandidates: OfficialScheduledCandidate[],
): Promise<LocalElectionScheduleEntry[]> {
  const scheduleHtml = await fetchText(ELECTION_SCHEDULE_URL);
  const overviewEntries = parseScheduleOverviewEntries(scheduleHtml);
  const today = startOfDay(new Date());
  const latestDate = addDays(today, SCHEDULE_WINDOW_DAYS);
  const upcomingEntries = overviewEntries
    .filter((entry) => {
      const voteDate = parseIsoDate(entry.voteDate);
      if (voteDate == null) {
        return false;
      }
      return voteDate.getTime() >= today.getTime() &&
        voteDate.getTime() <= latestDate.getTime();
    })
    .slice(0, SCHEDULE_MAX_ENTRIES);

  const detailed = await mapWithConcurrency(
    upcomingEntries,
    8,
    async (entry) => await enrichScheduleEntry(entry, officialCandidates),
  );

  return detailed.sort((left, right) => {
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
}

function parseScheduleOverviewEntries(html: string): ScheduleOverviewEntry[] {
  const lines = stripHtmlToText(html)
    .split("\n")
    .map((line) => normalizeWhitespace(line).trim())
    .filter((line) => line !== "");
  const detailUrlsByName = new Map<string, string[]>();
  const detailRegex = /<a[^>]+href="([^"]*\/local\/senkyo\/[^"]+)"[^>]*>(.*?)<\/a>/gsi;
  for (const match of html.matchAll(detailRegex)) {
    const label = decodeHtml(stripTags(match[2] ?? "")).trim();
    if (!label.includes("驕ｸ謖・)) {
      continue;
    }
    const resolvedUrl = new URL(
      match[1]?.trim() ?? "",
      ELECTION_SCHEDULE_URL,
    ).toString();
    const queue = detailUrlsByName.get(label) ?? [];
    queue.push(resolvedUrl);
    detailUrlsByName.set(label, queue);
  }

  const startIndex = lines.findIndex((line) => line === "螳滓命驕ｸ謖吩ｸ隕ｧ");
  if (startIndex < 0) {
    return [];
  }

  const entries: ScheduleOverviewEntry[] = [];
  let currentVoteDate = "";
  let currentElectionName = "";

  for (let index = startIndex + 1; index < lines.length; index += 1) {
    const line = lines[index];
    if (line === "閾ｪ豐ｻ菴薙°繧画爾縺・ || line === "My 驕ｸ謖・) {
      break;
    }
    if (line === "謚慕･ｨ譌･ 驕ｸ謖吝錐 驛ｽ驕灘ｺ懃恁" || /^\d+譛医・驕ｸ謖・\d+莉ｶ$/.test(line)) {
      continue;
    }
    if (/^\d{4}\/\d{2}\/\d{2}$/.test(line) || line === "譛ｪ螳・) {
      currentVoteDate = normalizeSlashedDate(line);
      currentElectionName = "";
      continue;
    }
    if (currentVoteDate === "") {
      continue;
    }
    if (currentElectionName === "") {
      currentElectionName = line;
      continue;
    }
    if (!isPrefectureName(line)) {
      currentElectionName = "";
      continue;
    }

    const queue = detailUrlsByName.get(currentElectionName) ?? [];
    const detailUrl = queue.shift() ?? "";
    detailUrlsByName.set(currentElectionName, queue);
    entries.push({
      electionName: currentElectionName,
      prefecture: line,
      voteDate: currentVoteDate,
      detailUrl,
    });
    currentElectionName = "";
  }

  return entries;
}

async function enrichScheduleEntry(
  entry: ScheduleOverviewEntry,
  officialCandidates: OfficialScheduledCandidate[],
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
  if (entry.detailUrl !== "") {
    try {
      const html = await fetchText(entry.detailUrl);
      const detail = parseScheduleDetail(html);
      announcementDate = detail.announcementDate;
      seatCount = detail.seatCount;
      totalCandidateCount = detail.totalCandidateCount;
    } catch (error) {
      console.error(`Failed to fetch schedule detail ${entry.detailUrl}:`, error);
    }
  }

  return {
    electionName: entry.electionName,
    prefecture: entry.prefecture,
    municipality: extractScheduleMunicipality(entry.electionName, entry.prefecture),
    electionCategory: inferElectionCategory(entry.electionName),
    voteDate: entry.voteDate,
    announcementDate,
    detailUrl: entry.detailUrl,
    officialCandidateSourceUrl: matchedCandidates[0]?.sourceUrl ??
      OFFICIAL_ELECTION_PAGE_URL,
    seatCount,
    totalCandidateCount,
    kokuminCandidateCount: matchedCandidates.length,
    kokuminCandidateNames: matchedCandidates.map((item) => item.name),
    kokuminCandidateStatuses: matchedCandidates.map((item) => item.statusLabel),
  };
}

function parseScheduleDetail(
  html: string,
): { announcementDate: string; seatCount: number; totalCandidateCount: number } {
  const text = normalizeWhitespace(stripHtmlToText(html));
  const announcementMatch = text.match(
    /蜻顔､ｺ譌･\s+([0-9・・・兢{4}蟷ｴ[0-9・・・兢{2}譛・0-9・・・兢{2}譌･|[0-9・・・兢{4}\/[0-9・・・兢{2}\/[0-9・・・兢{2}|譛ｪ螳・/u,
  );
  const countsMatch = text.match(
    /螳壽焚\/蛟呵｣懆・焚\s+([0-9・・・兢+)\s*\/\s*([0-9・・・兢+)/u,
  );
  return {
    announcementDate: normalizeJapaneseDate(announcementMatch?.[1] ?? ""),
    seatCount: countsMatch ? toInt(countsMatch[1]) : 0,
    totalCandidateCount: countsMatch ? toInt(countsMatch[2]) : 0,
  };
}

function matchOfficialCandidatesForSchedule(
  prefecture: string,
  electionName: string,
  voteDate: string,
  officialCandidates: OfficialScheduledCandidate[],
): OfficialScheduledCandidate[] {
  const normalizedPrefecture = prefecture.trim();
  const normalizedElectionName = normalizeElectionNameForMatch(electionName);
  const normalizedVoteDate = normalizeSlashedDate(voteDate);

  const byPrefecture = officialCandidates.filter((item) =>
    item.prefecture === normalizedPrefecture
  );
  const exact = byPrefecture.filter((item) =>
    normalizeElectionNameForMatch(item.electionName) === normalizedElectionName &&
    normalizeSlashedDate(item.voteDate) === normalizedVoteDate
  );
  if (exact.length > 0) {
    return exact;
  }

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

function normalizeOfficialVoteDate(value: string): string {
  const normalized = value.trim();
  const match = normalized.match(
    /^([0-9・・・兢{4})[.\/]([0-9・・・兢{1,2})[.\/]([0-9・・・兢{1,2})/,
  );
  if (!match) {
    return "";
  }
  const year = `${toInt(match[1])}`.padStart(4, "0");
  const month = `${toInt(match[2])}`.padStart(2, "0");
  const day = `${toInt(match[3])}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function normalizeJapaneseDate(value: string): string {
  const normalized = value.trim();
  if (normalized === "" || normalized === "譛ｪ螳・) {
    return "";
  }
  const match = normalized.match(
    /^([0-9・・・兢{4})蟷ｴ([0-9・・・兢{1,2})譛・[0-9・・・兢{1,2})譌･/u,
  );
  if (!match) {
    return normalizeSlashedDate(normalized);
  }
  const year = `${toInt(match[1])}`.padStart(4, "0");
  const month = `${toInt(match[2])}`.padStart(2, "0");
  const day = `${toInt(match[3])}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function normalizeSlashedDate(value: string): string {
  const normalized = value.trim();
  if (normalized === "" || normalized === "譛ｪ螳・) {
    return "";
  }
  const match = normalized.match(
    /^([0-9・・・兢{4})[\/\-]([0-9・・・兢{1,2})[\/\-]([0-9・・・兢{1,2})$/,
  );
  if (!match) {
    return normalized.replace(/\./g, "-");
  }
  const year = `${toInt(match[1])}`.padStart(4, "0");
  const month = `${toInt(match[2])}`.padStart(2, "0");
  const day = `${toInt(match[3])}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function parseIsoDate(value: string): Date | null {
  const normalized = normalizeSlashedDate(value);
  if (normalized === "") {
    return null;
  }
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

function extractScheduleMunicipality(
  electionName: string,
  prefecture: string,
): string {
  const suffixes = [
    "遏･莠矩∈謖・,
    "逵瑚ｭｰ莨夊ｭｰ蜩｡陬懈ｬ驕ｸ謖・,
    "蠎懆ｭｰ莨夊ｭｰ蜩｡陬懈ｬ驕ｸ謖・,
    "驛ｽ隴ｰ莨夊ｭｰ蜩｡陬懈ｬ驕ｸ謖・,
    "驕楢ｭｰ莨夊ｭｰ蜩｡陬懈ｬ驕ｸ謖・,
    "隴ｰ莨夊ｭｰ蜩｡陬懈ｬ驕ｸ謖・,
    "隴ｰ莨夊ｭｰ蜩｡蜀埼∈謖・,
    "隴ｰ莨夊ｭｰ蜩｡蠅怜藤驕ｸ謖・,
    "隴ｰ莨夊ｭｰ蜩｡驕ｸ謖・,
    "蟶る聞驕ｸ謖・,
    "逕ｺ髟ｷ驕ｸ謖・,
    "譚鷹聞驕ｸ謖・,
    "蛹ｺ髟ｷ驕ｸ謖・,
  ];
  for (const suffix of suffixes) {
    if (electionName.endsWith(suffix)) {
      const municipality = electionName.slice(0, -suffix.length).trim();
      return municipality === "" ? prefecture : municipality;
    }
  }
  return prefecture;
}

function inferElectionCategory(electionName: string): string {
  if (/(遏･莠弓蟶る聞|逕ｺ髟ｷ|譚鷹聞|蛹ｺ髟ｷ)驕ｸ謖・u.test(electionName)) {
    return "鬥夜聞驕ｸ謖・;
  }
  if (/隴ｰ莨夊ｭｰ蜩｡/u.test(electionName)) {
    return "蝨ｰ譁ｹ隴ｰ莨夐∈謖・;
  }
  return "蝨ｰ譁ｹ驕ｸ謖・;
}

function normalizeElectionNameForMatch(value: string): string {
  return value
    .replace(/[ 縲]/g, "")
    .replace(/[・茨ｼ・)]/g, "")
    .replace(/莠域Φ縺輔ｌ繧矩｡斐・繧・g, "")
    .trim();
}

function scheduleSeverity(entry: LocalElectionScheduleEntry): number {
  if (entry.kokuminCandidateCount === 0) {
    return 0;
  }
  if (entry.kokuminCandidateCount === 1) {
    return 1;
  }
  return 2;
}

async function buildAiAnalysis(
  snapshot: {
    baselineCurrentLocalMembers: number;
    officialCurrentLocalMembers: number;
    targetLocalMembers: number;
    baselineNetIncreaseRequired: number;
    actualNetIncreaseRequired: number;
    official2023FirstHalfWins: number;
    official2023SecondHalfWins: number;
    official2023TotalWins: number;
    prefectures: Array<{
      prefecture: string;
      sourceUrl: string;
      currentMembers: number;
      prefecturalAssemblyMembers: number;
      municipalAssemblyMembers: number;
    }>;
    members: LocalLegislatorProfile[];
  },
): Promise<AiAnalysis> {
  if (OPENAI_API_KEY === "") {
    return buildFallbackAnalysis(snapshot);
  }

  const topPrefectures = [...snapshot.prefectures]
    .sort((a, b) => b.currentMembers - a.currentMembers)
    .slice(0, 10);

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "縺ゅ↑縺溘・譌･譛ｬ縺ｮ驕ｸ謖吶ョ繝ｼ繧ｿ繧｢繝翫Μ繧ｹ繝医〒縺吶ゆｸ弱∴繧峨ｌ縺溷・蠑上ョ繝ｼ繧ｿ縺縺代ｒ菴ｿ縺｣縺ｦ縲∽ｺ句ｮ溘・繝ｼ繧ｹ縺ｮ遏ｭ縺・ｦ∫ｴ・ｒ菴懈・縺励※縺上□縺輔＞縲・SON縺ｧ summary, alerts, strategicNotes 繧定ｿ斐＠縺ｦ縺上□縺輔＞縲・,
        },
        {
          role: "user",
          content: JSON.stringify({
            baselineCurrentLocalMembers: snapshot.baselineCurrentLocalMembers,
            officialCurrentLocalMembers: snapshot.officialCurrentLocalMembers,
            targetLocalMembers: snapshot.targetLocalMembers,
            baselineNetIncreaseRequired: snapshot.baselineNetIncreaseRequired,
            actualNetIncreaseRequired: snapshot.actualNetIncreaseRequired,
            official2023FirstHalfWins: snapshot.official2023FirstHalfWins,
            official2023SecondHalfWins: snapshot.official2023SecondHalfWins,
            official2023TotalWins: snapshot.official2023TotalWins,
            rosterCount: snapshot.members.length,
            topPrefectures,
          }),
        },
      ],
    }),
  });

  if (!response.ok) {
    console.error("AI analysis failed:", await response.text());
    return buildFallbackAnalysis(snapshot);
  }

  const json = await response.json();
  const content = json.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim() === "") {
    return buildFallbackAnalysis(snapshot);
  }

  try {
    const parsed = JSON.parse(content);
    const fallback = buildFallbackAnalysis(snapshot);
    const parsedScheduleAlerts = sanitizeLines(parsed.scheduleAlerts, 4);
    return {
      summary: sanitizeLine(parsed.summary) || fallback.summary,
      alerts: sanitizeLines(parsed.alerts, 3),
      strategicNotes: sanitizeLines(parsed.strategicNotes, 3),
      scheduleSummary:
        sanitizeLine(parsed.scheduleSummary) || fallback.scheduleSummary,
      scheduleAlerts: parsedScheduleAlerts.length > 0
        ? parsedScheduleAlerts
        : fallback.scheduleAlerts,
    };
  } catch {
    return buildFallbackAnalysis(snapshot);
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
  prefectures: Array<{
    prefecture: string;
    sourceUrl: string;
    currentMembers: number;
    prefecturalAssemblyMembers: number;
    municipalAssemblyMembers: number;
  }>;
  members: LocalLegislatorProfile[];
}): AiAnalysis {
  const delta = snapshot.officialCurrentLocalMembers -
    snapshot.baselineCurrentLocalMembers;
  const deltaLabel = delta === 0
    ? "蝓ｺ貅悶・340莠ｺ縺ｨ蜷梧ｰｴ貅・
    : delta > 0
    ? `蝓ｺ貅匁ｯ斐〒+${delta}莠ｺ`
    : `蝓ｺ貅匁ｯ斐〒${delta}莠ｺ`;
  const topPrefectures = [...snapshot.prefectures]
    .sort((a, b) => b.currentMembers - a.currentMembers)
    .slice(0, 3)
    .map((item) => `${item.prefecture}${item.currentMembers}莠ｺ`);
  const scheduleEntries = (
    snapshot as { upcomingSchedules?: LocalElectionScheduleEntry[] }
  ).upcomingSchedules ?? [];
  const redSchedules = scheduleEntries.filter((item) =>
    item.kokuminCandidateCount === 0
  );
  const yellowSchedules = scheduleEntries.filter((item) =>
    item.kokuminCandidateCount === 1
  );
  const nearSchedules = scheduleEntries.slice(0, 3).map((item) =>
    `${item.voteDate} ${item.prefecture} ${item.electionName}(${item.kokuminCandidateCount}莠ｺ)`
  );

  return {
    summary:
      `蜈ｬ蠑丞慍譁ｹ隴ｰ蜩｡繝壹・繧ｸ縺ｮ髮・ｨ医〒縺ｯ蝨ｰ譁ｹ隴ｰ蜩｡縺ｯ ${snapshot.officialCurrentLocalMembers} 莠ｺ縺ｧ縲～ +
      `700莠ｺ縺ｾ縺ｧ谿九ｊ ${snapshot.actualNetIncreaseRequired} 莠ｺ縺ｧ縺吶・{deltaLabel}縺ｧ縺吶Ａ,
    alerts: [
      `2023蟷ｴ螳溽ｸｾ縺ｯ蜑榊濠 ${snapshot.official2023FirstHalfWins}縲∝ｾ悟濠 ${snapshot.official2023SecondHalfWins}縲∝粋險・${snapshot.official2023TotalWins} 縺ｧ縲∽ｻ雁屓縺ｮ蠢・ｦ∫ｴ泌｢苓ｦ乗ｨ｡繧剃ｸ句屓繧翫∪縺吶Ａ,
      `迴ｾ閨ｷ蝨ｰ譁ｹ隴ｰ蜩｡縺ｮ蛟狗･ｨ荳隕ｧ縺ｯ ${snapshot.members.length} 莠ｺ蛻・ｒ蜿門ｾ励〒縺阪※縺・∪縺吶ら樟閨ｷ邯ｭ謖∫岼讓吶→譛域ｬ｡KPI繧堤恁騾｣蜊倅ｽ阪〒謖√▽蜑肴署縺ｯ螟峨ｏ繧翫∪縺帙ｓ縲Ａ,
      topPrefectures.length === 0
        ? "驛ｽ驕灘ｺ懃恁蛻･縺ｮ荳贋ｽ咲恁騾｣縺ｯ縺ｾ縺蜿門ｾ励〒縺阪※縺・∪縺帙ｓ縲ょ・蠑上・繝ｼ繧ｸ縺ｮ讒矩螟画峩繧堤｢ｺ隱阪＠縺ｦ縺上□縺輔＞縲・
        : `迴ｾ閨ｷ謨ｰ縺ｮ荳贋ｽ阪・ ${
          topPrefectures.join("縲・)
        } 縺ｧ縺吶る㍾轤ｹ逵碁｣縺ｮ譁ｰ莠ｺ謫∫ｫ九→謗･謌ｦ蛹ｺ謾ｯ謠ｴ縺ｮ驟榊・縺ｫ菴ｿ縺医∪縺吶Ａ,
    ],
    strategicNotes: [
      "譛譁ｰ螳滓焚縺ｯ dashboard.currentLocalMembers 縺ｫ蜷梧悄縺ｧ縺阪ｋ縺ｮ縺ｧ縲∝ｷ･遞玖｡ｨ縺ｮ繝吶・繧ｹ繝ｩ繧､繝ｳ譖ｴ譁ｰ繧呈怦谺｡驕狗畑縺ｫ邨・∩霎ｼ繧薙〒縺上□縺輔＞縲・,
      "隴ｰ蜩｡荳隕ｧ縺ｯ驛ｽ驕灘ｺ懃恁蛻･縺ｫ蜿門ｾ励〒縺阪ｋ縺溘ａ縲・㍾轤ｹ閾ｪ豐ｻ菴捺焚縺ｨ譁ｰ莠ｺ謫∫ｫ区焚縺ｮ蜑ｲ繧頑険繧翫ｒ逵碁｣縺斐→縺ｫ謖√◆縺帙ｋ邂｡逅・梛驕ｸ謖吶↓蜷代＞縺ｦ縺・∪縺吶・,
      "蟷ｴ鮨｢繧・ｵ梧ｭｴ縺ｯ隧ｳ邏ｰ繝壹・繧ｸ縺ｫ譏手ｨ倥′縺ゅｋ蝣ｴ蜷医・縺ｿ霑ｽ蜉蜿門ｾ励〒縺阪∪縺吶よｧ蛻･縺ｯ蜈ｬ蠑剰ｨ倩ｼ峨′縺ｪ縺・剞繧願｡ｨ遉ｺ縺励↑縺・°逕ｨ縺ｫ縺励※縺上□縺輔＞縲・,
    ],
    scheduleSummary: scheduleEntries.length === 0
      ? "莉雁ｾ後・蝨ｰ譁ｹ驕ｸ謖呎律遞九・蜿門ｾ励〒縺阪∪縺帙ｓ縺ｧ縺励◆縲・
      : `莉雁ｾ・${scheduleEntries.length} 莉ｶ縺ｮ蝨ｰ譁ｹ驕ｸ謖吶ｒ逶｣隕紋ｸｭ縺ｧ縺吶よ悴謫∫ｫ・${redSchedules.length} 莉ｶ縲∝腰鬨・${yellowSchedules.length} 莉ｶ縺ｧ縺吶Ａ,
    scheduleAlerts: [
      ...(
        redSchedules.length > 0
          ? [
            `譛ｪ謫∫ｫ・${redSchedules.length} 莉ｶ: ${
              redSchedules.slice(0, 3).map((item) =>
                `${item.prefecture} ${item.electionName}`
              ).join(" / ")
            }`,
          ]
          : []
      ),
      ...(
        yellowSchedules.length > 0
          ? [
            `蜊倬ｨ・${yellowSchedules.length} 莉ｶ: ${
              yellowSchedules.slice(0, 3).map((item) =>
                `${item.prefecture} ${item.electionName}`
              ).join(" / ")
            }`,
          ]
          : []
      ),
      ...(nearSchedules.length > 0 ? [`逶ｴ霑第律遞・ ${nearSchedules.join(" / ")}`] : []),
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

  const categoryRank = (value: AssemblyCategory): number => {
    switch (value) {
      case "prefectural":
        return 0;
      case "municipal":
        return 1;
      default:
        return 2;
    }
  };
  const categoryCompare = categoryRank(left.assemblyCategory) -
    categoryRank(right.assemblyCategory);
  if (categoryCompare !== 0) {
    return categoryCompare;
  }

  return left.name.localeCompare(right.name, "ja");
}

function looksLikeMemberBlock(
  name: string,
  kana: string,
  constituency: string,
  assemblyLabel: string,
  electionCountLabel: string,
): boolean {
  if (
    name === "" ||
    kana === "" ||
    constituency === "" ||
    assemblyLabel === "" ||
    electionCountLabel === ""
  ) {
    return false;
  }
  if (
    name.includes("蝨ｰ譁ｹ閾ｪ豐ｻ菴楢ｭｰ蜩｡") ||
    name.includes("逵碁｣縺ｮ諠・ｱ") ||
    name.includes("繧ｷ繧ｧ繧｢縺吶ｋ")
  ) {
    return false;
  }
  if (!/^[縺・繧悶ぃ-繝ｺ繝ｼ繝ｻ\s]+$/u.test(kana)) {
    return false;
  }
  if (!assemblyLabel.includes("隴ｰ蜩｡")) {
    return false;
  }
  return /[0-9・・・兢+譛・.test(electionCountLabel);
}

function inferAssemblyCategory(assemblyLabel: string): AssemblyCategory {
  if (
    assemblyLabel.includes("逵瑚ｭｰ莨・) ||
    assemblyLabel.includes("蠎懆ｭｰ莨・) ||
    assemblyLabel.includes("驛ｽ隴ｰ莨・) ||
    assemblyLabel.includes("驕楢ｭｰ莨・)
  ) {
    return "prefectural";
  }
  if (
    assemblyLabel.includes("蟶りｭｰ莨・) ||
    assemblyLabel.includes("蛹ｺ隴ｰ莨・) ||
    assemblyLabel.includes("逕ｺ隴ｰ莨・) ||
    assemblyLabel.includes("譚題ｭｰ莨・)
  ) {
    return "municipal";
  }
  return "other";
}

function extractMunicipality(prefecture: string, constituency: string): string {
  const normalizedPrefecture = prefecture.trim();
  const normalizedConstituency = constituency.trim();
  if (
    normalizedPrefecture !== "" &&
    normalizedConstituency.startsWith(normalizedPrefecture)
  ) {
    return normalizedConstituency.slice(normalizedPrefecture.length).trim();
  }
  return normalizedConstituency;
}

function inferPrefectureFromConstituency(constituency: string): string {
  const normalized = constituency.trim();
  for (const prefecture of PREFECTURES) {
    if (normalized.startsWith(prefecture)) {
      return prefecture;
    }
  }
  return "";
}

function parseNameAndKana(line: string): { name: string; kana: string } {
  const normalized = normalizeWhitespace(line).trim();
  if (normalized === "") {
    return { name: "", kana: "" };
  }

  const match = normalized.match(/^(.*?)[\s縲]+([縺・繧悶ぃ-繝ｺ繝ｼ繝ｻ\s縲]+)$/u);
  if (!match) {
    return { name: normalized, kana: "" };
  }

  return {
    name: match[1].trim(),
    kana: match[2].trim(),
  };
}

function looksLikeKanaLine(value: string): boolean {
  return /^[縺・繧悶ぃ-繝ｺ繝ｼ繝ｻ\s]+$/u.test(value.trim());
}

// deno-lint-ignore no-unused-vars
function extractMemberIdentity(
  lines: string[],
  fromIndex: number,
): { name: string; kana: string } {
  if (fromIndex > 1) {
    for (
      let index = Math.max(0, fromIndex - 4);
      index < fromIndex - 1;
      index += 1
    ) {
      const candidateName = lines[index].trim();
      const candidateKana = lines[index + 1].trim();
      if (
        candidateName !== "" &&
        candidateKana !== "" &&
        !looksLikeKanaLine(candidateName) &&
        looksLikeKanaLine(candidateKana)
      ) {
        return {
          name: candidateName,
          kana: candidateKana,
        };
      }
    }
  }

  return parseNameAndKana(
    fromIndex > 0 ? lines[fromIndex - 1] : "",
  );
}

function findAssemblyLabel(lines: string[], fromIndex: number): string {
  const end = fromIndex < 0 ? Math.min(lines.length, 10) : fromIndex;
  for (let index = Math.max(0, end - 5); index < end; index += 1) {
    if (lines[index].includes("隴ｰ蜩｡")) {
      return lines[index];
    }
  }
  return "";
}

function extractField(lines: string[], label: string): string {
  const directPrefix = `${label} `;
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.startsWith(directPrefix)) {
      return line.slice(directPrefix.length).trim();
    }
    if (line === label && index + 1 < lines.length) {
      return lines[index + 1].trim();
    }
  }
  return "";
}

function extractMultilineField(
  lines: string[],
  label: string,
  stopMarkers: string[],
): string {
  const startIndex = lines.findIndex((line) => line === label);
  if (startIndex < 0) {
    return "";
  }

  const collected: string[] = [];
  for (let index = startIndex + 1; index < lines.length; index += 1) {
    const line = lines[index];
    if (line === "") {
      continue;
    }
    if (stopMarkers.some((marker) => line.includes(marker))) {
      break;
    }
    collected.push(line);
  }

  return collected.join(" ").trim();
}

function normalizeBirthDate(value: string): string {
  const normalized = value.trim();
  if (normalized === "") {
    return "";
  }
  const match = normalized.match(
    /^([0-9・・・兢{4})[\/\-蟷ｴ]([0-9・・・兢{1,2})[\/\-譛・([0-9・・・兢{1,2})/u,
  );
  if (!match) {
    return normalized;
  }
  const year = toInt(match[1]);
  const month = `${toInt(match[2])}`.padStart(2, "0");
  const day = `${toInt(match[3])}`.padStart(2, "0");
  return `${year}/${month}/${day}`;
}

function calculateAge(birthDate: string): number | null {
  if (birthDate === "") {
    return null;
  }

  const match = birthDate.match(/^(\d{4})\/(\d{2})\/(\d{2})$/);
  if (!match) {
    return null;
  }

  const year = Number.parseInt(match[1], 10);
  const month = Number.parseInt(match[2], 10);
  const day = Number.parseInt(match[3], 10);
  const today = new Date();
  let age = today.getFullYear() - year;
  const hasBirthdayPassed = today.getMonth() + 1 > month ||
    (today.getMonth() + 1 === month && today.getDate() >= day);
  if (!hasBirthdayPassed) {
    age -= 1;
  }
  return age >= 0 ? age : null;
}

function sliceBetweenMarkers(
  value: string,
  startMarkers: string[],
  endMarkers: string[],
): string {
  let sliced = value;
  const startIndex = findFirstIndex(sliced, startMarkers);
  if (startIndex >= 0) {
    const startMarker = startMarkers.find((marker) =>
      sliced.indexOf(marker) === startIndex
    );
    if (startMarker) {
      sliced = sliced.slice(startIndex + startMarker.length);
    }
  }

  const endIndex = findFirstIndex(sliced, endMarkers);
  if (endIndex >= 0) {
    sliced = sliced.slice(0, endIndex);
  }

  return sliced;
}

function findFirstIndex(value: string, markers: string[]): number {
  let best = -1;
  for (const marker of markers) {
    const index = value.indexOf(marker);
    if (index >= 0 && (best < 0 || index < best)) {
      best = index;
    }
  }
  return best;
}

function normalizeMemberName(value: string): string {
  return normalizeWhitespace(value).trim();
}

function extractCount(text: string, pattern: RegExp): number | null {
  const match = text.match(pattern);
  if (!match || match.length < 2) {
    return null;
  }
  return toInt(match[1]);
}

function toInt(value: string): number {
  const normalized = toAsciiDigits(value).replace(/[^0-9]/g, "");
  return normalized === "" ? 0 : Number.parseInt(normalized, 10);
}

function toAsciiDigits(value: string): string {
  return value.replace(
    /[・・・兢/g,
    (digit) => String.fromCharCode(digit.charCodeAt(0) - 0xfee0),
  );
}

function stripTags(value: string): string {
  return value.replace(/<[^>]+>/g, " ");
}

function stripHtmlToText(html: string): string {
  return decodeHtml(
    html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
      .replace(/<[^>]+>/g, "\n"),
  );
}

function decodeHtml(value: string): string {
  return value
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&ensp;/g, " ")
    .replace(/&emsp;/g, " ")
    .replace(/&#x2f;/gi, "/");
}

function normalizeWhitespace(value: string): string {
  return value
    .replace(/\r/g, "\n")
    .replace(/[ \t\u3000]+/g, " ")
    .replace(/\n{2,}/g, "\n")
    .trim();
}

function sanitizeLine(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function sanitizeLines(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => sanitizeLine(item))
    .filter((item) => item.length > 0)
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

