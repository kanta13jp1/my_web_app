// R24: X Analytics のコンテンツ CSV エクスポートを学習母集団へ取り込むための
// 純ロジック。x_post_archetype.ts / x_acquisition_score.ts と同じ抽出パターン。
//
// なぜ必要か: これまで x.performance_context が見ていたのは x_post_log =
// 「アプリの AI シェア経由で投稿したもの」だけだった。実測 (2026-04-27〜07-25 /
// 350 投稿) では、サイトへの URL クリック 304 件のうち 302 件がアプリ外の手動
// 投稿から出ており、学習ループはアカウント最大の勝ち筋を一度も見ていなかった。
// アカウント全体を取り込む既存の手段は「1 投稿ごとの手書きマイグレーション +
// 目視の概算インプレッション」(20260712143000_backfill_election_post_a...) で、
// 同シリーズの実測 122,978-129,889 に対し 8,000 と桁を取り違えていた。
//
// CSV は lifetime cumulative (投稿からの経過時間がバラバラ) なので、取り込んだ
// 行は learning_cohort='historical_benchmark' として、投稿年齢を揃えた勝ち
// exemplar のランキングには入れない。アカウント水準の獲得事実の供給に使う。

export interface XAnalyticsCsvRow {
  postId: string;
  date: string;
  text: string;
  link: string;
  impressions: number;
  likes: number;
  engagements: number;
  bookmarks: number;
  shares: number;
  newFollows: number;
  replies: number;
  reposts: number;
  profileVisits: number;
  detailExpands: number;
  urlClicks: number;
  hashtagClicks: number;
  permalinkClicks: number;
}

export type XAnalyticsCsvIssueCode =
  | "duplicate_header"
  | "duplicate_post_id"
  | "non_ascii_digit"
  | "negative_numeric"
  | "invalid_numeric";

export interface XAnalyticsCsvIssue {
  code: XAnalyticsCsvIssueCode;
  rowIndex: number;
  column: string;
  postId?: string;
  rawValue: string;
}

export interface XAnalyticsCsvDiagnostics {
  rows: XAnalyticsCsvRow[];
  issues: XAnalyticsCsvIssue[];
  bomStripped: boolean;
  duplicatePostIdsSkipped: number;
  duplicateHeadersIgnored: string[];
  invalidNumericCells: number;
}

const HEADER_TO_KEY: Record<string, keyof XAnalyticsCsvRow> = {
  "post id": "postId",
  "date": "date",
  "post text": "text",
  "post link": "link",
  "impressions": "impressions",
  "likes": "likes",
  "engagements": "engagements",
  "bookmarks": "bookmarks",
  "shares": "shares",
  "new follows": "newFollows",
  "replies": "replies",
  "reposts": "reposts",
  "profile visits": "profileVisits",
  "detail expands": "detailExpands",
  "url clicks": "urlClicks",
  "hashtag clicks": "hashtagClicks",
  "permalink clicks": "permalinkClicks",
};

type NumericRowKey =
  | "impressions"
  | "likes"
  | "engagements"
  | "bookmarks"
  | "shares"
  | "newFollows"
  | "replies"
  | "reposts"
  | "profileVisits"
  | "detailExpands"
  | "urlClicks"
  | "hashtagClicks"
  | "permalinkClicks";

const NUMERIC_KEYS: readonly NumericRowKey[] = [
  "impressions",
  "likes",
  "engagements",
  "bookmarks",
  "shares",
  "newFollows",
  "replies",
  "reposts",
  "profileVisits",
  "detailExpands",
  "urlClicks",
  "hashtagClicks",
  "permalinkClicks",
];

/// RFC4180 相当の最小 CSV スプリッタ。X の Date 列は `"Wed, Jul 22, 2026"` の
/// ように引用符内にカンマを含み、本文には改行も含まれうるため、素朴な
/// `split(",")` / `split("\n")` では壊れる。先頭 BOM (\uFEFF) も明示除去する。
export function splitCsvRows(input: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  const text = (input ?? "")
    .replace(/^\uFEFF/, "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n");
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        field += ch;
      }
      continue;
    }
    if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n") {
      row.push(field);
      field = "";
      if (row.some((cell) => cell.trim() !== "")) rows.push(row);
      row = [];
    } else {
      field += ch;
    }
  }
  row.push(field);
  if (row.some((cell) => cell.trim() !== "")) rows.push(row);
  return rows;
}

function parseNumericCell(
  raw: string,
  rowIndex: number,
  column: string,
  postId: string,
  issues: XAnalyticsCsvIssue[],
): { value: number; invalid: boolean } {
  const trimmed = (raw ?? "").trim();
  if (trimmed === "") return { value: 0, invalid: false };
  if (/[０-９]/.test(trimmed)) {
    issues.push({
      code: "non_ascii_digit",
      rowIndex,
      column,
      postId,
      rawValue: trimmed,
    });
    return { value: 0, invalid: true };
  }
  const compact = trimmed.replace(/[",\s]/g, "");
  if (/^-\d+(?:\.\d+)?$/.test(compact)) {
    issues.push({
      code: "negative_numeric",
      rowIndex,
      column,
      postId,
      rawValue: trimmed,
    });
    return { value: 0, invalid: true };
  }
  if (/^\d+(?:\.\d+)?$/.test(compact)) {
    const parsed = Number(compact);
    if (Number.isFinite(parsed)) {
      return { value: parsed, invalid: false };
    }
  }
  issues.push({
    code: "invalid_numeric",
    rowIndex,
    column,
    postId,
    rawValue: trimmed,
  });
  return { value: 0, invalid: true };
}

/// X Analytics のコンテンツ CSV をパースし、重複ヘッダ・重複 Post id・
/// 全角数字/負数/不正数値セルの診断情報も合わせて返す。
export function parseXAnalyticsCsvWithDiagnostics(
  input: string,
): XAnalyticsCsvDiagnostics {
  const rawInput = input ?? "";
  const bomStripped = rawInput.startsWith("\uFEFF");
  const rows = splitCsvRows(bomStripped ? rawInput.slice(1) : rawInput);
  const issues: XAnalyticsCsvIssue[] = [];
  const duplicateHeadersIgnored: string[] = [];

  if (rows.length < 2) {
    return {
      rows: [],
      issues,
      bomStripped,
      duplicatePostIdsSkipped: 0,
      duplicateHeadersIgnored,
      invalidNumericCells: 0,
    };
  }

  const header = rows[0].map((cell) => cell.trim().toLowerCase());
  const indexByKey = new Map<keyof XAnalyticsCsvRow, number>();
  header.forEach((name, index) => {
    const key = HEADER_TO_KEY[name];
    if (key === undefined) return;
    if (indexByKey.has(key)) {
      duplicateHeadersIgnored.push(name);
      issues.push({
        code: "duplicate_header",
        rowIndex: 1,
        column: name,
        rawValue: rows[0][index] ?? name,
      });
      return;
    }
    indexByKey.set(key, index);
  });

  if (!indexByKey.has("postId")) {
    return {
      rows: [],
      issues,
      bomStripped,
      duplicatePostIdsSkipped: 0,
      duplicateHeadersIgnored,
      invalidNumericCells: 0,
    };
  }

  const cell = (cells: string[], key: keyof XAnalyticsCsvRow): string => {
    const index = indexByKey.get(key);
    return index === undefined ? "" : (cells[index] ?? "").trim();
  };

  const parsed: XAnalyticsCsvRow[] = [];
  const seenPostIds = new Set<string>();
  let duplicatePostIdsSkipped = 0;
  let invalidNumericCells = 0;

  for (let i = 1; i < rows.length; i += 1) {
    const cells = rows[i];
    const rowIndex = i + 1;
    const postId = cell(cells, "postId");
    if (!/^\d{5,}$/.test(postId)) continue;
    if (seenPostIds.has(postId)) {
      duplicatePostIdsSkipped += 1;
      issues.push({
        code: "duplicate_post_id",
        rowIndex,
        column: "postId",
        postId,
        rawValue: postId,
      });
      continue;
    }
    seenPostIds.add(postId);

    const row: XAnalyticsCsvRow = {
      postId,
      date: cell(cells, "date"),
      text: cell(cells, "text"),
      link: cell(cells, "link"),
      impressions: 0,
      likes: 0,
      engagements: 0,
      bookmarks: 0,
      shares: 0,
      newFollows: 0,
      replies: 0,
      reposts: 0,
      profileVisits: 0,
      detailExpands: 0,
      urlClicks: 0,
      hashtagClicks: 0,
      permalinkClicks: 0,
    };

    for (const key of NUMERIC_KEYS) {
      const checked = parseNumericCell(
        cell(cells, key),
        rowIndex,
        key,
        postId,
        issues,
      );
      row[key] = checked.value;
      if (checked.invalid) invalidNumericCells += 1;
    }
    parsed.push(row);
  }

  return {
    rows: parsed,
    issues,
    bomStripped,
    duplicatePostIdsSkipped,
    duplicateHeadersIgnored,
    invalidNumericCells,
  };
}

/// X Analytics のコンテンツ CSV をパースする。列順とヘッダ表記の揺れを許容し、
/// Post id が空の行や重複 Post id 行は捨てる。未知の列は無視する。
export function parseXAnalyticsCsv(input: string): XAnalyticsCsvRow[] {
  return parseXAnalyticsCsvWithDiagnostics(input).rows;
}

/// 取り込み 1 行分の x_post_log metadata を作る。
/// CSV は lifetime cumulative なので historical_benchmark コホートに入れ、
/// 投稿年齢を揃えた勝ち exemplar ランキングは汚さない。
export function buildAnalyticsImportMetadata(
  row: XAnalyticsCsvRow,
  options: {
    userId: string;
    archetype: string;
    observedAt: string;
    exportRange?: string;
  },
): Record<string, unknown> {
  return {
    user_id: options.userId,
    tweet_id: row.postId,
    status: "tracked_existing",
    text: row.text,
    reply_texts: [],
    source: "x_analytics_csv_import",
    variant: "account_history",
    experiment_key: "x_first_user_growth_10k",
    content_kind: "text",
    content_archetype: options.archetype,
    learning_cohort: "historical_benchmark",
    metric_observation_kind: "lifetime_cumulative",
    metric_provenance: "x_analytics_csv",
    historical_benchmark_impressions: row.impressions,
    historical_benchmark_observed_at: options.observedAt,
    historical_benchmark_provenance: "x_analytics_csv_export",
    analytics_export_range: options.exportRange ?? "",
    observed_at: options.observedAt,
    posted_at: row.date,
    impressions: row.impressions,
    latest_metrics: {
      tweet_id: row.postId,
      tweet_role: "lead",
      text: row.text,
      source: "x_analytics_csv_import",
      variant: "account_history",
      impressions: row.impressions,
      engagements: row.engagements,
      like_count: row.likes,
      reply_count: row.replies,
      repost_count: row.reposts,
      bookmark_count: row.bookmarks,
      url_clicks: row.urlClicks,
      profile_clicks: row.profileVisits,
      new_follows: row.newFollows,
      detail_expands: row.detailExpands,
      metric_observation_kind: "lifetime_cumulative",
    },
  };
}

/// x.performance_context に出すアカウント水準の獲得事実。
/// 「到達は出ているのにサイトへ人が来ていない」構造を、逸話ではなく分布で渡す。
/// 3 行未満、または URL クリックが全件ゼロのときは null (=沈黙)。
export function buildAccountAcquisitionLine(
  rows: readonly XAnalyticsCsvRow[],
): string | null {
  if (rows.length < 3) return null;
  const totalImpressions = rows.reduce((sum, r) => sum + r.impressions, 0);
  const totalClicks = rows.reduce((sum, r) => sum + r.urlClicks, 0);
  if (totalClicks <= 0) return null;
  const clicked = rows.filter((r) => r.urlClicks > 0);
  const ranked = [...clicked].sort((a, b) => b.urlClicks - a.urlClicks);
  const topShare = Math.round(
    (ranked.slice(0, 5).reduce((sum, r) => sum + r.urlClicks, 0) /
      totalClicks) * 100,
  );
  const compact = (value: string) =>
    value.replace(/\s+/g, " ").slice(0, 60).trim();
  return [
    `Account-wide acquisition (imported X analytics, n=${rows.length}, ` +
    `lifetime cumulative): impressions=${totalImpressions}, ` +
    `url clicks=${totalClicks}, posts with >=1 click=${clicked.length}.`,
    `The top ${Math.min(5, ranked.length)} click drivers account for ` +
    `${topShare}% of all url clicks. Top driver hooks: ` +
    `${
      ranked.slice(0, 3).map((r) =>
        `"${compact(r.text)}" (${r.urlClicks} clicks, ${r.impressions} imp)`
      ).join(" | ")
    }.`,
    `Reach alone did not convert: copy what the click drivers did ` +
    `(named specifics, real numbers, the link in the lead), not what merely ` +
    `reached many people.`,
  ].join(" ");
}
