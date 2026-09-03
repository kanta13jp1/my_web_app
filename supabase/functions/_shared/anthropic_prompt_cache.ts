// Anthropic Messages API prompt-caching request builder.
// Static system instructions are moved to the top-level `system` prefix while
// dynamic user/assistant turns remain in `messages`.

export const ANTHROPIC_PROMPT_CACHE_ENV = "ANTHROPIC_PROMPT_CACHE_ENABLED";

export interface AnthropicChatMessage {
  role: string;
  content: string;
}

export interface AnthropicMessagesBodyOptions {
  maxTokens?: number;
  cacheSystem?: boolean;
}

const DISABLED_VALUES = new Set(["0", "false", "off", "disabled", "no"]);

/** Prompt caching is enabled by default and may be disabled system-wide. */
export function anthropicPromptCacheEnabled(
  configuredValue: string | null | undefined,
): boolean {
  const normalized = configuredValue?.trim().toLowerCase();
  return normalized === undefined || normalized === "" ||
    !DISABLED_VALUES.has(normalized);
}

/**
 * Builds an Anthropic Messages request without mixing stable system content
 * into dynamic conversation turns. The last system block is the explicit
 * five-minute cache breakpoint when caching is enabled.
 */
export function buildAnthropicMessagesBody(
  messages: AnthropicChatMessage[],
  model: string,
  options: AnthropicMessagesBodyOptions = {},
): Record<string, unknown> {
  const systemTexts = messages
    .filter((message) =>
      message.role === "system" && message.content.trim().length > 0
    )
    .map((message) => message.content);
  const chatMessages = messages
    .filter((message) => message.role !== "system")
    .map((message) => ({
      role: message.role,
      content: message.content,
    }));

  const body: Record<string, unknown> = {
    model,
    max_tokens: options.maxTokens ?? 512,
    messages: chatMessages,
  };
  if (systemTexts.length === 0) return body;

  body.system = systemTexts.map((text, index) => ({
    type: "text",
    text,
    ...(options.cacheSystem !== false && index === systemTexts.length - 1
      ? { cache_control: { type: "ephemeral" } }
      : {}),
  }));
  return body;
}
