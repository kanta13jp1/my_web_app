// R13: X 投稿の「メディア種別(動画/画像/テキスト)」を第1級の A/B 次元へ昇格する
// ための純ロジック(#3764)。growth-hub/index.ts から使う classify/normalize と、
// x.performance_context に出す "Media lift" 集計行の生成をここに切り出してテスト
// 可能にする(metrics_window.ts / x_duplicate_content.ts と同じ抽出パターン)。

export type MediaBucket = "video" | "image" | "text" | "unknown";

/// 投稿メディアを video/image/text/unknown の意味カテゴリへ正規化する。
/// MIME(video/mp4, image/png)・意味値(video/image/text)・空を許容し、判定
/// 不能な既存行は "unknown" バケットに残す(過去データを捨てない = #3764 受け入れ
/// 条件「既存は unknown bucket で保持」)。
export function normalizeMediaBucket(raw: string): MediaBucket {
  const v = (raw ?? "").toLowerCase().trim();
  if (v === "video" || v.startsWith("video/")) return "video";
  if (v === "image" || v.startsWith("image/") || v.startsWith("photo")) {
    return "image";
  }
  if (v === "gif") return "image";
  if (v === "text" || v === "none") return "text";
  return "unknown";
}

/// 投稿時に x_post_log.metadata へ書く意味カテゴリを決める(Slice 1)。media URL が
/// あればアップロード時 MIME(authoritative)や拡張子から video/image を判定し、
/// media が無ければ "text"。判定不能な media は "image"(AI 動画経路は常に .mp4 の
/// ため)。全 x.post 経路が growth-hub を通るので、ここ一箇所で全経路を賄う。
export function classifyPostMediaType(
  mediaUrl: string,
  mediaTypeHint: string,
): "video" | "image" | "text" {
  const bucket = normalizeMediaBucket(mediaTypeHint);
  if (bucket === "video" || bucket === "image") return bucket;
  const url = (mediaUrl ?? "").toLowerCase();
  if (url === "") return "text";
  if (/\.(mp4|mov|webm|m4v)(\?|#|$)/.test(url)) return "video";
  if (/\.(png|jpe?g|gif|webp|avif)(\?|#|$)/.test(url)) return "image";
  return "image";
}

/// x.performance_context の "Media lift (by type)" 行を作る純関数(Slice 3)。
/// score アクセサを注入し、n>=2 のバケットだけ平均を表示、判定不能な既存行は
/// unknown として保持。比較可能(unknown 除く)なバケットが 2 つ以上あるとき、
/// コピー variant を固定して勝ちメディアを次に優先する recommendation を測定事実
/// として付す。表示可能なバケットが 1 つも無ければ null(=データ希薄時は沈黙)。
export function buildMediaLiftLine<T>(
  rows: readonly T[],
  mediaTypeOf: (row: T) => string,
  scoreOf: (row: T) => number,
): string | null {
  const buckets = new Map<MediaBucket, T[]>();
  for (const row of rows) {
    const bucket = normalizeMediaBucket(mediaTypeOf(row));
    const list = buckets.get(bucket) ?? [];
    list.push(row);
    buckets.set(bucket, list);
  }
  const avg = (list: T[]): number =>
    list.length === 0 ? 0 : Math.round(
      list.reduce((sum, row) => sum + scoreOf(row), 0) / list.length,
    );
  const order: MediaBucket[] = ["video", "image", "text", "unknown"];
  const shown = order
    .map((bucket) => [bucket, buckets.get(bucket) ?? []] as [MediaBucket, T[]])
    .filter(([, list]) => list.length >= 2);
  if (shown.length < 1) return null;
  const parts = shown.map(([bucket, list]) =>
    `${bucket} avg=${avg(list)} (n=${list.length})`
  );
  let line = `Media lift (by type): ${parts.join(", ")}.`;
  const comparable = shown.filter(([bucket]) => bucket !== "unknown");
  if (comparable.length >= 2) {
    const winner = [...comparable]
      .sort((left, right) => avg(right[1]) - avg(left[1]))[0][0];
    line +=
      ` Recommendation: hold the copy variant constant and prefer ${winner}` +
      ` media on the next comparable post.`;
  } else {
    line +=
      " Recommendation: insufficient distinct-media samples — do not force a" +
      " media choice yet.";
  }
  return line;
}
