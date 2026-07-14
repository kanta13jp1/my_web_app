// R27: AIツール動向トラッカー系列 (docs/X_TRACKER_SERIES_PLAYBOOK.md step 2)。
// データ資産 = docs/ai-tool-watch/latest-report.json (ai-tool-watch.yml が
// 公式 changelog / リリースノート 9 ソースを日次巡回して生成する実測)。
// 「読者コミュニティ(AI開発者)が既に追っている固有テーマ」×「自分だけが
// この形で集計している実数」= ポストA(選挙集計 17.2K 実測)の勝ち条件を
// AI ツールニッチへ水平展開する。
//
// LLM 不使用の決定的合成のみ(数値捏造が構造的に不可能)。変化が無い日と
// ソース数が薄い日は null(候補を作らない=近似重複ガードに拒否させるの
// ではなく生成側で見送る / playbook step 3)。

type JsonRecord = Record<string, unknown>;

function asRecord(value: unknown): JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/// 監視ソース 1 件の正規化ビュー。
export type AiToolWatchSourceView = {
  name: string;
  url: string;
  changed: boolean;
  firstSeen: boolean;
  hasError: boolean;
  keywords: string[];
  latestSignal: string;
};

/// 生成側 (scripts/ai_tool_watch.py) が signal 抽出に失敗した時のプレースホルダ。
const NO_SIGNAL_PLACEHOLDER = "No title detected";

export function parseAiToolWatchSources(
  rawSources: unknown,
): AiToolWatchSourceView[] {
  return asArray(rawSources).map((entry) => {
    const record = asRecord(entry);
    const groups = asRecord(record.keyword_groups);
    const keywords: string[] = [];
    for (const groupValues of Object.values(groups)) {
      for (const keyword of asArray(groupValues)) {
        const clean = text(keyword);
        if (clean !== "" && !keywords.includes(clean)) keywords.push(clean);
      }
    }
    const rawSignal = text(record.latest_signal);
    return {
      name: text(record.name),
      url: text(record.url),
      changed: record.changed === true,
      firstSeen: record.first_seen === true,
      hasError: record.error !== null && record.error !== undefined &&
        text(record.error) !== "",
      keywords,
      latestSignal: rawSignal === NO_SIGNAL_PLACEHOLDER ? "" : rawSignal,
    };
  }).filter((source) => source.name !== "");
}

export type AiToolTrackerPost = {
  text: string;
  replyTexts: string[];
  sourceUrls: string[];
  candidateKey: string;
  changedCount: number;
  sourceCount: number;
};

const MIN_SOURCES = 3;
const MAX_KEYWORDS_PER_SOURCE = 8;
const MAX_SIGNAL_CHARS = 70;

function compactSignal(signal: string): string {
  const clean = signal.replace(/\s+/g, " ").trim();
  return clean.length <= MAX_SIGNAL_CHARS
    ? clean
    : `${clean.slice(0, MAX_SIGNAL_CHARS - 1)}…`;
}

function jstDateLabel(iso: string): { label: string; key: string } | null {
  const parsed = Date.parse(iso);
  if (!Number.isFinite(parsed)) return null;
  const jst = new Date(parsed + 9 * 60 * 60 * 1000);
  const y = jst.getUTCFullYear();
  const m = jst.getUTCMonth() + 1;
  const d = jst.getUTCDate();
  return {
    label: `${y}/${m}/${d}`,
    key: `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`,
  };
}

/// ai-tool-watch レポートからポストA構造の X 投稿候補を決定的に合成する。
/// 更新検知 0 件 / ソース数 MIN_SOURCES 未満 / checked_at 不正は null。
export function buildAiToolTrackerPost(
  rawReport: unknown,
  targetUrl: string,
): AiToolTrackerPost | null {
  const report = asRecord(rawReport);
  const sources = parseAiToolWatchSources(report.sources);
  if (sources.length < MIN_SOURCES) return null;
  // 取得エラーのソースを「更新検知」に数えない(レビュー F1): 生成側は
  // fetch 失敗時もエラーページ本文の hash 変化で changed=true を立てるため、
  // 403/timeout の遷移日に偽の検知件数が載る。「実測値」を掲げる系列で
  // 捏造相当の数値を出さないための除外(エラー自体はアラートに出す)。
  const changed = sources.filter(
    (source) => source.changed && !source.hasError,
  );
  if (changed.length === 0) return null;
  const checkedAt = text(report.checked_at);
  const day = jstDateLabel(checkedAt);
  if (day === null) return null;

  const activeGroups = asArray(report.active_groups).map(text).filter(
    (group) => group !== "",
  );
  const highPriority = asArray(report.high_priority_groups).map(text).filter(
    (group) => group !== "",
  );

  // リード: ポストA構造(取得日時→主要実数→検知内訳)。「集計」の語は
  // classifyPostArchetype の data_report シグナル(自己整合テストで固定)。
  const lead = [
    `AIコーディングツール定点観測 ${day.label}`,
    "",
    `取得日時: ${checkedAt}`,
    `監視ソース: ${sources.length}件`,
    `24hで更新検知: ${changed.length}件`,
    `アクティブ話題群: ${activeGroups.length}群`,
    `高優先シグナル: ${
      highPriority.length > 0 ? highPriority.join("、") : "なし"
    }`,
    "",
    "更新を検知した公式ソース",
    // 検知シグナル(生成側が実本文から抽出した見出し)を必ず併記する:
    // (a) 「何が変わったか」の実データで情報価値を上げる (b) リード唯一の
    // 日替わり自由テキスト=連日同一ソースが更新されるリリース週でも前日
    // リードとの類似度を下げ、承認後の近似重複拒否を防ぐ(レビュー F2:
    // シグナル無しだと類似度 0.99 で threshold 0.9 を踏む実測)。
    ...changed.flatMap((source) => {
      const keywords = source.keywords.slice(0, MAX_KEYWORDS_PER_SOURCE);
      const suffix = keywords.length > 0 ? `: ${keywords.join(" / ")}` : "";
      const lines = [`・${source.name}${suffix}`];
      if (source.latestSignal !== "") {
        lines.push(`　└「${compactSignal(source.latestSignal)}」`);
      }
      return lines;
    }),
    "",
    `公式changelog・リリースノート${sources.length}件を毎日自動巡回して集計した実測値です。`,
  ].join("\n");

  const replies: string[] = [];

  // 全監視対象(ポストAの「名簿」相当 = 固有名詞の検索面)。
  replies.push(
    [
      "監視対象の全ソース",
      "",
      ...sources.map((source) =>
        source.changed && !source.hasError
          ? `🔄 ${source.name}(24hで更新)`
          : `・${source.name}`
      ),
    ].join("\n"),
  );

  // アラート(実測から機械的に導出できるものだけ)。
  const errored = sources.filter((source) => source.hasError);
  replies.push(
    [
      "アラート",
      "",
      ...(errored.length > 0
        ? errored.map((source) => `🟡 ${source.name}: 取得エラー`)
        : [`取得エラーなし。全${sources.length}ソース正常巡回。`]),
    ].join("\n"),
  );

  // URL は実測の勝ち構造(link-in-reply)に従い最終リプライのみ。
  replies.push(
    [
      "この定点観測はアプリ内のAIツール監視cronが毎日生成しています。",
      "同じ「実測を並べる」型のトラッカーを選挙・家計・X運用でも公開中です。",
      targetUrl,
    ].join("\n"),
  );

  const sourceUrls = changed
    .map((source) => source.url)
    .filter((url) => url !== "")
    .slice(0, 10);

  return {
    text: lead,
    replyTexts: replies,
    sourceUrls,
    candidateKey: `ai-tool-tracker:${day.key}`,
    changedCount: changed.length,
    sourceCount: sources.length,
  };
}
