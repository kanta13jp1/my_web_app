// x.performance_context の勝ち型 (bestVariant) 選定。
//
// variants ランキングには variant タグ無し投稿の受け皿である「unknown」
// バケットが混ざる。variant ランキング表示・distinctVariants 計数など他の
// 全消費箇所は unknown を除外しているのに、bestVariant だけ variants[0] を
// 素通ししていたため、タグ無し高インプレ投稿が貯まると「今の勝ち型:
// unknown」がダッシュボードと投稿生成プロンプト (Current best variant) の
// 両方へ流れていた。ここで除外を一元化する。

export interface VariantRankingEntry {
  variant: string;
}

/// unknown を除いた最上位 variant。無ければ fallback (既定 daily_briefing)。
export function pickBestVariant(
  variants: VariantRankingEntry[],
  fallback = "daily_briefing",
): string {
  return variants.find((entry) => entry.variant !== "unknown")?.variant ??
    fallback;
}

/// unknown 以外の実測 variant が1つでもあるか。promptContext が
/// 「Current best variant: X」と主張してよいかのガード (全行 unknown のとき
/// fallback 名を実測済みかのように主張しない)。
export function hasNamedVariant(variants: VariantRankingEntry[]): boolean {
  return variants.some((entry) => entry.variant !== "unknown");
}
