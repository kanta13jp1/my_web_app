import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

const OFFICIAL_MEMBER_PAGE_URL = "https://new-kokumin.jp/member";
const OFFICIAL_2023_FIRST_HALF_URL =
  "https://new-kokumin.jp/news/election/20230410_election";
const OFFICIAL_2023_SECOND_HALF_URL =
  "https://new-kokumin.jp/news/election/20230423_1";

const TARGET_LOCAL_MEMBERS = 700;
const BASELINE_CURRENT_LOCAL_MEMBERS = 340;

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
    const prefectureLinkMap = parsePrefectureLinks(memberPageHtml);
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
      sources: [
        {
          label: "国民民主党 地方自治体議員一覧",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_members",
          note: "都道府県ページから現職地方議員数と個票一覧を取得しています。",
        },
        {
          label: "国民民主党 地方自治体議員詳細ページ",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_member_profiles",
          note:
            "年齢と簡易プロフィールは議員ごとの詳細ページに明記がある場合だけ個別取得します。",
        },
        {
          label: "2023 統一地方選 前半戦結果",
          url: OFFICIAL_2023_FIRST_HALF_URL,
          category: "official_2023_first_half",
          note: "公式ニュースリリースから当選人数を確認しています。",
        },
        {
          label: "2023 統一地方選 後半戦結果",
          url: OFFICIAL_2023_SECOND_HALF_URL,
          category: "official_2023_second_half",
          note: "公式ニュースリリースから当選人数を確認しています。",
        },
      ],
      prefectures,
      members,
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
  const section = html.includes("地方自治体議員 LOCAL ASSEMBLY MEMBERS")
    ? html.split("地方自治体議員 LOCAL ASSEMBLY MEMBERS")[1]
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
    [`${prefecture}の地方自治体議員`, "地方自治体議員"],
    [
      `${prefecture}連の情報`,
      "地方自治体議員 LOCAL ASSEMBLY MEMBERS",
      "シェアする",
      "国民民主党公式SNS",
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
  const constituency = extractField(lines, "選挙区");
  const electionCountLabel = extractField(lines, "当選回数");
  const birthDate = normalizeBirthDate(extractField(lines, "生年月日"));
  const gender = extractField(lines, "性別");
  const profile = extractMultilineField(lines, "経歴", [
    "シェアする",
    "国民民主党公式SNS",
    "Copyright",
  ]);
  const constituencyIndex = lines.findIndex((line) =>
    line.startsWith("選挙区")
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
    /([0-9０-９]+)名の国民民主党公認・推薦候補が当選/,
  ) ?? 62;
  const secondHalfWins = extractCount(
    secondHalfText,
    /([0-9０-９]+)名の国民民主党公認・推薦候補が当選/,
  ) ?? 121;
  const totalWins = extractCount(
    secondHalfText,
    /前半戦・後半戦の合計[^\d０-９]*([0-9０-９]+)名が当選/,
  ) ?? firstHalfWins + secondHalfWins;

  return {
    firstHalfWins,
    secondHalfWins,
    totalWins,
  };
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
            "あなたは日本の選挙データアナリストです。与えられた公式データだけを使って、事実ベースの短い要約を作成してください。JSONで summary, alerts, strategicNotes を返してください。",
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
    return {
      summary: sanitizeLine(parsed.summary) || fallback.summary,
      alerts: sanitizeLines(parsed.alerts, 3),
      strategicNotes: sanitizeLines(parsed.strategicNotes, 3),
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
    ? "基準の340人と同水準"
    : delta > 0
    ? `基準比で+${delta}人`
    : `基準比で${delta}人`;
  const topPrefectures = [...snapshot.prefectures]
    .sort((a, b) => b.currentMembers - a.currentMembers)
    .slice(0, 3)
    .map((item) => `${item.prefecture}${item.currentMembers}人`);

  return {
    summary:
      `公式地方議員ページの集計では地方議員は ${snapshot.officialCurrentLocalMembers} 人で、` +
      `700人まで残り ${snapshot.actualNetIncreaseRequired} 人です。${deltaLabel}です。`,
    alerts: [
      `2023年実績は前半 ${snapshot.official2023FirstHalfWins}、後半 ${snapshot.official2023SecondHalfWins}、合計 ${snapshot.official2023TotalWins} で、今回の必要純増規模を下回ります。`,
      `現職地方議員の個票一覧は ${snapshot.members.length} 人分を取得できています。現職維持目標と月次KPIを県連単位で持つ前提は変わりません。`,
      topPrefectures.length === 0
        ? "都道府県別の上位県連はまだ取得できていません。公式ページの構造変更を確認してください。"
        : `現職数の上位は ${
          topPrefectures.join("、")
        } です。重点県連の新人擁立と接戦区支援の配分に使えます。`,
    ],
    strategicNotes: [
      "最新実数は dashboard.currentLocalMembers に同期できるので、工程表のベースライン更新を月次運用に組み込んでください。",
      "議員一覧は都道府県別に取得できるため、重点自治体数と新人擁立数の割り振りを県連ごとに持たせる管理型選挙に向いています。",
      "年齢や経歴は詳細ページに明記がある場合のみ追加取得できます。性別は公式記載がない限り表示しない運用にしてください。",
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
    name.includes("地方自治体議員") ||
    name.includes("県連の情報") ||
    name.includes("シェアする")
  ) {
    return false;
  }
  if (!/^[ぁ-ゖァ-ヺー・\s]+$/u.test(kana)) {
    return false;
  }
  if (!assemblyLabel.includes("議員")) {
    return false;
  }
  return /[0-9０-９]+期/.test(electionCountLabel);
}

function inferAssemblyCategory(assemblyLabel: string): AssemblyCategory {
  if (
    assemblyLabel.includes("県議会") ||
    assemblyLabel.includes("府議会") ||
    assemblyLabel.includes("都議会") ||
    assemblyLabel.includes("道議会")
  ) {
    return "prefectural";
  }
  if (
    assemblyLabel.includes("市議会") ||
    assemblyLabel.includes("区議会") ||
    assemblyLabel.includes("町議会") ||
    assemblyLabel.includes("村議会")
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

  const match = normalized.match(/^(.*?)[\s　]+([ぁ-ゖァ-ヺー・\s　]+)$/u);
  if (!match) {
    return { name: normalized, kana: "" };
  }

  return {
    name: match[1].trim(),
    kana: match[2].trim(),
  };
}

function looksLikeKanaLine(value: string): boolean {
  return /^[ぁ-ゖァ-ヺー・\s]+$/u.test(value.trim());
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
    if (lines[index].includes("議員")) {
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
    /^([0-9０-９]{4})[\/\-年]([0-9０-９]{1,2})[\/\-月]([0-9０-９]{1,2})/u,
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
    /[０-９]/g,
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
