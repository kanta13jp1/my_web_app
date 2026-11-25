import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleCoreHubRequest } from "./index.ts";
import {
  buildDiscordWebhookPayload,
  extractSlackNotificationSummary,
  notifySlackWithDiscordFailover,
  sendDiscordWebhook,
  wantsDiscordFailover,
  wantsDiscordSecondary,
} from "./notification_channels.ts";

Deno.test("wantsDiscordSecondary accepts snake and camel case flags", () => {
  assertEquals(wantsDiscordSecondary({ discord_secondary: true }), true);
  assertEquals(wantsDiscordSecondary({ discordSecondary: "discord" }), true);
  assertEquals(wantsDiscordSecondary({ discord_backup: ["discord"] }), true);
  assertEquals(wantsDiscordSecondary({ discord_secondary: false }), false);
  assertEquals(wantsDiscordSecondary({}), false);
});

Deno.test("buildDiscordWebhookPayload removes mentions and bounds content", () => {
  const payload = buildDiscordWebhookPayload({
    text: "hello",
    username: "Fallback Bot",
    channel: "quota",
  });

  assertEquals(payload.content, "hello");
  assertEquals(payload.username, "Fallback Bot");
  assertEquals(payload.allowed_mentions, { parse: [] });
  assertEquals(Array.isArray(payload.embeds), true);
});

Deno.test("sendDiscordWebhook soft-skips when secondary is disabled", async () => {
  const result = await sendDiscordWebhook({
    enabled: false,
    webhookUrl: "https://discord.example/webhook",
    text: "quota alert",
    fetcher: () => {
      throw new Error("fetch should not run");
    },
  });

  assertEquals(result, {
    enabled: false,
    configured: false,
    success: false,
    skipped: true,
    error: "discord secondary disabled",
  });
});

Deno.test("sendDiscordWebhook soft-skips missing secret", async () => {
  const result = await sendDiscordWebhook({
    enabled: true,
    webhookUrl: "",
    text: "quota alert",
    fetcher: () => {
      throw new Error("fetch should not run");
    },
  });

  assertEquals(result, {
    enabled: true,
    configured: false,
    success: false,
    skipped: true,
    error: "DISCORD_WEBHOOK_URL not configured",
  });
});

Deno.test("sendDiscordWebhook posts a Discord payload when configured", async () => {
  let postedBody = "";
  const result = await sendDiscordWebhook({
    enabled: true,
    webhookUrl: "https://discord.example/webhook",
    text: "quota alert",
    username: "Ops",
    channel: "quota",
    fetcher: (_url, init) => {
      postedBody = String(init?.body ?? "");
      return Promise.resolve(new Response("ok", { status: 200 }));
    },
  });

  assertEquals(result, {
    enabled: true,
    configured: true,
    success: true,
    skipped: false,
    status: 200,
  });
  const payload = JSON.parse(postedBody);
  assertEquals(payload.content, "quota alert");
  assertEquals(payload.username, "Ops");
});

Deno.test("sendDiscordWebhook reports webhook errors without throwing", async () => {
  const result = await sendDiscordWebhook({
    enabled: true,
    webhookUrl: "https://discord.example/webhook",
    text: "quota alert",
    fetcher: () =>
      Promise.resolve(new Response("bad webhook", { status: 500 })),
  });

  assertEquals(result, {
    enabled: true,
    configured: true,
    success: false,
    skipped: false,
    status: 500,
    error: "discord webhook failed: 500",
    detail: "bad webhook",
  });
});

Deno.test("sendDiscordWebhook catches fetch failures", async () => {
  const result = await sendDiscordWebhook({
    enabled: true,
    webhookUrl: "https://discord.example/webhook",
    text: "quota alert",
    fetcher: () => Promise.reject(new Error("network down")),
  });

  assertEquals(result, {
    enabled: true,
    configured: true,
    success: false,
    skipped: false,
    error: "network down",
  });
});

Deno.test("sendDiscordWebhook skips non-https webhook URLs", async () => {
  const result = await sendDiscordWebhook({
    enabled: true,
    webhookUrl: "http://discord.example/webhook",
    text: "quota alert",
    fetcher: () => {
      throw new Error("insecure fetch should not run");
    },
  });

  assertEquals(result.skipped, true);
  assertEquals(result.configured, false);
  assertEquals(result.error, "DISCORD_WEBHOOK_URL must use https://");
});

Deno.test("wantsDiscordFailover defaults true and honors explicit opt-outs", () => {
  assertEquals(wantsDiscordFailover({}), true);
  assertEquals(wantsDiscordFailover({ discord_failover: false }), false);
  assertEquals(wantsDiscordFailover({ discordFailover: "off" }), false);
  assertEquals(wantsDiscordFailover({ disable_discord_failover: true }), false);
  assertEquals(wantsDiscordFailover({ discord_secondary: false }), false);
  assertEquals(wantsDiscordFailover({ discord_secondary: true }), true);
});

Deno.test("extractSlackNotificationSummary reads Slack block text fallback", () => {
  const summary = extractSlackNotificationSummary(
    "",
    [
      { type: "section", text: { type: "mrkdwn", text: "Deploy alert #2704" } },
      { type: "section", text: "Latency threshold exceeded" },
    ],
    "fallback text",
  );
  assertEquals(summary, "Deploy alert #2704\nLatency threshold exceeded");
});

Deno.test("notifySlackWithDiscordFailover fails over when Slack env is unset", async () => {
  const calls: string[] = [];
  const res = await notifySlackWithDiscordFailover({
    body: {},
    channel: "alerts",
    text: "Database backup check failed",
    blocks: null,
    getEnv: (name) =>
      name === "DISCORD_WEBHOOK_URL"
        ? "https://discord.example/webhook"
        : undefined,
    fetcher: (url) => {
      calls.push(String(url));
      return Promise.resolve(new Response(null, { status: 204 }));
    },
  });

  assertEquals(res.status, 200);
  assertEquals(calls, ["https://discord.example/webhook"]);
  assertEquals(res.payload.success, true);
  assertEquals(res.payload.failover_used, true);
  assertEquals(res.payload.delivered_via, "discord_failover");
  assertEquals(res.payload.primary_status, "unconfigured");
});

Deno.test("notifySlackWithDiscordFailover fails over automatically on Slack 429", async () => {
  const calls: string[] = [];
  const res = await notifySlackWithDiscordFailover({
    body: {},
    channel: "ci",
    text: "CI outage alert",
    blocks: null,
    getEnv: (name) => {
      if (name === "SLACK_WEBHOOK_CI") return "https://hooks.slack.example/ci";
      if (name === "DISCORD_WEBHOOK_URL") {
        return "https://discord.example/webhook";
      }
      return undefined;
    },
    fetcher: (url) => {
      calls.push(String(url));
      if (String(url).includes("slack.example")) {
        return Promise.resolve(new Response("rate_limited", { status: 429 }));
      }
      return Promise.resolve(new Response("ok", { status: 200 }));
    },
  });

  assertEquals(res.status, 200);
  assertEquals(calls, [
    "https://hooks.slack.example/ci",
    "https://discord.example/webhook",
  ]);
  assertEquals(res.payload.failover_used, true);
  assertEquals(res.payload.slack_status, 429);
});

Deno.test("notifySlackWithDiscordFailover catches Slack fetch throws and fails over", async () => {
  const res = await notifySlackWithDiscordFailover({
    body: {},
    channel: "default",
    text: "Primary timeout alert",
    blocks: null,
    getEnv: (name) => {
      if (name === "SLACK_WEBHOOK_URL") {
        return "https://hooks.slack.example/default";
      }
      if (name === "DISCORD_WEBHOOK_URL") {
        return "https://discord.example/webhook";
      }
      return undefined;
    },
    fetcher: (url) => {
      if (String(url).includes("slack.example")) {
        return Promise.reject(new Error("slack network timeout"));
      }
      return Promise.resolve(new Response("ok", { status: 200 }));
    },
  });

  assertEquals(res.status, 200);
  assertEquals(res.payload.failover_used, true);
  assertEquals(res.payload.primary_error, "slack network timeout");
});

Deno.test("notifySlackWithDiscordFailover respects explicit opt-out when Slack fails", async () => {
  const calls: string[] = [];
  const res = await notifySlackWithDiscordFailover({
    body: { discord_failover: false },
    channel: "default",
    text: "Do not mirror",
    blocks: null,
    getEnv: (name) => {
      if (name === "SLACK_WEBHOOK_URL") {
        return "https://hooks.slack.example/default";
      }
      if (name === "DISCORD_WEBHOOK_URL") {
        return "https://discord.example/webhook";
      }
      return undefined;
    },
    fetcher: (url) => {
      calls.push(String(url));
      return Promise.resolve(new Response("bad gateway", { status: 502 }));
    },
  });

  assertEquals(res.status, 502);
  assertEquals(calls, ["https://hooks.slack.example/default"]);
  assertEquals(res.payload.failover_used, false);
});

Deno.test("notifySlackWithDiscordFailover skips Discord when Slack succeeds without secondary flag", async () => {
  const calls: string[] = [];
  const res = await notifySlackWithDiscordFailover({
    body: {},
    channel: "default",
    text: "Normal delivery",
    blocks: null,
    getEnv: (name) => {
      if (name === "SLACK_WEBHOOK_URL") {
        return "https://hooks.slack.example/default";
      }
      if (name === "DISCORD_WEBHOOK_URL") {
        return "https://discord.example/webhook";
      }
      return undefined;
    },
    fetcher: (url) => {
      calls.push(String(url));
      return Promise.resolve(new Response("ok", { status: 200 }));
    },
  });

  assertEquals(res.status, 200);
  assertEquals(calls, ["https://hooks.slack.example/default"]);
  assertEquals(res.payload.delivered_via, "slack");
  assertEquals(res.payload.failover_used, false);
});

Deno.test("handleCoreHubRequest slack.notify fails over across outage modes", async () => {
  const srk = ["expected", "service", "role", "key"].join("-");
  const authHdr = ["Bea" + "rer", srk].join(" ");
  const envMap: Record<string, string> = {
    DISCORD_WEBHOOK_URL: "https://discord.example/webhook",
    SLACK_WEBHOOK_ALERTS: "https://hooks.slack.example/alerts",
  };
  const postCore = (action: string, body: Record<string, unknown>) =>
    new Request("https://example.test/functions/v1/core-hub", {
      method: "POST",
      headers: {
        authorization: authHdr,
        "content-type": "application/json",
      },
      body: JSON.stringify({ action, ...body }),
    });

  const postedUrls: string[] = [];
  const outageResp = await handleCoreHubRequest(
    postCore("slack.notify", {
      channel: "alerts",
      text: "Production alert #2704",
    }),
    {
      serviceRoleKey: srk,
      createAdminClient: () => ({} as never),
      getEnv: (name) => envMap[name],
      fetcher: (input) => {
        const url = String(input);
        postedUrls.push(url);
        if (url.includes("slack.example")) {
          return Promise.resolve(new Response("unavailable", { status: 503 }));
        }
        return Promise.resolve(new Response(null, { status: 204 }));
      },
      reportError: () => {},
    },
  );
  assertEquals(outageResp.status, 200);
  const outageJson = await outageResp.json();
  assertEquals(outageJson.failover_used, true);
  assertEquals(outageJson.delivered_via, "discord_failover");
  assertEquals(postedUrls, [
    "https://hooks.slack.example/alerts",
    "https://discord.example/webhook",
  ]);

  const missingResp = await handleCoreHubRequest(
    postCore("slack.notify", {
      channel: "quota",
      text: "Quota threshold alert",
    }),
    {
      serviceRoleKey: srk,
      createAdminClient: () => ({} as never),
      getEnv: (name) => envMap[name],
      fetcher: (input) => {
        if (String(input).includes("discord.example")) {
          return Promise.resolve(new Response("ok", { status: 200 }));
        }
        throw new Error("unexpected slack call");
      },
      reportError: () => {},
    },
  );
  assertEquals(missingResp.status, 200);
  const missingJson = await missingResp.json();
  assertEquals(missingJson.failover_used, true);
  assertEquals(missingJson.primary_status, "unconfigured");

  const optOutResp = await handleCoreHubRequest(
    postCore("slack.notify", {
      channel: "alerts",
      text: "Opt-out alert",
      discord_failover: false,
    }),
    {
      serviceRoleKey: srk,
      createAdminClient: () => ({} as never),
      getEnv: (name) => envMap[name],
      fetcher: () => Promise.resolve(new Response("err", { status: 500 })),
      reportError: () => {},
    },
  );
  assertEquals(optOutResp.status, 502);

  const directResp = await handleCoreHubRequest(
    postCore("discord.notify", {
      channel: "ci",
      text: "Direct Discord failover test",
    }),
    {
      serviceRoleKey: srk,
      createAdminClient: () => ({} as never),
      getEnv: (name) => envMap[name],
      fetcher: () => Promise.resolve(new Response(null, { status: 204 })),
      reportError: () => {},
    },
  );
  assertEquals(directResp.status, 200);
  const directJson = await directResp.json();
  assertEquals(directJson.success, true);
  assertEquals(directJson.discord.status, 204);
});
