// R16: /admin 経営分析ダッシュボードの「今日の投稿を知る」ループを閉じる純ロジック。
// ダッシュボードは従来 x_post_log を一切読まず、todayViews==0 だけ見て無条件に
// 「X投稿を作る」を出していた。今日 11:57 に投稿済み(動画+poll)でも再投稿を促し、
// 近似重複ガード踏み+ゴールデンアワー(手動リプ)喪失+CmoPage の有償生成を誘発した
// (R15 の spend-cap 事件と同型の foot-gun)。この関数は直近ログから「今日すでに
// 投稿したか / 何件 / 最新の tweet と初速インプレ / spend-cap ブロック中か」を返す。

import { decideXPostPreflight, XPostPreflightRow } from "./x_post_preflight.ts";

export interface XTodayStatusRow {
  created_at: string;
  metadata: Record<string, unknown>;
}

export interface XTodayStatus {
  available: true;
  postedTodayCount: number;
  lastPostedAt: string | null;
  lastTweetId: string | null;
  lastMediaType: string | null;
  lastVariant: string | null;
  latestImpressions: number | null;
  lastCollectedAt: string | null;
  blocked: boolean;
  resetAt: string | null;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function strOrNull(value: unknown): string | null {
  const s = value === null || value === undefined ? "" : String(value).trim();
  return s === "" ? null : s;
}

function numOrNull(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

/// 今日投稿されたか等を集計する。今日境界 = クライアントのローカル深夜を UTC ISO で
/// 受け取り(例: JST 深夜 → 前日 15:00Z)、posted_at と epoch ms で絶対時刻比較する
/// (文字列の日付比較は JST/UTC ズレで誤る)。status==='posted' 行だけを数えるので、
/// 失敗行や x_billing_blocked 行が「投稿済み」に化けることはない。
/// startOfDayIso が不正なときは直近24hへ degrade(全件でも0件でもなく安全側)。
export function computeTodayStatus(
  rows: readonly XTodayStatusRow[],
  startOfDayIso: string,
  nowUtc: Date,
): XTodayStatus {
  const parsedStart = Date.parse(startOfDayIso ?? "");
  const startMs = Number.isNaN(parsedStart)
    ? nowUtc.getTime() - 24 * 3600 * 1000
    : parsedStart;

  let count = 0;
  let last: { at: number; meta: Record<string, unknown> } | null = null;
  for (const row of rows) {
    const meta = asRecord(row.metadata);
    if (String(meta.status ?? "") !== "posted") continue;
    const postedMs = Date.parse(
      String(meta.posted_at ?? row.created_at ?? ""),
    );
    if (Number.isNaN(postedMs) || postedMs < startMs) continue;
    count += 1;
    if (last === null || postedMs > last.at) last = { at: postedMs, meta };
  }

  const preflight = decideXPostPreflight(
    rows as readonly XPostPreflightRow[],
    nowUtc,
  );
  const meta = last?.meta ?? {};
  const latest = asRecord(meta.latest_metrics);

  return {
    available: true,
    postedTodayCount: count,
    lastPostedAt: last ? new Date(last.at).toISOString() : null,
    lastTweetId: strOrNull(meta.tweet_id),
    lastMediaType: strOrNull(meta.media_type),
    lastVariant: strOrNull(meta.variant),
    latestImpressions: last
      ? numOrNull(latest.impressions ?? meta.impressions)
      : null,
    lastCollectedAt: strOrNull(meta.metrics_checked_at),
    blocked: preflight.blocked,
    resetAt: preflight.resetAt ?? null,
  };
}
