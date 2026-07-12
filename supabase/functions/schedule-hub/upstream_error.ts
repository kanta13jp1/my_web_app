// upstream_error.ts — 外部ブログ API (Qiita / dev.to) 非 ok 応答の構造化 (純ロジック)
//
// 統一方針 (2026-07-12):
//   - 単一 upstream の action: 上流 4xx/5xx → HTTP 502 + 本 payload
//   - 複数 platform の action (auto_publish / publish_post / backfill_from_apis):
//     results/errors に本 payload を埋め、全 platform 失敗時のみ HTTP 502
//     (部分成功は 200 のまま — 502 にすると成功済み platform へ再投稿リトライを誘発する)
//   - 一時障害 (timeout / retry 尽き 5xx/429) は従来通り ExternalFetchError
//     → serve top-level catch が 503 + externalFetchErrorPayload を返す

export type BlogUpstreamApi = "qiita" | "dev.to";

export interface UpstreamErrorPayload {
  ok: false;
  error: string;
  error_code:
    | "upstream_auth_error"
    | "upstream_rate_limited"
    | "upstream_error";
  target_api: BlogUpstreamApi;
  upstream_status: number | null;
  hint?: string;
}

const API_LABELS: Record<BlogUpstreamApi, string> = {
  qiita: "Qiita",
  "dev.to": "dev.to",
};

export const QIITA_TOKEN_ROTATE_HINT =
  "QIITA_ACCESS_TOKEN が失効/権限不足の可能性。Qiita 設定 → アプリケーション → " +
  "個人用アクセストークンを再発行し `supabase secrets set QIITA_ACCESS_TOKEN=<新トークン> " +
  "--project-ref smmkxxavexumewbfaqpy` で更新してください。";

export const DEVTO_KEY_ROTATE_HINT =
  "DEVTO_API_KEY が失効した可能性。dev.to Settings → Extensions → DEV Community API Keys " +
  "で再発行し `supabase secrets set DEVTO_API_KEY=<新キー> " +
  "--project-ref smmkxxavexumewbfaqpy` で更新してください。";

export const QIITA_RATE_LIMIT_HINT =
  "Qiita API レート制限。72 時間級の長期 cooldown 実績あり — リトライ間隔を空けてください。";

const DETAIL_MAX_CHARS = 300;

// Qiita はレート超過を 403 body で返すことがあるため status + body で分類する
export function classifyUpstreamError(
  status: number | null,
  detail = "",
): UpstreamErrorPayload["error_code"] {
  if (status === 429) return "upstream_rate_limited";
  if (status === 403 && /rate ?limit/i.test(detail)) {
    return "upstream_rate_limited";
  }
  if (status === 401 || status === 403) return "upstream_auth_error";
  return "upstream_error";
}

function hintFor(
  targetApi: BlogUpstreamApi,
  code: UpstreamErrorPayload["error_code"],
): string | undefined {
  if (code === "upstream_auth_error") {
    return targetApi === "qiita"
      ? QIITA_TOKEN_ROTATE_HINT
      : DEVTO_KEY_ROTATE_HINT;
  }
  if (code === "upstream_rate_limited" && targetApi === "qiita") {
    return QIITA_RATE_LIMIT_HINT;
  }
  return undefined;
}

export function buildUpstreamErrorPayload(params: {
  targetApi: BlogUpstreamApi;
  status: number | null;
  detail?: string;
}): UpstreamErrorPayload {
  const detail = (params.detail ?? "").trim().slice(0, DETAIL_MAX_CHARS);
  const code = classifyUpstreamError(params.status, detail);
  const label = API_LABELS[params.targetApi];
  const statusPart = params.status !== null ? ` ${params.status}` : "";
  const detailPart = detail ? `: ${detail}` : "";
  const hint = hintFor(params.targetApi, code);
  return {
    ok: false,
    error: `${label} API error${statusPart}${detailPart}`,
    error_code: code,
    target_api: params.targetApi,
    upstream_status: params.status,
    ...(hint ? { hint } : {}),
  };
}

// results (platform → {ok,...}) が「1 件以上あり全滅」かを判定する。
// 空 map は「何も試行していない」なので false (= 従来通り 200)。
export function allPlatformsFailed(
  results: Record<string, unknown>,
): boolean {
  const entries = Object.values(results);
  if (entries.length === 0) return false;
  return entries.every(
    (r) => (r as { ok?: unknown } | null | undefined)?.ok !== true,
  );
}

// 全滅時の top-level error メッセージ (platform: error の列挙)
export function summarizePlatformFailures(
  results: Record<string, unknown>,
): string {
  const parts = Object.entries(results).map(([platform, r]) => {
    const rec = r as { error?: unknown } | null | undefined;
    const msg = typeof rec?.error === "string" ? rec.error : "unknown error";
    return `${platform}: ${msg}`;
  });
  return `All requested platforms failed — ${parts.join(" / ")}`;
}
