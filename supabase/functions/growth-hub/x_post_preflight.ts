// R15: X spend-cap 到達中に高価な創作パイプライン(GPT image + ElevenLabs +
// Hedra ~119 credits + 最大7.5分ポーリング)を毎回燃やしてから投稿が確定失敗する
// 実障害(2026-07-08 観測)への止血。x_post_log の失敗行から「今 x.post しても
// billing で確定失敗するか」を判定する純ロジック。Hedra 側の
// shouldSkipVideoGeneration と同じ log-scan + TTL + 成功で自己解除の契約。

import { parseBillingBlockedUntil } from "../_shared/x-client.ts";

export interface XPostPreflightRow {
  created_at: string;
  metadata: Record<string, unknown>;
}

export interface XPostPreflightResult {
  blocked: boolean;
  code?: "x_billing_blocked";
  resetAt?: string;
}

/// リセット日を parse できない時の TTL(時間)。Hedra preflight(24h)と同契約。
export const X_BILLING_PREFLIGHT_TTL_HOURS = 24;

/// 直近の x_post_log 行から billing ブロック中かを判定する。
/// blocked ⟺ 最新の code=x_billing_blocked 失敗行が存在し、それより新しい
/// status=posted 成功行が無く、かつ now < resetAt(構造化済み
/// billing_blocked_until、無ければエラー文の "next cycle begins on YYYY-MM-DD"
/// を解釈。どちらも無ければ失敗時刻 + 24h TTL)。
/// 注意: x.post は投稿前 rejection 行(dry_run / rejected_duplicate 等)も書く
/// ため「単純に最新行を見る」判定は不可 — billing 失敗行と posted 成功行だけを
/// 比較する。operator が cap を上げて投稿が成功すれば自動解除(自己修復)。
export function decideXPostPreflight(
  rows: readonly XPostPreflightRow[],
  nowUtc: Date,
): XPostPreflightResult {
  let fail: { at: Date; resetDate: string | null } | null = null;
  let lastSuccess: Date | null = null;
  for (const row of rows) {
    const metadata = row.metadata ?? {};
    const created = new Date(row.created_at);
    if (Number.isNaN(created.getTime())) continue;
    const status = String(metadata.status ?? "");
    if (status === "posted") {
      if (lastSuccess === null || created > lastSuccess) lastSuccess = created;
      continue;
    }
    if (
      status === "failed" && String(metadata.code ?? "") === "x_billing_blocked"
    ) {
      if (fail === null || created > fail.at) {
        const structured = String(metadata.billing_blocked_until ?? "").trim();
        const resetDate = /^\d{4}-\d{2}-\d{2}$/.test(structured)
          ? structured
          : parseBillingBlockedUntil(
            `${metadata.error ?? ""} ${metadata.action_required ?? ""}`,
          );
        fail = { at: created, resetDate };
      }
    }
  }
  if (fail === null) return { blocked: false };
  if (lastSuccess !== null && lastSuccess > fail.at) {
    return { blocked: false };
  }
  if (fail.resetDate) {
    // リセット日は「その日の開始」でサイクルが切り替わる。タイムゾーン差と
    // X 側の処理遅延を吸収するため +12h の grace を置く(早すぎる解除でも 1 回
    // 失敗して新しい失敗行で再アームされるだけなので安全側)。
    const resetAt = new Date(`${fail.resetDate}T12:00:00Z`);
    if (nowUtc < resetAt) {
      return {
        blocked: true,
        code: "x_billing_blocked",
        resetAt: fail.resetDate,
      };
    }
    return { blocked: false };
  }
  const ttlMs = X_BILLING_PREFLIGHT_TTL_HOURS * 3600 * 1000;
  if (nowUtc.getTime() - fail.at.getTime() < ttlMs) {
    return { blocked: true, code: "x_billing_blocked" };
  }
  return { blocked: false };
}
