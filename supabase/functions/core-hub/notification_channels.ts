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

export const SLACK_WEBHOOK_ENV_MAP: Record<string, string> = {
  default: "SLACK_WEBHOOK_URL",
  quota: "SLACK_WEBHOOK_QUOTA",
  ci: "SLACK_WEBHOOK_CI",
  alerts: "SLACK_WEBHOOK_ALERTS",
  daily: "SLACK_WEBHOOK_DAILY",
  handoff: "SLACK_WEBHOOK_HANDOFF",
};

function isExplicitFalseFlag(value: unknown): boolean {
  if (typeof value === "boolean") return value === false;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "false" || normalized === "0" ||
      normalized === "off" || normalized === "disabled" ||
      normalized === "none";
  }
  return false;
}

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

export function wantsDiscordFailover(body: Record<string, unknown>): boolean {
  if (body.disable_discord_failover === true) return false;
  if (body.disableDiscordFailover === true) return false;
  for (
    const value of [
      body.discord_failover,
      body.discordFailover,
      body.discord_secondary,
      body.discordSecondary,
      body.discord_backup,
      body.discordBackup,
    ]
  ) {
    if (isExplicitFalseFlag(value)) return false;
  }
  return true;
}

export function extractSlackNotificationSummary(
  text: string,
  blocks: unknown[] | null,
  fallback: string,
): string {
  if (text.trim() !== "") return text.trim();
  if (Array.isArray(blocks) && blocks.length > 0) {
    const parts: string[] = [];
    for (const block of blocks) {
      if (block === null || typeof block !== "object") continue;
      const record = block as Record<string, unknown>;
      const blockText = record.text;
      if (typeof blockText === "string" && blockText.trim() !== "") {
        parts.push(blockText.trim());
      } else if (
        blockText !== null &&
        typeof blockText === "object" &&
        typeof (blockText as Record<string, unknown>).text === "string"
      ) {
        parts.push(String((blockText as Record<string, unknown>).text).trim());
      }
      if (parts.join("\n").length >= 1800) break;
    }
    const combined = parts.filter(Boolean).join("\n").slice(0, 2000).trim();
    if (combined !== "") return combined;
  }
  return fallback;
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

  if (!webhookUrl.startsWith("https://")) {
    return {
      enabled: true,
      configured: false,
      success: false,
      skipped: true,
      error: "DISCORD_WEBHOOK_URL must use https://",
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

export async function notifySlackWithDiscordFailover(input: {
  body: Record<string, unknown>;
  channel: string;
  text: string;
  blocks: unknown[] | null;
  getEnv?: (name: string) => string | undefined;
  fetcher?: Fetcher;
}): Promise<{ status: number; payload: Record<string, unknown> }> {
  const getEnv = input.getEnv ?? ((name: string) => Deno.env.get(name));
  const fetcher = input.fetcher ?? fetch;
  const envKey = SLACK_WEBHOOK_ENV_MAP[input.channel] ?? "SLACK_WEBHOOK_URL";
  const slackUrl = (getEnv(envKey) ?? "").trim();
  const discordUrl = (getEnv("DISCORD_WEBHOOK_URL") ?? "").trim();
  const failoverEnabled = wantsDiscordFailover(input.body);
  const mirrorEnabled = wantsDiscordSecondary(input.body);
  const username = input.body.discord_username ?? input.body.username;

  if (!slackUrl) {
    const discord = await sendDiscordWebhook({
      enabled: failoverEnabled,
      webhookUrl: discordUrl,
      text: extractSlackNotificationSummary(
        input.text,
        input.blocks,
        `Slack ${input.channel} webhook unconfigured failover.`,
      ),
      username,
      channel: input.channel,
      fetcher,
    });
    if (discord.success) {
      return {
        status: 200,
        payload: {
          success: true,
          delivered_via: "discord_failover",
          failover_used: true,
          primary_failed: true,
          primary_status: "unconfigured",
          primary_error: `webhook not configured: ${envKey}`,
          channel: input.channel,
          envKey,
          discord,
        },
      };
    }
    return {
      status: 500,
      payload: {
        success: false,
        failover_used: false,
        primary_status: "unconfigured",
        error: `webhook not configured: ${envKey}`,
        channel: input.channel,
        envKey,
        discord,
      },
    };
  }

  const slackPayload: Record<string, unknown> = {};
  if (input.text) slackPayload.text = input.text;
  if (input.blocks) slackPayload.blocks = input.blocks;

  let resp: Response;
  try {
    resp = await fetcher(slackUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(slackPayload),
    });
  } catch (error) {
    const primaryError = error instanceof Error ? error.message : String(error);
    const discord = await sendDiscordWebhook({
      enabled: failoverEnabled,
      webhookUrl: discordUrl,
      text: extractSlackNotificationSummary(
        input.text,
        input.blocks,
        `Slack ${input.channel} network failure failover.`,
      ),
      username,
      channel: input.channel,
      fetcher,
    });
    if (discord.success) {
      return {
        status: 200,
        payload: {
          success: true,
          delivered_via: "discord_failover",
          failover_used: true,
          primary_failed: true,
          primary_error: primaryError.slice(0, 500),
          channel: input.channel,
          envKey,
          discord,
        },
      };
    }
    return {
      status: 502,
      payload: {
        success: false,
        failover_used: false,
        error: "slack webhook fetch failed",
        detail: primaryError.slice(0, 500),
        channel: input.channel,
        envKey,
        discord,
      },
    };
  }

  if (!resp.ok) {
    const errBody = await resp.text();
    const primaryError = `slack webhook failed: ${resp.status}`;
    const discord = await sendDiscordWebhook({
      enabled: failoverEnabled,
      webhookUrl: discordUrl,
      text: extractSlackNotificationSummary(
        input.text,
        input.blocks,
        `Slack ${input.channel} notification failed.`,
      ),
      username,
      channel: input.channel,
      fetcher,
    });
    if (discord.success) {
      return {
        status: 200,
        payload: {
          success: true,
          delivered_via: "discord_failover",
          failover_used: true,
          primary_failed: true,
          slack_status: resp.status,
          primary_error: primaryError,
          detail: errBody.slice(0, 500),
          channel: input.channel,
          envKey,
          discord,
        },
      };
    }
    return {
      status: 502,
      payload: {
        success: false,
        failover_used: false,
        error: primaryError,
        detail: errBody.slice(0, 500),
        channel: input.channel,
        envKey,
        discord,
      },
    };
  }

  const discord = await sendDiscordWebhook({
    enabled: mirrorEnabled,
    webhookUrl: discordUrl,
    text: extractSlackNotificationSummary(
      input.text,
      input.blocks,
      `Slack ${input.channel} notification mirrored to Discord.`,
    ),
    username,
    channel: input.channel,
    fetcher,
  });

  return {
    status: 200,
    payload: {
      success: true,
      delivered_via: mirrorEnabled && discord.success
        ? "slack+discord"
        : "slack",
      failover_used: false,
      channel: input.channel,
      envKey,
      status: resp.status,
      discord,
    },
  };
}
