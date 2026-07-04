type SlackText = {
  type: "plain_text" | "mrkdwn";
  text: string;
  emoji?: boolean;
};

type SlackBlock =
  | {
    type: "header";
    text: SlackText;
  }
  | {
    type: "section";
    text?: SlackText;
    fields?: SlackText[];
  }
  | {
    type: "context";
    elements: SlackText[];
  };

export type SignupSlackPayload = {
  text: string;
  blocks: SlackBlock[];
  unfurl_links: false;
  unfurl_media: false;
};

const SIGNUP_CHANNEL_LABELS: Record<string, string> = {
  signup_submit_landing: "landing",
  signup_submit_import: "import",
  signup_submit_public_memo: "public_memo",
  signup_submit_referral: "referral",
  signup_submit_comparison: "comparison",
  signup_submit_guitar: "guitar",
};

export function resolveSignupChannel(signalKey: unknown): string {
  if (typeof signalKey !== "string") return "unknown";
  const normalized = signalKey.trim();
  if (normalized in SIGNUP_CHANNEL_LABELS) {
    return SIGNUP_CHANNEL_LABELS[normalized];
  }
  if (normalized.startsWith("touch_comparison")) return "comparison";
  if (normalized.startsWith("touch_referral")) return "referral";
  if (normalized.startsWith("touch_import")) return "import";
  if (normalized.startsWith("touch_public_memo")) return "public_memo";
  if (normalized.startsWith("touch_landing")) return "landing";
  return "unknown";
}

export function isRecentSignupCreatedAt(
  createdAt: string,
  now = new Date(),
  maxAgeHours = 48,
): boolean {
  const created = Date.parse(createdAt);
  if (!Number.isFinite(created)) return false;
  const ageMs = now.getTime() - created;
  return ageMs >= 0 && ageMs <= maxAgeHours * 60 * 60 * 1000;
}

export function buildSignupSlackPayload(input: {
  totalUsers: number | null;
  signalKey: unknown;
  signupUserId: string;
  createdAt: string;
  appUrl?: string;
  now?: Date;
}): SignupSlackPayload {
  const totalUsers = typeof input.totalUsers === "number" &&
      Number.isFinite(input.totalUsers) && input.totalUsers > 0
    ? Math.trunc(input.totalUsers)
    : null;
  const userNumber = totalUsers === null ? "#?" : `#${totalUsers}`;
  const channel = resolveSignupChannel(input.signalKey);
  const shortUserId = input.signupUserId.trim().slice(0, 8) || "unknown";
  const appUrl = input.appUrl?.trim() || "https://my-web-app-b67f4.web.app/";
  const createdAt = input.createdAt.trim() || new Date().toISOString();
  const detectedAt = (input.now ?? new Date()).toISOString();
  const text =
    `:tada: New signup ${userNumber} registered (channel: ${channel})`;

  return {
    text,
    unfurl_links: false,
    unfurl_media: false,
    blocks: [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: `New signup ${userNumber}`,
          emoji: true,
        },
      },
      {
        type: "section",
        fields: [
          { type: "mrkdwn", text: `*Channel*\n${channel}` },
          {
            type: "mrkdwn",
            text: `*Signup signal*\n${input.signalKey || "unknown"}`,
          },
          { type: "mrkdwn", text: `*User ref*\n${shortUserId}` },
          { type: "mrkdwn", text: `*Total users*\n${userNumber}` },
        ],
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text:
            `First-user sprint signal detected. Check activation quickly: ${appUrl}`,
        },
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: `created_at=${createdAt} detected_at=${detectedAt}`,
          },
        ],
      },
    ],
  };
}
