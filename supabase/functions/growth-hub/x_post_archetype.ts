// R23: X 投稿の「内容アーキタイプ(データレポート/ニュース要約/製品プロモ)」を
// 第1級の A/B 次元へ昇格するための純ロジック。実測(2026-07-12 同日3連投):
// 独自集計データのレポート型 3.2K imp vs ニュース要約スレ 517 vs ニュース→製品
// 転換型 28 — 投稿の「情報ペイロードの型」がコピー品質よりインプレッションを
// 支配した。growth-hub/index.ts から使う classify/normalize と、
// x.performance_context に出す "Archetype lift" 集計行・"Own measured data"
// 公開可能実数行の生成をここに切り出してテスト可能にする(x_media_type.ts と
// 同じ抽出パターン)。
//
// 分類は情報ペイロードの優先順で決定的に解決する:
// news_briefing(明示ラベル) > data_report > news_briefing(構造) >
// product_promo > general。
// universal 経路の投稿は設計上ほぼ全て機能名+URL を含む(ハイブリッド)ため、
// 「ニュース要約 vs 製品プロモ」の分離は既存の variant / fallback_used 軸が担い、
// この軸の主目的は data_report(独自データ)の lift を測ることに置く。

export type ArchetypeBucket =
  | "data_report"
  | "news_briefing"
  | "product_promo"
  | "general"
  | "unknown";

/// 保存済み metadata.content_archetype / クライアント指定値を意味カテゴリへ
/// 正規化する。未知値・欠損は "unknown" バケットに残す(過去データを捨てない)。
export function normalizeArchetypeBucket(raw: string): ArchetypeBucket {
  const v = (raw ?? "").toLowerCase().trim();
  if (
    v === "data_report" || v === "news_briefing" || v === "product_promo" ||
    v === "general"
  ) {
    return v;
  }
  return "unknown";
}

// 実在機能名(短縮キー)。lib/services/x_copy_guardrails.dart の kFeatureNames と
// 同期を保つこと(サーバ側は Dart を import できないための意図的な複製)。
const FEATURE_NAME_MARKERS = [
  "給料日サイクル",
  "負債トレンド",
  "Xワンボタン投稿",
  "端末跨ぎ同期",
  "給与明細",
];

function countMatches(text: string, pattern: RegExp): number {
  return (text.match(pattern) ?? []).length;
}

/// 投稿本文(リード+リプライ連結)から内容アーキタイプを決定的に分類する。
/// news_briefing(ラベル付き): 「デイリーブリーフィング」ラベルは自前の定型
/// テンプレ由来なので定義上ニュース要約=最優先で解決する(「集計速報」等の
/// ニュース常用語+数値矢印だけで data_report に誤爆した実反例への対策)。
/// data_report: レポート固有の強シグナル(取得日時/現職名簿/基準Nとの差分 =
/// +2)とニュースにも現れる弱シグナル(集計・差分矢印・🔴🟡アラート・
/// 「残りN」・数値+単位の高密度 = 各+1)の加重合計が 3 以上。
/// news_briefing(構造): 【…】見出し 2 件以上・番号付きダイジェスト行 2 件以上。
/// product_promo: ニュース構造なしで製品シグナル(機能名/自分株式会社/本番 URL)。
export function classifyPostArchetype(
  text: string,
): "data_report" | "news_briefing" | "product_promo" | "general" {
  const body = text ?? "";
  if (body.includes("デイリーブリーフィング")) return "news_briefing";
  let dataScore = 0;
  if (/取得日時|現職名簿|基準\s*\d[\d,]*\s*との差分/.test(body)) dataScore += 2;
  if (/集計/.test(body)) dataScore += 1;
  if (/\d[\d,.]*\s*→\s*\d/.test(body)) dataScore += 1;
  if (/[🔴🟡]/u.test(body)) dataScore += 1;
  if (/残り\s*[:：]?\s*\d|あと\s*\d+\s*(日|人|件)/.test(body)) dataScore += 1;
  if (countMatches(body, /\d[\d,.]*\s*(人|件|県|円|票|pt)/g) >= 8) {
    dataScore += 1;
  }
  if (dataScore >= 3) return "data_report";

  const bracketHeadlines = countMatches(body, /【[^】]+】/g) >= 2;
  const numberedDigest = countMatches(body, /^\s*\d+[.．]\s/gm) >= 2;
  if (bracketHeadlines || numberedDigest) {
    return "news_briefing";
  }

  const productSignal = FEATURE_NAME_MARKERS.some((name) =>
    body.includes(name)
  ) ||
    body.includes("自分株式会社") ||
    body.includes("my-web-app-b67f4.web.app");
  if (productSignal) return "product_promo";

  return "general";
}

/// x_post_log 行のアーキタイプを解決する(read 側)。保存済みの意味値があれば
/// それを使い、無い旧行は本文(リード+リプライ)から best-effort 分類する。
/// 本文まで欠けている行は "unknown" で保持する。
export function resolveLoggedArchetype(
  stored: string,
  leadText: string,
  replyTexts: readonly unknown[],
): ArchetypeBucket {
  const storedBucket = normalizeArchetypeBucket(stored);
  if (storedBucket !== "unknown") return storedBucket;
  const joined = [leadText ?? "", ...replyTexts.map((t) => String(t ?? ""))]
    .join("\n")
    .trim();
  if (joined === "") return "unknown";
  return classifyPostArchetype(joined);
}

/// x.performance_context の "Archetype lift" 行を作る純関数。score アクセサを
/// 注入し、n>=2 のバケットだけ平均を表示、判定不能な既存行は unknown として
/// 保持。比較可能(unknown 除く)なバケットが 2 つ以上あるとき勝ちアーキタイプを
/// 測定事実として recommendation に付す。表示可能なバケットが 1 つも無ければ
/// null(=データ希薄時は沈黙 / 実質 default-off)。
export function buildArchetypeLiftLine<T>(
  rows: readonly T[],
  archetypeOf: (row: T) => string,
  scoreOf: (row: T) => number,
): string | null {
  const buckets = new Map<ArchetypeBucket, T[]>();
  for (const row of rows) {
    const bucket = normalizeArchetypeBucket(archetypeOf(row));
    const list = buckets.get(bucket) ?? [];
    list.push(row);
    buckets.set(bucket, list);
  }
  const avg = (list: T[]): number =>
    list.length === 0 ? 0 : Math.round(
      list.reduce((sum, row) => sum + scoreOf(row), 0) / list.length,
    );
  const order: ArchetypeBucket[] = [
    "data_report",
    "news_briefing",
    "product_promo",
    "general",
    "unknown",
  ];
  const shown = order
    .map((bucket) =>
      [bucket, buckets.get(bucket) ?? []] as [ArchetypeBucket, T[]]
    )
    .filter(([, list]) => list.length >= 2);
  if (shown.length < 1) return null;
  const parts = shown.map(([bucket, list]) =>
    `${bucket} avg=${avg(list)} (n=${list.length})`
  );
  let line = `Archetype lift (by content archetype): ${parts.join(", ")}.`;
  const comparable = shown.filter(([bucket]) => bucket !== "unknown");
  if (comparable.length >= 2) {
    const winner = [...comparable]
      .sort((left, right) => avg(right[1]) - avg(left[1]))[0][0];
    line += ` Recommendation: structure the next post as ${winner}` +
      (winner === "data_report"
        ? " (dense original numbers, deltas, named specifics, alerts)."
        : ".");
  } else {
    line += " Recommendation: insufficient archetype samples — do not force" +
      " an archetype yet.";
  }
  return line;
}

/// LLM が「データレポート型」投稿で一人称公開してよい実測数値行を作る純関数。
/// 捏造禁止ルールと両立する唯一の恒常データ源=このアカウント自身の実測
/// インプレッション。実測行(impressions 非 null)が 3 件以上あるときだけ
/// 中央値/最高値/件数を返し、薄いうちは null(沈黙)。
export function buildOwnDataFactsLine<T>(
  rows: readonly T[],
  impressionsOf: (row: T) => number | null,
): string | null {
  const measured = rows
    .map((row) => impressionsOf(row))
    .filter((value): value is number =>
      typeof value === "number" && Number.isFinite(value) && value >= 0
    )
    .sort((left, right) => left - right);
  if (measured.length < 3) return null;
  const mid = Math.floor(measured.length / 2);
  const median = measured.length % 2 === 1
    ? measured[mid]
    : Math.round((measured[mid - 1] + measured[mid]) / 2);
  const best = measured[measured.length - 1];
  return `Own measured data (REAL numbers you MAY publish first-person as ` +
    `build-in-public stats): measured posts=${measured.length}, median ` +
    `impressions=${median}, best impressions=${best}.`;
}
