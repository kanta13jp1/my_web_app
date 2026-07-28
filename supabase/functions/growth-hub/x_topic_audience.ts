// R24: X 投稿の「どの既存オーディエンスに乗ったか」を第1級の A/B 次元へ昇格する
// ための純ロジック。x_post_archetype.ts (情報ペイロードの型) と対になる軸で、
// 両者の交互作用こそが実測を説明する。
//
// 実測 (account_analytics_content 2026-04-27〜2026-07-25 / 350 投稿):
//   同一の data_report 型・同一の自動生成・同一の末尾 URL でも、
//     - 日本政治 (国民民主党 地方議員集計) : n=5  中央値 122,978 imp / 286 クリック
//     - AI・テック (AIコーディングツール定点観測): n=16 中央値     58 imp /   0 クリック
//     - 家計・資産                              : n=57 中央値      9 imp /   0 クリック
//   4 桁の差。archetype 単独では説明できず、効いているのは「国民民主党」という
//   既存の巨大な受け手集団に固有名詞で乗っていること。
//
// したがって archetype lift だけを見て「データレポート型が勝ち」と学習すると、
// 型を移植したのに 58 imp しか出ない失敗を繰り返す。ここでは topic を明示的な
// 次元として測り、archetype × topic の組み合わせで勝ち負けを判定させる。

export type TopicBucket =
  | "japan_politics"
  | "ai_tech"
  | "household_finance"
  | "product"
  | "general";

/// 既存オーディエンスを持つ固有名詞アンカー。ここに載る語が本文にあると、
/// その語のフォロワー/検索面に乗る (= 自力のフォロワー数を超えて配信される)。
const POLITICS_ANCHORS = [
  "国民民主党",
  "自民党",
  "立憲民主党",
  "公明党",
  "日本維新",
  "参政党",
  "れいわ",
  "社民",
  "高市",
  "統一地方選",
  "衆院",
  "参院",
  "内閣",
  "皇室",
  "天皇",
  "議員",
  "選挙",
];
const AI_TECH_ANCHORS = [
  "openai",
  "chatgpt",
  "claude",
  "gemini",
  "cursor",
  "devin",
  "copilot",
  "notebooklm",
  "flutter",
  "supabase",
  "ai",
];
const FINANCE_ANCHORS = [
  "家計",
  "資産",
  "給料日",
  "負債",
  "給与明細",
  "支出",
  "節約",
  "投資",
  "税",
];
const PRODUCT_ANCHORS = [
  "自分株式会社",
  "ai仕事os",
  "my-web-app-b67f4",
  "5分だけ",
  "buildinpublic",
];

function hits(haystack: string, needles: readonly string[]): number {
  return needles.filter((needle) => haystack.includes(needle)).length;
}

export function normalizeTopicBucket(raw: string): TopicBucket {
  const v = (raw ?? "").toLowerCase().trim();
  if (
    v === "japan_politics" || v === "ai_tech" || v === "household_finance" ||
    v === "product" || v === "general"
  ) {
    return v;
  }
  return "general";
}

/// 本文から「乗っている既存オーディエンス」を決定的に分類する。
/// 政治アンカーは他ジャンルと同居しても優先する (実測でリーチを支配するのは
/// そちらのため)。製品語しか無いものは product = 自前の受け手しかいない投稿。
export function classifyPostTopic(text: string): TopicBucket {
  const body = (text ?? "").toLowerCase();
  const politics = hits(text ?? "", POLITICS_ANCHORS);
  const finance = hits(text ?? "", FINANCE_ANCHORS);
  const aiTech = hits(body, AI_TECH_ANCHORS);
  const product = hits(body, PRODUCT_ANCHORS);
  if (politics >= 1) return "japan_politics";
  if (finance >= 1 && finance >= aiTech) return "household_finance";
  if (aiTech >= 1) return "ai_tech";
  if (product >= 1) return "product";
  return "general";
}

/// x.performance_context の "Topic lift" 行を作る。
/// n>=2 のバケットだけ平均を出し、比較可能なバケットが 2 つ以上あるときに
/// 勝ちトピックを推奨する。データが薄い間は null (=沈黙 / 実質 default-off)。
export function buildTopicLiftLine<T>(
  rows: readonly T[],
  topicOf: (row: T) => string,
  scoreOf: (row: T) => number,
): string | null {
  const buckets = new Map<TopicBucket, T[]>();
  for (const row of rows) {
    const bucket = normalizeTopicBucket(topicOf(row));
    const list = buckets.get(bucket) ?? [];
    list.push(row);
    buckets.set(bucket, list);
  }
  const avg = (list: T[]): number =>
    list.length === 0 ? 0 : Math.round(
      list.reduce((sum, row) => sum + scoreOf(row), 0) / list.length,
    );
  const order: TopicBucket[] = [
    "japan_politics",
    "ai_tech",
    "household_finance",
    "product",
    "general",
  ];
  const shown = order
    .map((bucket) => [bucket, buckets.get(bucket) ?? []] as [TopicBucket, T[]])
    .filter(([, list]) => list.length >= 2);
  if (shown.length < 2) return null;
  const parts = shown.map(([bucket, list]) =>
    `${bucket} avg=${avg(list)} (n=${list.length})`
  );
  const winner =
    [...shown].sort((left, right) => avg(right[1]) - avg(left[1]))[0][0];
  return `Topic lift (by audience the post rode): ${parts.join(", ")}. ` +
    `Best measured topic: ${winner}. Topic is a separate dimension from ` +
    `content archetype — the same data-report format collapsed by orders of ` +
    `magnitude when moved to a topic without an existing audience. Pick the ` +
    `topic first (named entities a large audience already follows), then ` +
    `apply the winning archetype inside it.`;
}

/// archetype × topic の交互作用行。同じ archetype が topic 違いでどれだけ
/// 変わるかを明示する。両方のセルに n>=2 が揃ったときだけ出す。
export function buildArchetypeTopicInteractionLine<T>(
  rows: readonly T[],
  archetypeOf: (row: T) => string,
  topicOf: (row: T) => string,
  scoreOf: (row: T) => number,
): string | null {
  const cells = new Map<string, T[]>();
  for (const row of rows) {
    const key = `${archetypeOf(row)}|${normalizeTopicBucket(topicOf(row))}`;
    const list = cells.get(key) ?? [];
    list.push(row);
    cells.set(key, list);
  }
  const avg = (list: T[]): number =>
    list.length === 0 ? 0 : Math.round(
      list.reduce((sum, row) => sum + scoreOf(row), 0) / list.length,
    );
  const eligible = [...cells.entries()].filter(([, list]) => list.length >= 2);
  if (eligible.length < 2) return null;
  const byArchetype = new Map<string, [string, T[]][]>();
  for (const [key, list] of eligible) {
    const archetype = key.split("|")[0];
    byArchetype.set(archetype, [
      ...(byArchetype.get(archetype) ?? []),
      [key.split("|")[1], list],
    ]);
  }
  const split = [...byArchetype.entries()]
    .filter(([, entries]) => entries.length >= 2);
  if (split.length === 0) return null;
  const described = split.map(([archetype, entries]) => {
    const sorted = [...entries].sort((left, right) =>
      avg(right[1]) - avg(left[1])
    );
    return `${archetype}: ` +
      sorted.map(([topic, list]) => `${topic}=${avg(list)} (n=${list.length})`)
        .join(" vs ");
  });
  return `Archetype x topic interaction: ${described.join("; ")}. ` +
    `The same archetype does not transfer across topics — do not reuse a ` +
    `winning format on a topic where it has not been measured.`;
}
