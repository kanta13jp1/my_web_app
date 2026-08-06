// fal.ai queue API 経由の cinematic text-to-video 生成ヘルパー。
// presenter_video (Hedra) と並ぶ第二の動画エンジンとして type=cinematic_video で使う。
// モデルは FAL_TEXT_TO_VIDEO_MODEL secret で差し替え可能 (Veo / Kling / Seedance 等、
// fal.ai がホストする text-to-video エンドポイントならどれでも動く)。

export const FAL_QUEUE_BASE = "https://queue.fal.run";

// 既定モデル。速度/コスト/品質バランスの良い Veo fast を選ぶ。
// より高品質にしたい場合は FAL_TEXT_TO_VIDEO_MODEL で
// "fal-ai/veo3" や "fal-ai/kling-video/v2.5-turbo/pro/text-to-video" 等へ切替。
export const DEFAULT_FAL_TEXT_TO_VIDEO_MODEL = "fal-ai/veo3/fast";

// fal の API キーは env 名が 2 系統ある。コードは歴史的に FAL_KEY を読むが、
// 運用側の手順書は FAL_API_KEY を正としており、実際に FAL_API_KEY だけが
// 登録されている期間があった (2026-07-25 実障害: 値は 2026-04-18 から存在した
// のに名前だけがズレていて、AIシェアの動画が "FAL_KEY not configured" で
// 静かに落ちていた。投稿自体は成功するので丸一日気づけなかった)。
// core-hub の GITHUB_PAT ?? GITHUB_TOKEN ?? GH_TOKEN と同じ連鎖にして、
// どちらの名前で登録されていても動くようにする。
export const FAL_API_KEY_ENV_NAMES = ["FAL_KEY", "FAL_API_KEY"] as const;

export function resolveFalApiKey(
  lookup: (name: string) => string | undefined,
): string {
  for (const name of FAL_API_KEY_ENV_NAMES) {
    const value = lookup(name)?.trim();
    if (value != null && value.length > 0) return value;
  }
  return "";
}

export type FalQueueStatus = "queued" | "processing" | "completed" | "failed";

export type FalSubmitResult = {
  requestId: string | null;
  statusUrl: string | null;
  responseUrl: string | null;
};

// fal queue の status/result エンドポイントはモデルのサブパス
// ("fal-ai/veo3/fast" の "/fast" 等) を含まない owner/alias 2 セグメントで
// 参照する必要がある。"fal-ai/veo3/fast" -> "fal-ai/veo3"。
export function falQueueAppId(modelId: string): string {
  const segments = modelId
    .split("/")
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0);
  if (segments.length <= 2) return segments.join("/");
  return `${segments[0]}/${segments[1]}`;
}

// 送信 payload を組み立てる。prompt + 16:9 を既定にし、モデル固有パラメータ
// (duration / resolution 等はモデル毎に名前が違う) は JSON 文字列の
// extraParamsJson (= FAL_TEXT_TO_VIDEO_PARAMS secret) で上書き注入する。
// 壊れた JSON は無視して既定のみで送る (投稿フローを絶対に止めない)。
export function buildFalTextToVideoPayload(params: {
  prompt: string;
  extraParamsJson?: string | null;
}): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    prompt: params.prompt,
    aspect_ratio: "16:9",
  };
  const raw = params.extraParamsJson?.trim() ?? "";
  if (raw.length > 0) {
    try {
      const extra = JSON.parse(raw);
      if (extra != null && typeof extra === "object" && !Array.isArray(extra)) {
        for (const [key, value] of Object.entries(extra)) {
          payload[key] = value;
        }
      }
    } catch (_e) {
      // 壊れた JSON secret は既定 payload で続行。
    }
  }
  // prompt は常に呼び出し側の値を優先する (extra で誤って潰されないように)。
  payload.prompt = params.prompt;
  return payload;
}

// fal queue の status 文字列を安定した内部ステータスへ正規化する。
export function normalizeFalQueueStatus(value: unknown): FalQueueStatus {
  const status = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (status === "COMPLETED" || status === "OK") return "completed";
  if (status === "IN_QUEUE") return "queued";
  if (status === "IN_PROGRESS") return "processing";
  if (status === "FAILED" || status === "ERROR" || status === "CANCELLED") {
    return "failed";
  }
  return "processing";
}

// result payload から動画 URL を取り出す。モデルにより出力 shape が違う
// (Veo/Kling: {video:{url}} / 一部: {videos:[{url}]} / {video_url}) ため
// 代表的な形を順に許容する。
export function extractFalVideoUrl(payload: unknown): string | null {
  const record = asRecord(payload);
  if (record == null) return null;
  const direct = asRecord(record["video"]);
  const candidates: unknown[] = [
    direct?.["url"],
    record["video_url"],
    firstArrayItemUrl(record["videos"]),
    asRecord(asRecord(record["output"])?.["video"])?.["url"],
    asRecord(record["response"]) != null
      ? extractFalVideoUrl(record["response"])
      : null,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === "string" && /^https?:\/\//.test(candidate)) {
      return candidate;
    }
  }
  return null;
}

// fal の課金系エラー文言判定。Hedra クレジット不足と同様に、静止画降格の
// 理由として operator が投稿画面で即視認できる日本語文言に変換するために使う。
export function isFalExhaustedBalanceError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  const normalized = message.toLowerCase();
  return normalized.includes("exhausted balance") ||
    normalized.includes("insufficient credit") ||
    (normalized.includes("balance") && normalized.includes("locked"));
}

export async function submitFalTextToVideoJob(params: {
  apiKey: string;
  modelId: string;
  payload: Record<string, unknown>;
}): Promise<FalSubmitResult> {
  const data = await falJsonRequest(
    params.apiKey,
    `${FAL_QUEUE_BASE}/${params.modelId}`,
    { method: "POST", body: params.payload },
  );
  const record = asRecord(data);
  return {
    requestId: stringOrNull(record?.["request_id"]),
    statusUrl: stringOrNull(record?.["status_url"]),
    responseUrl: stringOrNull(record?.["response_url"]),
  };
}

export async function getFalQueueRequestStatus(params: {
  apiKey: string;
  modelId: string;
  requestId: string;
}): Promise<{ status: FalQueueStatus; raw: unknown }> {
  const appId = falQueueAppId(params.modelId);
  const data = await falJsonRequest(
    params.apiKey,
    `${FAL_QUEUE_BASE}/${appId}/requests/${params.requestId}/status`,
    { method: "GET" },
  );
  const record = asRecord(data);
  return { status: normalizeFalQueueStatus(record?.["status"]), raw: data };
}

export async function getFalQueueRequestResult(params: {
  apiKey: string;
  modelId: string;
  requestId: string;
}): Promise<unknown> {
  const appId = falQueueAppId(params.modelId);
  return await falJsonRequest(
    params.apiKey,
    `${FAL_QUEUE_BASE}/${appId}/requests/${params.requestId}`,
    { method: "GET" },
  );
}

async function falJsonRequest(
  apiKey: string,
  url: string,
  options: { method: "GET" | "POST"; body?: Record<string, unknown> },
): Promise<unknown> {
  const response = await fetch(url, {
    method: options.method,
    headers: {
      "Authorization": `Key ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: options.body == null ? undefined : JSON.stringify(options.body),
  });
  const raw = await response.text();
  if (!response.ok) {
    throw new Error(`fal.ai API ${response.status}: ${raw.slice(0, 500)}`);
  }
  try {
    return raw.length > 0 ? JSON.parse(raw) : {};
  } catch (_e) {
    throw new Error(`fal.ai API returned non-JSON: ${raw.slice(0, 200)}`);
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function firstArrayItemUrl(value: unknown): string | null {
  if (!Array.isArray(value) || value.length === 0) return null;
  const first = value[0];
  if (typeof first === "string") return first;
  return stringOrNull(asRecord(first)?.["url"]);
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}
