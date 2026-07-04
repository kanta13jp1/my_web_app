// x_duplicate_content — X 投稿の近似重複ガード (投稿前チェック)
//
// 同一/ほぼ同一の投稿を量産すると、X のアルゴリズムに重複アカウント信号を送り、
// 凍結リスク+インプレッション低下を招く。実投稿 (postTweet) の直前に、直近 N 件の
// 投稿済み本文と現在の本文の類似度を計算し、閾値を超えたら投稿を拒否する。
//
// 類似度 = 文字バイグラム Jaccard と 正規化編集距離 (Levenshtein) の高い方。
//   - Jaccard: 語順の入れ替え・部分再利用を検出。日本語 (空白なし) にも強い文字 n-gram。
//   - 編集距離: 数語だけ差し替えた微修正コピーを検出。
// 両者の max を取ることで、どちらかの観点で「ほぼ同一」なら弾く。

export interface DuplicateGuardConfig {
  /** 類似度がこの値以上なら投稿拒否 (0..1) */
  threshold: number;
  /** 比較対象とする直近の投稿済みポスト件数 (0 = ガード無効) */
  recentCount: number;
}

export const DEFAULT_DUPLICATE_THRESHOLD = 0.9;
export const DEFAULT_DUPLICATE_RECENT_COUNT = 5;
export const MAX_DUPLICATE_RECENT_COUNT = 50;
/** 閾値の下限 (これ未満は誤検出が増えるため許可しない) */
export const MIN_DUPLICATE_THRESHOLD = 0.5;

export interface RecentPost {
  text: string;
  id?: string;
  createdAt?: string;
}

export interface DuplicateMatch {
  /** 検出した最大類似度 (0..1, 小数第3位で丸め) */
  similarity: number;
  /** 判定に用いた閾値 */
  threshold: number;
  /** 重複と判定された過去投稿の本文 */
  matchedText: string;
  /** 過去投稿の hub_data 行 id (取得できなければ null) */
  matchedId: string | null;
  /** 過去投稿の作成日時 (取得できなければ null) */
  matchedCreatedAt: string | null;
}

function clampNumber(
  value: number,
  min: number,
  max: number,
  fallback: number,
): number {
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
}

/**
 * 環境変数 (文字列) から重複ガード設定を解決する。
 * - X_DUP_SIMILARITY_THRESHOLD: 類似度閾値 (既定 0.9, 下限 0.5, 上限 1.0)
 * - X_DUP_RECENT_COUNT: 比較件数 (既定 5, 範囲 0..50, 0 でガード無効)
 * 未設定/不正値は既定値にフォールバックする。
 */
export function resolveDuplicateGuardConfig(env: {
  threshold?: string | null;
  recentCount?: string | null;
}): DuplicateGuardConfig {
  const thresholdRaw = env.threshold != null && env.threshold.trim() !== ""
    ? Number(env.threshold)
    : NaN;
  const recentRaw = env.recentCount != null && env.recentCount.trim() !== ""
    ? Number(env.recentCount)
    : NaN;
  return {
    threshold: clampNumber(
      thresholdRaw,
      MIN_DUPLICATE_THRESHOLD,
      1,
      DEFAULT_DUPLICATE_THRESHOLD,
    ),
    recentCount: clampNumber(
      Number.isFinite(recentRaw) ? Math.trunc(recentRaw) : NaN,
      0,
      MAX_DUPLICATE_RECENT_COUNT,
      DEFAULT_DUPLICATE_RECENT_COUNT,
    ),
  };
}

/**
 * 類似度比較用に本文を正規化する。
 * NFKC 正規化 → 小文字化 → URL 除去 → 記号/句読点/絵文字除去 → 空白除去。
 * URL や末尾 CTA リンクの差分ノイズを排除し、本文の実質的な同一性を測る。
 */
export function normalizeForSimilarity(value: unknown): string {
  return String(value ?? "")
    .normalize("NFKC")
    .toLowerCase()
    // URL は空白/文字列末尾まで。空白除去より先に落とす必要がある。
    .replace(/https?:\/\/\S+/g, " ")
    // 記号・句読点・絵文字 (Symbol) を除去。URL 除去後に行う。
    .replace(/[\p{P}\p{S}]+/gu, " ")
    // 残った空白 (半角/全角) をすべて除去。
    .replace(/\s+/gu, "");
}

/** 正規化済み文字列から文字バイグラム集合を作る (サロゲートペア対応)。 */
export function bigramSet(normalized: string): Set<string> {
  const chars = [...normalized];
  const set = new Set<string>();
  if (chars.length === 0) return set;
  if (chars.length === 1) {
    set.add(chars[0]);
    return set;
  }
  for (let i = 0; i < chars.length - 1; i++) {
    set.add(chars[i] + chars[i + 1]);
  }
  return set;
}

/** 文字バイグラムの Jaccard 係数 (0..1)。入力は正規化済み文字列を想定。 */
export function jaccardSimilarity(a: string, b: string): number {
  const setA = bigramSet(a);
  const setB = bigramSet(b);
  if (setA.size === 0 || setB.size === 0) {
    return setA.size === 0 && setB.size === 0 && a === b ? 1 : 0;
  }
  let intersection = 0;
  for (const gram of setA) {
    if (setB.has(gram)) intersection++;
  }
  const union = setA.size + setB.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/** Levenshtein 編集距離 (2 行 DP, サロゲートペア対応)。 */
export function levenshtein(a: string, b: string): number {
  const s = [...a];
  const t = [...b];
  const n = s.length;
  const m = t.length;
  if (n === 0) return m;
  if (m === 0) return n;
  let prev = new Array<number>(m + 1);
  let curr = new Array<number>(m + 1);
  for (let j = 0; j <= m; j++) prev[j] = j;
  for (let i = 1; i <= n; i++) {
    curr[0] = i;
    for (let j = 1; j <= m; j++) {
      const cost = s[i - 1] === t[j - 1] ? 0 : 1;
      curr[j] = Math.min(
        prev[j] + 1, // 削除
        curr[j - 1] + 1, // 挿入
        prev[j - 1] + cost, // 置換/一致
      );
    }
    const tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[m];
}

/** 正規化編集距離を類似度 (0..1) に変換。入力は正規化済み文字列を想定。 */
export function editSimilarity(a: string, b: string): number {
  const maxLen = Math.max([...a].length, [...b].length);
  if (maxLen === 0) return 1;
  return 1 - levenshtein(a, b) / maxLen;
}

/**
 * 2 本の投稿本文の類似度 (0..1)。Jaccard と編集距離の高い方を採用。
 * 正規化後に一方でも空になる場合は 0 (誤ブロックを避けるため fail-open)。
 */
export function contentSimilarity(rawA: string, rawB: string): number {
  const a = normalizeForSimilarity(rawA);
  const b = normalizeForSimilarity(rawB);
  if (a === "" || b === "") return 0;
  if (a === b) return 1;
  return Math.max(jaccardSimilarity(a, b), editSimilarity(a, b));
}

/**
 * 候補本文が直近の投稿群のいずれかと閾値以上に類似していれば、最も類似する
 * ものを返す。閾値を超えるものが無ければ null。
 */
export function findDuplicateContent(
  candidate: string,
  recentPosts: RecentPost[],
  config: DuplicateGuardConfig,
): DuplicateMatch | null {
  if (config.recentCount <= 0) return null;
  if (normalizeForSimilarity(candidate) === "") return null;

  let best: DuplicateMatch | null = null;
  const posts = recentPosts.slice(0, config.recentCount);
  for (const post of posts) {
    const text = String(post?.text ?? "");
    if (text.trim() === "") continue;
    const similarity = contentSimilarity(candidate, text);
    if (similarity < config.threshold) continue;
    if (best && similarity <= best.similarity) continue;
    best = {
      similarity: Math.round(similarity * 1000) / 1000,
      threshold: config.threshold,
      matchedText: text,
      matchedId: post.id != null ? String(post.id) : null,
      matchedCreatedAt: post.createdAt != null ? String(post.createdAt) : null,
    };
  }
  return best;
}

export interface XPostLogRowLike {
  id?: unknown;
  created_at?: unknown;
  metadata?: unknown;
}

/**
 * hub_data の x_post_log 行群から「実際に投稿済み (status=posted) かつ本文あり」の
 * ものだけを新しい順に取り出す。dry_run / failed / rejected_* は比較対象外
 * (X のタイムラインに載っていない = 重複信号を発生させていないため)。
 */
export function extractPostedTexts(
  rows: XPostLogRowLike[],
  limit: number,
): RecentPost[] {
  const posts: RecentPost[] = [];
  if (limit <= 0) return posts;
  for (const row of rows) {
    const meta = (row?.metadata && typeof row.metadata === "object")
      ? row.metadata as Record<string, unknown>
      : {};
    if (String(meta.status ?? "") !== "posted") continue;
    const text = typeof meta.text === "string" ? meta.text : "";
    if (text.trim() === "") continue;
    posts.push({
      text,
      id: row.id != null ? String(row.id) : undefined,
      createdAt: row.created_at != null ? String(row.created_at) : undefined,
    });
    if (posts.length >= limit) break;
  }
  return posts;
}
