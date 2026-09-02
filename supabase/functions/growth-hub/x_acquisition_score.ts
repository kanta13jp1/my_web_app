// R24: X 投稿の学習ランキング基準を「到達(impressions)」から「獲得(URL クリック)」
// へ差し替えるための純ロジック。x_media_type.ts / x_post_archetype.ts と同じ抽出
// パターンで、growth-hub/index.ts から使う score 計算と x.performance_context に
// 出す集計行の生成をここへ切り出してテスト可能にする。
//
// 実測根拠 (account_analytics_content 2026-04-27〜2026-07-25 / 350 投稿):
//   - アカウント全体: impressions 983,216 / URL クリック 304 / 新規フォロー 24。
//   - URL クリックが 1 以上あった投稿は 350 本中 13 本のみ。
//   - クリック上位 5 本 (国民民主党 地方議員集計) だけで 286 クリック = 全体の 94%。
//   - 一方で「いいね」上位 (女系天皇 57K/2.5K いいね, 政府専用機 35K/1.3K いいね)
//     の URL クリックは 0-2。到達・共感とサイト獲得は同じ順序に並ばない。
//
// したがって impressions 単独ランキングは「到達は大きいがサイトへ 1 人も送って
// いない投稿」を勝ち exemplar として LLM に手本提示してしまう。ここでは
// クリックを最上位の重みに置き、impressions は上限キャップ付きの補助項として
// 残す (到達ゼロの投稿を勝ちにしないための下支え)。

/// 獲得スコアの入力。すべて「最新の実測値」を渡す (欠損は 0 / null)。
export interface AcquisitionScoreInput {
  urlClicks?: number | null;
  profileClicks?: number | null;
  bookmarkCount?: number | null;
  replyCount?: number | null;
  repostCount?: number | null;
  likeCount?: number | null;
  impressions?: number | null;
}

/// 重み。獲得(サイト着地)への距離が近い指標ほど大きい。
/// urlClicks = 実際にサイトへ着地した人数そのものなので最上位。
/// profileClicks = プロフィール経由の二次導線 (実測 2,296 / 90 日)。
/// bookmark/reply = 保存・会話 (後日の再訪と関係の芽)。
/// repost/like = 拡散と共感。実測でクリックへの寄与が最も弱い。
export const ACQUISITION_WEIGHTS = {
  urlClicks: 1000,
  profileClicks: 60,
  bookmarkCount: 25,
  replyCount: 20,
  repostCount: 8,
  likeCount: 2,
} as const;

/// impressions は「上限キャップ付きの補助項」。10K を満点 100 点として頭打ちに
/// する = 130K の到達は 10K の 13 倍の価値を持たない、という測定上の立場。
/// これが無いと 122,978 imp / 0 クリックの投稿が、500 imp / 3 クリックの投稿を
/// 永久に上回り続ける。
export const IMPRESSION_CAP = 10_000;
export const IMPRESSION_MAX_POINTS = 100;

function num(value: number | null | undefined): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? value
    : 0;
}

/// 到達の寄与分 (0..IMPRESSION_MAX_POINTS)。
export function impressionTerm(impressions: number | null | undefined): number {
  const value = num(impressions);
  if (value <= 0) return 0;
  return Math.round(
    (Math.min(value, IMPRESSION_CAP) / IMPRESSION_CAP) * IMPRESSION_MAX_POINTS,
  );
}

/// クリック最上位の複合獲得スコア。impressions は上限キャップ付きで加算する。
export function computeAcquisitionScore(input: AcquisitionScoreInput): number {
  return Math.round(
    num(input.urlClicks) * ACQUISITION_WEIGHTS.urlClicks +
      num(input.profileClicks) * ACQUISITION_WEIGHTS.profileClicks +
      num(input.bookmarkCount) * ACQUISITION_WEIGHTS.bookmarkCount +
      num(input.replyCount) * ACQUISITION_WEIGHTS.replyCount +
      num(input.repostCount) * ACQUISITION_WEIGHTS.repostCount +
      num(input.likeCount) * ACQUISITION_WEIGHTS.likeCount +
      impressionTerm(input.impressions),
  );
}

/// x.performance_context の "Acquisition ranking" 行を作る。
/// 到達ランキングの 1 位と獲得ランキングの 1 位が食い違うときは、その乖離を
/// 測定事実として明示する (到達だけを見て手本を選ばせないための警告行)。
/// rows が 2 件未満、または獲得スコアが全件ゼロのときは null (=沈黙)。
export function buildAcquisitionRankingLine<T>(
  rows: readonly T[],
  acquisitionOf: (row: T) => number,
  reachOf: (row: T) => number | null,
  hookOf: (row: T) => string,
  urlClicksOf: (row: T) => number,
): string | null {
  if (rows.length < 2) return null;
  const scored = rows.filter((row) => acquisitionOf(row) > 0);
  if (scored.length === 0) return null;
  const byAcquisition = [...scored].sort((left, right) =>
    acquisitionOf(right) - acquisitionOf(left)
  );
  const byReach = [...rows].sort((left, right) =>
    (reachOf(right) ?? -1) - (reachOf(left) ?? -1)
  );
  const top = byAcquisition[0];
  const reachTop = byReach[0];
  const parts = [
    `Acquisition ranking (URL clicks weighted first, impressions capped at ` +
    `${IMPRESSION_CAP}): top=${acquisitionOf(top)} ` +
    `(${urlClicksOf(top)} url clicks, reach=${reachOf(top) ?? "unknown"}) ` +
    `hook="${hookOf(top)}".`,
  ];
  if (reachTop !== top) {
    parts.push(
      `Divergence warning: the highest-reach post ` +
        `(reach=${reachOf(reachTop) ?? "unknown"}, ` +
        `${urlClicksOf(reachTop)} url clicks) is NOT the acquisition winner. ` +
        `Do not copy the highest-reach post when its url clicks are lower — ` +
        `reach without clicks did not put anyone on the site.`,
    );
  }
  const zeroClick = rows.filter((row) => urlClicksOf(row) === 0).length;
  parts.push(
    `Click coverage: ${
      rows.length - zeroClick
    }/${rows.length} measured posts ` +
      `produced at least one url click.`,
  );
  return parts.join(" ");
}

/// R24 fix: 獲得スコアの入力は**全項が同じ期間基準**でなければならない。
///
/// 初版は `impressions` だけ年齢正規化窓の値を渡し、`urlClicks` ほか 6 項は
/// lifetime 累積を渡していた。`urlClicks` の重みは 1000、`impressions` 項は
/// 上限 100 点なので、支配項に年齢バイアスが丸ごと残り、正規化した項では
/// 原理的に埋め合わせられない。結果、3 ヶ月前の投稿 (lifetime 5 クリック) が
/// 2 日前の投稿 (同一窓 4 クリック) を恒久的に上回り、
/// 「Rank every post against one shared age window」という同ファイルの
/// 不変条件に正面から反していた。
///
/// ここでは all-or-nothing で基準を選ぶ。窓のサンプルがあれば**全項**を窓から、
/// 無ければ**全項**を累積から取る。項ごとのフォールバックは同じバグを再発させる
/// ので行わない。
export interface AcquisitionScoreBasis {
  input: AcquisitionScoreInput;
  /// "window" = 年齢を揃えた窓の値 / "cumulative" = lifetime 累積。
  basis: "window" | "cumulative";
}

export function resolveAcquisitionScoreInput(
  sample: AcquisitionScoreInput | null | undefined,
  cumulative: AcquisitionScoreInput,
): AcquisitionScoreBasis {
  // 窓サンプルは impressions を必ず持つ (無い窓はそもそも作られない)。
  // impressions が取れない sample は窓として不完全なので累積へ倒す。
  if (sample && typeof sample.impressions === "number") {
    return {
      basis: "window",
      input: {
        urlClicks: sample.urlClicks ?? 0,
        profileClicks: sample.profileClicks ?? 0,
        bookmarkCount: sample.bookmarkCount ?? 0,
        replyCount: sample.replyCount ?? 0,
        repostCount: sample.repostCount ?? 0,
        likeCount: sample.likeCount ?? 0,
        impressions: sample.impressions,
      },
    };
  }
  return { basis: "cumulative", input: cumulative };
}
