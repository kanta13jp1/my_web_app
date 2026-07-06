// growth-hub: metrics 収集対象の鮮度フィルタ (R8-recency-window)。
//
// なぜ必要か: X のポスト指標は投稿後 ~72h でほぼ定常化する。窓なしで全履歴を
// 3 時間毎に再読すると、読取量が投稿の蓄積に比例して無限に増え、X API の
// spend cap を焼き尽くす(実障害 2026-07-05〜07: cap 到達で投稿・計測が数日
// 停止し、perf フィードバックループがデータ饑餓に陥った)。
//
// 保持条件(いずれか):
//   (a) created_at が windowDays 以内(鮮度窓)
//   (b) created_at がパース不能(fail-open — 壊れた行で計測を落とさない)
//   (c) 未計測(metadata.metrics_checked_at 不在) — cap 停止中に生まれた投稿を
//       復旧後 1 回は必ず計測するレスキュー。1 回計測されると (a) の窓判定へ
//       自然移行するため、自己制限的で読取が再増殖しない。

export interface MetricsWindowLog {
  created_at?: unknown;
  metadata?: unknown;
}

export function filterRecentLogs<T extends MetricsWindowLog>(
  logs: T[],
  windowDays: number,
  nowMs: number,
): T[] {
  const windowMs = windowDays * 86_400_000;
  return logs.filter((log) => {
    const metadata = (log.metadata ?? {}) as Record<string, unknown>;
    const checkedAt = metadata["metrics_checked_at"];
    if (checkedAt == null || String(checkedAt).trim() === "") {
      return true; // (c) 未計測レスキュー
    }
    const createdMs = Date.parse(String(log.created_at ?? ""));
    if (!Number.isFinite(createdMs)) {
      return true; // (b) fail-open
    }
    return nowMs - createdMs <= windowMs; // (a) 鮮度窓
  });
}
