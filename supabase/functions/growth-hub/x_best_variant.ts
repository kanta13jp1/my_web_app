// x.performance_context の勝ち型 (bestVariant) 選定。
//
// 2 段階の誠実性ガードを一元化する:
//  (1) unknown 除外 — variant タグ無し投稿の受け皿バケットは勝ち型ではない。
//  (2) `_fallback` を base variant へ畳む — `daily_briefing_fallback` は
//      `daily_briefing` の定型フォールバック版で戦略としては同一。畳まないと
//      1 サンプルの fallback (平均89 n=1) が 7 サンプルの本命 (平均76 n=7) を
//      抑えて「勝ち型」に昇格していた (part338 で unknown 除外を入れた副作用)。
//  (3) 最小サンプル — n=1 の外れ値を勝ち型に断定しない (archetype winner の
//      n>=2 規律と対称)。
// distinctMeasuredVariants (client) の畳み込みロジックと同一の戦略同一視を保つ。

export interface VariantRankingEntry {
  variant: string;
  count?: number;
  averageScore?: number;
  totalScore?: number;
}

export interface FoldedVariant {
  variant: string;
  count: number;
  averageScore: number;
}

/// unknown を除外し `_fallback` を base へ畳んで再集計する。平均スコア降順
/// (同点は件数降順) でソートして返す。count/totalScore が無い要素は
/// count=1・totalScore=averageScore として扱う (client 側の近似入力に対応)。
export function foldVariants(
  variants: VariantRankingEntry[] | null | undefined,
): FoldedVariant[] {
  const byBase = new Map<
    string,
    { variant: string; count: number; totalScore: number }
  >();
  for (const entry of variants ?? []) {
    let name = (entry?.variant ?? "").trim();
    if (!name || name === "unknown") continue;
    if (name.endsWith("_fallback")) {
      name = name.slice(0, -"_fallback".length);
    }
    if (!name) continue;
    const count = entry.count ?? 1;
    const total = entry.totalScore ?? (entry.averageScore ?? 0) * count;
    const current = byBase.get(name) ?? {
      variant: name,
      count: 0,
      totalScore: 0,
    };
    current.count += count;
    current.totalScore += total;
    byBase.set(name, current);
  }
  return [...byBase.values()]
    .map((entry) => ({
      variant: entry.variant,
      count: entry.count,
      averageScore: Math.round(entry.totalScore / Math.max(1, entry.count)),
    }))
    .sort((left, right) =>
      right.averageScore - left.averageScore || right.count - left.count
    );
}

/// 自信を持って主張できる勝ち型 (畳み込み後 count>=minSample の最上位)。
/// 該当が無ければ null (勝ち型を主張しない)。
export function pickConfidentVariant(
  variants: VariantRankingEntry[] | null | undefined,
  minSample = 2,
): FoldedVariant | null {
  const eligible = foldVariants(variants).filter((e) => e.count >= minSample);
  return eligible[0] ?? null;
}

/// 保存フィールド/プロンプト用の bestVariant 文字列。confident があればそれ、
/// 無ければ畳み込み後の最上位、それも無ければ fallback 既定。
export function pickBestVariant(
  variants: VariantRankingEntry[] | null | undefined,
  fallback = "daily_briefing",
  minSample = 2,
): string {
  const folded = foldVariants(variants);
  const confident = folded.find((e) => e.count >= minSample);
  return (confident ?? folded[0])?.variant ?? fallback;
}

/// unknown/空を除いた実測 variant が (畳み込み後) 1 つでもあるか。
export function hasNamedVariant(
  variants: VariantRankingEntry[] | null | undefined,
): boolean {
  return foldVariants(variants).length > 0;
}
