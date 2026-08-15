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
  | "debt_recovery"
  | "household_finance"
  | "product"
  | "general";

/// R28: 楔 (2026-07-28 の戦略確定) の ICP トピック。到達だけを見ると
/// japan_politics が常に勝つが、その受け手は楔の客ではない。勝ち型の選定は
/// このコホート内で行う (下の [selectIcpCohort])。
export const ICP_TARGET_TOPIC: TopicBucket = "debt_recovery";

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
/// 借金・リボ払いからの生活再建 (楔の ICP)。家計一般より狭く、当事者コミュニティ
/// の語彙に寄せる。分類のみに使う語であり、助言や法律判断には一切用いない
/// (非弁行為の一線を越えないため、債務整理系の語も「その話題である」ことの
/// 検出だけに使う)。
const DEBT_RECOVERY_ANCHORS = [
  "リボ",
  "借金",
  "返済",
  "完済",
  "残債",
  "滞納",
  "延滞",
  "多重債務",
  "自転車操業",
  "任意整理",
  "債務整理",
  "繰り上げ",
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
    v === "japan_politics" || v === "ai_tech" || v === "debt_recovery" ||
    v === "household_finance" || v === "product" || v === "general"
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
  const debt = hits(text ?? "", DEBT_RECOVERY_ANCHORS);
  const finance = hits(text ?? "", FINANCE_ANCHORS);
  const aiTech = hits(body, AI_TECH_ANCHORS);
  const product = hits(body, PRODUCT_ANCHORS);
  if (politics >= 1) return "japan_politics";
  // 借金・リボは家計一般より狭いので先に判定する (「返済」「残債」を
  // household_finance に吸わせると ICP コホートが永久に空になる)。
  if (debt >= 1) return "debt_recovery";
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
    "debt_recovery",
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

/// R28: 勝ち型の選定を ICP トピックのコホート内に閉じる。
///
/// なぜ必要か: 実測 (2026-04-27〜07-25 / 350 投稿) では URL クリックの 94% が
/// japan_politics の定点観測シリーズから出ている。到達・獲得ともグローバル最大
/// なので、素朴に最大値を取ると学習ループは「政治の集計レポートを再生産せよ」と
/// 指示する。だが 2026-07-28 の戦略確定で楔は「借金・リボ払いからの生活再建」に
/// 絞られており、その受け手は楔の客ではない。数字が大きいことと、客に届いている
/// ことは別問題。
///
/// 重要: サンプルが足りないとき **グローバル最大へ黙って落ちない**。落ちると
/// 政治シリーズが勝者として復活し、この関数の意味が消える。足りなければ
/// `sufficient: false` を返し、呼び出し側は「勝者を宣言しない」を選ぶ。
export interface IcpCohortSelection<T> {
  rows: readonly T[];
  sufficient: boolean;
  target: TopicBucket;
  totalCount: number;
}

/// ICP コホートを切り出す。既定の最小サンプルは 2 (他の lift 行と同じ基準)。
export function selectIcpCohort<T>(
  rows: readonly T[],
  topicOf: (row: T) => string,
  options: { target?: TopicBucket; minSamples?: number } = {},
): IcpCohortSelection<T> {
  const target = options.target ?? ICP_TARGET_TOPIC;
  const minSamples = options.minSamples ?? 2;
  const scoped = rows.filter((row) =>
    normalizeTopicBucket(topicOf(row)) === target
  );
  return {
    rows: scoped,
    sufficient: scoped.length >= minSamples,
    target,
    totalCount: rows.length,
  };
}

/// x.performance_context に出す ICP スコープ行。コホートが薄いときは
/// 「グローバルの勝者を手本にするな」と明示する (沈黙すると、他の行に残る
/// グローバル最大が事実上の手本になってしまう)。
///
/// R28 fix: 「ICP の投稿が 1 本も無い」と「ICP の投稿はあるが投稿年齢を揃えた
/// 比較ができない」は別の状態で、必要な次の一手も違う (前者は書け / 後者は
/// アプリ経由で投稿して計測を貯めろ)。両者を同じ 0 件として報告していた。
///
/// 背景: CSV 取込の行は `learning_cohort='historical_benchmark'` になり、
/// 年齢正規化ランキング (learningRows) から意図的に除外される。一方、返済
/// 報告カードの共有はクリップボードのみで `x_post_log` に残らない。結果、
/// ICP の実績は「取り込んだ履歴」にしか存在しえないのに、それが 1 件も
/// 見えないまま「measurements first」とだけ言い続ける状態になっていた。
export function buildIcpScopeLine<T>(
  selection: IcpCohortSelection<T>,
  historicalCount = 0,
): string {
  if (selection.sufficient) {
    return `ICP cohort: winner selection is scoped to topic=${selection.target} ` +
      `(n=${selection.rows.length} of ${selection.totalCount} measured posts). ` +
      `Reach from other topics is not evidence for this audience.`;
  }
  const base = `ICP cohort: topic=${selection.target} has only ` +
    `${selection.rows.length}/${selection.totalCount} post-age comparable ` +
    `posts — not enough to name a winner. Do NOT copy the highest-reach or ` +
    `highest-acquisition post from another topic: those numbers come from a ` +
    `different audience and do not transfer.`;
  if (historicalCount > 0) {
    return `${base} ${historicalCount} imported historical ICP post(s) exist ` +
      `but are lifetime-cumulative, so they cannot be ranked against ` +
      `age-normalized posts. Treat them as audience evidence only. To get a ` +
      `comparable winner, post ICP content through the app so metrics are ` +
      `logged from posting time.`;
  }
  return `${base} No ICP post has been measured at all yet — write for the ` +
    `ICP first, then collect measurements.`;
}

/// R29: ICP コホートの「手本」を、取り込んだ履歴から供給する。
///
/// なぜ必要か: ICP (借金・リボ) の投稿は、返済報告カードの共有が HITL 厳守で
/// クリップボード専用のため `x_post_log` に入らない。実績は CSV 取込の
/// `historical_benchmark` 行にしか存在せず、それは lifetime cumulative なので
/// 年齢正規化ランキング (winners) には載せられない。結果、ICP 向けに何本
/// 投稿しても「手本ゼロ」のままだった。
///
/// ここでは順位付けと手本提示を分ける。**順位付けには使わない** (期間基準の
/// 混在は #4367 で禁止した) が、**どのフックがこの受け手にクリックされたか**は
/// 手本として渡す。ランキングの主張はせず、事実と出所を明示する。
///
/// 返すのは URL クリック降順の上位。クリック 0 件しか無いときは、
/// 「この受け手ではまだ 1 クリックも出ていない」ことを事実として返す
/// (沈黙すると「手本が無い」と「手本はあるが効いていない」が混ざる)。
export function buildIcpHistoricalExemplarLine<T>(
  rows: readonly T[],
  urlClicksOf: (row: T) => number,
  impressionsOf: (row: T) => number | null,
  hookOf: (row: T) => string,
  target: TopicBucket = ICP_TARGET_TOPIC,
  limit = 3,
): string | null {
  if (rows.length === 0) return null;
  const withClicks = rows.filter((row) => urlClicksOf(row) > 0);
  if (withClicks.length === 0) {
    return `ICP exemplars (topic=${target}, imported lifetime-cumulative, ` +
      `n=${rows.length}): none of them produced a single url click. Do not ` +
      `reuse their shape as a proven pattern — nothing about this audience ` +
      `has converted yet. Treat the next post as a fresh test.`;
  }
  const top = [...withClicks]
    .sort((left, right) => urlClicksOf(right) - urlClicksOf(left))
    .slice(0, limit);
  const parts = top.map((row) =>
    `${urlClicksOf(row)} clicks / ${impressionsOf(row) ?? "unknown"} imp — ` +
    `"${hookOf(row)}"`
  );
  return `ICP exemplars (topic=${target}, imported lifetime-cumulative, ` +
    `${withClicks.length}/${rows.length} posts got >=1 click): ` +
    `${parts.join(" | ")}. These are NOT age-normalized and are excluded ` +
    `from the winner ranking — copy their structure, not their rank.`;
}
