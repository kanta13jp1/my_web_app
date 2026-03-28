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
];

interface PrefectureReality {
  prefecture: string;
  sourceUrl: string;
  currentMembers: number;
  prefecturalAssemblyMembers: number;
  municipalAssemblyMembers: number;
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "GET" && req.method !== "POST") {
      throw new Error("Method not allowed. Use GET or POST.");
    }

    let includeAiSummary = true;
    if (req.method === "POST") {
      try {
        const body = await req.json();
        includeAiSummary = body?.includeAiSummary !== false;
      } catch {
        includeAiSummary = true;
      }
    } else {
      const url = new URL(req.url);
      includeAiSummary = url.searchParams.get("includeAiSummary") !== "false";
    }

    const memberPageHtml = await fetchText(OFFICIAL_MEMBER_PAGE_URL);
    const prefectureLinkMap = parsePrefectureLinks(memberPageHtml);
    const prefectures = await mapWithConcurrency(
      PREFECTURES,
      6,
      async (prefecture) => {
        const sourceUrl = prefectureLinkMap.get(prefecture) ?? "";
        return await fetchPrefectureReality(prefecture, sourceUrl);
      },
    );

    const officialCurrentLocalMembers = prefectures.reduce((sum, item) => {
      return sum + item.currentMembers;
    }, 0);
    const historical = await fetchHistoricalResult();
    const snapshotBase = {
      fetchedAt: new Date().toISOString(),
      baselineCurrentLocalMembers: BASELINE_CURRENT_LOCAL_MEMBERS,
      officialCurrentLocalMembers,
      targetLocalMembers: TARGET_LOCAL_MEMBERS,
      baselineNetIncreaseRequired:
        TARGET_LOCAL_MEMBERS - BASELINE_CURRENT_LOCAL_MEMBERS,
      actualNetIncreaseRequired: Math.max(
        0,
        TARGET_LOCAL_MEMBERS - officialCurrentLocalMembers,
      ),
      official2023FirstHalfWins: historical.firstHalfWins,
      official2023SecondHalfWins: historical.secondHalfWins,
      official2023TotalWins: historical.totalWins,
      sources: [
        {
          label: "国民民主党 議員ページ",
          url: OFFICIAL_MEMBER_PAGE_URL,
          category: "official_members",
          note: "地方自治体議員の都道府県別ページを巡回して集計",
        },
        {
          label: "2023 統一地方選 前半戦結果",
          url: OFFICIAL_2023_FIRST_HALF_URL,
          category: "official_2023_first_half",
          note: "公式結果ページから当選者数を抽出",
        },
        {
          label: "2023 統一地方選 後半戦結果",
          url: OFFICIAL_2023_SECOND_HALF_URL,
          category: "official_2023_second_half",
          note: "公式結果ページから当選者数を抽出",
        },
      ],
      prefectures,
    };

    const aiAnalysis = includeAiSummary
      ? await buildAiAnalysis(snapshotBase)
      : buildFallbackAnalysis(snapshotBase);

    return new Response(
      JSON.stringify({
        success: true,
        snapshot: {
          ...snapshotBase,
          aiSummary: aiAnalysis.summary,
          aiAlerts: aiAnalysis.alerts,
          aiStrategicNotes: aiAnalysis.strategicNotes,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("local-election-intelligence failed:", message);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function fetchText(url: string): Promise<string> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "User-Agent":
          "my_web_app local-election-intelligence/1.0 (+https://my-web-app-b67f4.web.app/)",
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
  const section = html.includes("都道府県別所属議員")
    ? html.split("都道府県別所属議員")[1]
    : html;
  const links = new Map<string, string>();
  const linkRegex = /<a[^>]+href="([^"]*\/member_tag\/[^"]+)"[^>]*>(.*?)<\/a>/gsi;

  for (const match of section.matchAll(linkRegex)) {
    const rawHref = match[1]?.trim() ?? "";
    const label = decodeHtml(stripTags(match[2] ?? "")).trim();
    if (!PREFECTURES.includes(label) || rawHref === "") {
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
    };
  }

  try {
    const html = await fetchText(sourceUrl);
    const text = normalizeWhitespace(stripHtmlToText(html));
    const marker = `${prefecture}の地方自治体議員`;
    const localSection = text.includes(marker)
      ? text.split(marker)[1]
      : text.includes("地方自治体議員")
      ? text.split("地方自治体議員")[1]
      : text;

    const prefecturalAssemblyMembers = countMatches(
      localSection,
      /都議会議員|道議会議員|府議会議員|県議会議員/g,
    );
    const municipalAssemblyMembers = countMatches(
      localSection,
      /市議会議員|区議会議員|町議会議員|村議会議員/g,
    );

    return {
      prefecture,
      sourceUrl,
      currentMembers: prefecturalAssemblyMembers + municipalAssemblyMembers,
      prefecturalAssemblyMembers,
      municipalAssemblyMembers,
    };
  } catch (error) {
    console.error(`Failed to fetch ${prefecture}:`, error);
    return {
      prefecture,
      sourceUrl,
      currentMembers: 0,
      prefecturalAssemblyMembers: 0,
      municipalAssemblyMembers: 0,
    };
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

  const firstHalfWins =
    extractCount(
      firstHalfText,
      /([0-9０-９]+)名の国民民主党公認・推薦候補者が当選/,
    ) ?? 62;
  const secondHalfWins =
    extractCount(
      secondHalfText,
      /([0-9０-９]+)名の国民民主党公認・推薦候補者が当選/,
    ) ?? 121;
  const totalWins =
    extractCount(
      secondHalfText,
      /前半戦・後半戦の合計[^0-9０-９]*([0-9０-９]+)名が当選/,
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
    prefectures: PrefectureReality[];
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
            "あなたは選挙データアナリストです。入力された公式データだけを使って、短く実務向けに要約してください。推測の書き足しは禁止です。JSONで summary, alerts, strategicNotes を返してください。",
        },
        {
          role: "user",
          content: JSON.stringify({
            baselineCurrentLocalMembers:
              snapshot.baselineCurrentLocalMembers,
            officialCurrentLocalMembers:
              snapshot.officialCurrentLocalMembers,
            targetLocalMembers: snapshot.targetLocalMembers,
            baselineNetIncreaseRequired:
              snapshot.baselineNetIncreaseRequired,
            actualNetIncreaseRequired:
              snapshot.actualNetIncreaseRequired,
            official2023FirstHalfWins: snapshot.official2023FirstHalfWins,
            official2023SecondHalfWins: snapshot.official2023SecondHalfWins,
            official2023TotalWins: snapshot.official2023TotalWins,
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
    return {
      summary: sanitizeLine(parsed.summary) || buildFallbackAnalysis(snapshot).summary,
      alerts: sanitizeLines(parsed.alerts, 3),
      strategicNotes: sanitizeLines(parsed.strategicNotes, 3),
    };
  } catch (_error) {
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
  prefectures: PrefectureReality[];
}): AiAnalysis {
  const delta =
    snapshot.officialCurrentLocalMembers -
    snapshot.baselineCurrentLocalMembers;
  const deltaLabel =
    delta == 0 ? "基準の340人と一致" : delta > 0 ? `基準比 +${delta}人` : `基準比 ${delta}人`;
  const topPrefectures = [...snapshot.prefectures]
    .sort((a, b) => b.currentMembers - a.currentMembers)
    .slice(0, 3)
    .map((item) => `${item.prefecture}${item.currentMembers}人`);

  return {
    summary:
      `公式議員ページの集計では地方議員は ${snapshot.officialCurrentLocalMembers} 人で、` +
      `700 人まで残り ${snapshot.actualNetIncreaseRequired} 人です。${deltaLabel} です。`,
    alerts: [
      `2023年実績は前半 ${snapshot.official2023FirstHalfWins}、後半 ${snapshot.official2023SecondHalfWins}、合計 ${snapshot.official2023TotalWins}。今回の必要純増はそれを大きく上回ります。`,
      `現職数の基準を 340 人で置いている場合、実数との差分を月次KPIへ反映した方が計画精度が上がります。`,
      topPrefectures.length == 0
        ? "都道府県別ページの取得に失敗した県は 0 人表示になるため、再取得で確認してください。"
        : `現職が厚い上位県は ${topPrefectures.join("、")} です。`,
    ],
    strategicNotes: [
      "最新実数は計画の currentLocalMembers に同期させると、必要純増の計算を実数基準にできます。",
      "上位県の現職厚みと、現職が薄い県の新人擁立目標を分けて管理すると打ち手が明確になります。",
      "公式ソースの再取得時刻を見ながら、日次ではなく週次レビューの定点観測に使うのが現実的です。",
    ],
  };
}

function extractCount(text: string, pattern: RegExp): number | null {
  const match = text.match(pattern);
  if (!match || match.length < 2) {
    return null;
  }
  return toInt(match[1]);
}

function toInt(value: string): number {
  return parseInt(toAsciiDigits(value).replace(/[^0-9]/g, ""), 10);
}

function toAsciiDigits(value: string): string {
  return value.replace(/[０-９]/g, (digit) =>
    String.fromCharCode(digit.charCodeAt(0) - 0xfee0)
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
    .replace(/[ \t]+/g, " ")
    .replace(/\n{2,}/g, "\n")
    .trim();
}

function countMatches(value: string, pattern: RegExp): number {
  return [...value.matchAll(pattern)].length;
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
    .where((item) => item.length > 0)
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
