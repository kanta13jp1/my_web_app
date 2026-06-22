import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildDiscordWebhookPayload,
  sendDiscordWebhook,
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
