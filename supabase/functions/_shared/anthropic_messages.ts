// Anthropic Messages API 共有ヘルパー
// ベンダーダイジェスト 2026-07-05 採用 #1 (messages 配列内 system entry) +
// #2 (prompt caching / cache diagnostics) の実装基盤。
//
// 設計根拠: docs/PROMPT_CACHING_OPUS47_COST_GUIDE.md §3.1 / §8
// - prompt caching は prefix 一致。安定部分 (system) を先頭に置き、
//   最後の system block に cache_control breakpoint を付ける。
// - 最小キャッシュ長はモデル依存 (約 1024〜4096 tokens)。短い system は
//   エラーなく黙ってキャッシュされない (usage で確認する)。

export const ANTHROPIC_VERSION = "2023-06-01";
export const ANTHROPIC_MESSAGES_URL = "https://api.anthropic.com/v1/messages";

// Cache diagnostics は public beta / first-party Claude API のみ。
// リクエストに diagnostics.previous_message_id を渡すと、レスポンスの
// diagnostics にキャッシュミス箇所の説明が返る。
export const CACHE_DIAGNOSTICS_BETA = "cache-diagnosis-2026-04-07";

export interface ChatMessage {
  role: string;
  content: string;
}

export interface AnthropicUsageMetrics {
  input_tokens: number | null;
  output_tokens: number | null;
  cache_read_input_tokens: number | null;
  cache_creation_input_tokens: number | null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : null;
}

function asIntOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.round(value)
    : null;
}

/**
 * chat 形式の messages から Anthropic Messages API の request body を作る。
 * system role のメッセージは top-level `system` blocks に分離し、最後の
 * block に cache_control を付けて prompt caching を有効化する
 * (旧実装は system role を単純に捨てていた)。
 */
export function buildAnthropicMessagesBody(
  messages: ChatMessage[],
  model: string,
  options?: { maxTokens?: number; cacheSystem?: boolean },
): Record<string, unknown> {
  const cacheSystem = options?.cacheSystem ?? true;
  const systemTexts = messages
    .filter((m) => m.role === "system" && String(m.content ?? "").trim())
    .map((m) => String(m.content));
  const chatMessages = messages
    .filter((m) => m.role !== "system")
    .map((m) => ({ role: m.role, content: m.content }));

  const body: Record<string, unknown> = {
    model,
    max_tokens: options?.maxTokens ?? 512,
    messages: chatMessages,
  };
  if (systemTexts.length > 0) {
    body.system = systemTexts.map((text, index) => {
      const block: Record<string, unknown> = { type: "text", text };
      if (cacheSystem && index === systemTexts.length - 1) {
        block.cache_control = { type: "ephemeral" };
      }
      return block;
    });
  }
  return body;
}

/** ANTHROPIC_CACHE_DIAGNOSTICS=1 のとき cache diagnostics beta を有効化する */
export function anthropicCacheDiagnosticsEnabled(): boolean {
  try {
    return Deno.env.get("ANTHROPIC_CACHE_DIAGNOSTICS") === "1";
  } catch {
    return false;
  }
}

/**
 * cache diagnostics を request body に付与する。
 * previousMessageId は同一会話の直前レスポンスの message id (初回は null)。
 */
export function attachCacheDiagnostics(
  body: Record<string, unknown>,
  previousMessageId: string | null,
): Record<string, unknown> {
  body.diagnostics = { previous_message_id: previousMessageId };
  return body;
}

/** Anthropic レスポンスから実測 token / cache 指標を取り出す */
export function extractAnthropicUsage(
  data: unknown,
): AnthropicUsageMetrics | null {
  const usage = asRecord(asRecord(data)?.usage);
  if (!usage) return null;
  const metrics: AnthropicUsageMetrics = {
    input_tokens: asIntOrNull(usage.input_tokens),
    output_tokens: asIntOrNull(usage.output_tokens),
    cache_read_input_tokens: asIntOrNull(usage.cache_read_input_tokens),
    cache_creation_input_tokens: asIntOrNull(
      usage.cache_creation_input_tokens,
    ),
  };
  if (
    metrics.input_tokens === null && metrics.output_tokens === null &&
    metrics.cache_read_input_tokens === null &&
    metrics.cache_creation_input_tokens === null
  ) {
    return null;
  }
  return metrics;
}

/** cache diagnostics レスポンスから cache_miss_reason を取り出す */
export function extractCacheMissReason(data: unknown): string | null {
  const diagnostics = asRecord(asRecord(data)?.diagnostics);
  const reason = diagnostics?.cache_miss_reason;
  return typeof reason === "string" && reason.trim() ? reason.trim() : null;
}

/**
 * messages 配列内 system entry (mid-conversation system message) を
 * サポートするモデルか。2026-07 時点で Claude Opus 4.8 のみ。
 * 非対応モデルに送ると 400 (`role 'system' is not supported on this model`)。
 */
export function supportsMidConversationSystem(model: string): boolean {
  return model.startsWith("claude-opus-4-8");
}

/**
 * 会話の途中で operator 指示を追加する。
 * - 対応モデル (Opus 4.8): `{role: "system"}` を messages 末尾に追加。
 *   top-level system を書き換えないため prompt cache の prefix を壊さない。
 * - 非対応モデル: 最後の user メッセージ末尾に <system-reminder> として
 *   追記する fallback (cache 保持効果は同等、operator 権威性は劣る)。
 *
 * 制約 (対応モデル側): system entry は user メッセージの直後、かつ
 * messages 末尾 (または直後に assistant turn) に置くこと。messages[0] 不可。
 */
export function appendSystemEntry(
  messages: ChatMessage[],
  instruction: string,
  model: string,
): ChatMessage[] {
  const text = instruction.trim();
  if (!text) return messages;
  if (supportsMidConversationSystem(model)) {
    return [...messages, { role: "system", content: text }];
  }
  const reminder = `<system-reminder>\n${text}\n</system-reminder>`;
  const last = messages[messages.length - 1];
  if (last && last.role === "user" && typeof last.content === "string") {
    return [
      ...messages.slice(0, -1),
      { role: "user", content: `${last.content}\n\n${reminder}` },
    ];
  }
  return [...messages, { role: "user", content: reminder }];
}
