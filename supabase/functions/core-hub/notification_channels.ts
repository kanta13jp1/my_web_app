export type DiscordNotifyResult = {
  enabled: boolean;
  configured: boolean;
  success: boolean;
  skipped: boolean;
  status?: number;
  error?: string;
  detail?: string;
};

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export function wantsDiscordSecondary(body: Record<string, unknown>): boolean {
  const value = body.discord_secondary ?? body.discordSecondary ??
    body.discord_backup ?? body.discordBackup;
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "1" ||
      normalized === "discord" || normalized === "secondary";
  }
  if (Array.isArray(value)) {
    return value.some((item) => String(item).toLowerCase() === "discord");
  }
  return false;
}

export function buildDiscordWebhookPayload(input: {
  text: string;
  username?: unknown;
  channel?: string;
}): Record<string, unknown> {
  const content = input.text.trim().slice(0, 2000) ||
    "Slack notification mirrored to Discord.";
  const username = typeof input.username === "string" &&
      input.username.trim() !== ""
    ? input.username.trim().slice(0, 80)
    : "my_web_app fallback";
  return {
    content,
    username,
    allowed_mentions: { parse: [] },
    embeds: input.channel
      ? [{
        title: "Fallback notification",
        fields: [{ name: "Slack channel", value: input.channel }],
      }]
      : undefined,
  };
}

export async function sendDiscordWebhook(input: {
  enabled: boolean;
  webhookUrl: string;
  text: string;
  username?: unknown;
  channel?: string;
  fetcher?: Fetcher;
}): Promise<DiscordNotifyResult> {
  if (!input.enabled) {
    return {
      enabled: false,
      configured: false,
      success: false,
      skipped: true,
      error: "discord secondary disabled",
    };
  }

  const webhookUrl = input.webhookUrl.trim();
  if (!webhookUrl) {
    return {
      enabled: true,
      configured: false,
      success: false,
      skipped: true,
      error: "DISCORD_WEBHOOK_URL not configured",
    };
  }

  try {
    const fetcher = input.fetcher ?? fetch;
    const resp = await fetcher(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(buildDiscordWebhookPayload(input)),
    });
    if (!resp.ok) {
      const detail = await resp.text();
      return {
        enabled: true,
        configured: true,
        success: false,
        skipped: false,
        status: resp.status,
        error: `discord webhook failed: ${resp.status}`,
        detail: detail.slice(0, 500),
      };
    }
    return {
      enabled: true,
      configured: true,
      success: true,
      skipped: false,
      status: resp.status,
    };
  } catch (error) {
    return {
      enabled: true,
      configured: true,
      success: false,
      skipped: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
