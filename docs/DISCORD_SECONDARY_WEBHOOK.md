# Discord Secondary Webhook

Issue #1035 adds Discord as an optional secondary notification channel for the
multi-AI fallback workflow. Slack remains the primary notification path.

## Secret

Set the Supabase Edge Function secret:

```bash
supabase secrets set DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

## Mirror a Slack Notification

Use the existing `core-hub` `slack.notify` action and opt in per payload:

```json
{
  "action": "slack.notify",
  "channel": "quota",
  "text": "AI fallback quota alert",
  "discord_secondary": true
}
```

`discordSecondary: true`, `discord_backup: true`, and `discordBackup: true` are
also accepted.

If `DISCORD_WEBHOOK_URL` is missing or Discord returns an error, the Slack
notification path still keeps its original success/failure behavior. The Discord
result is included in the JSON response as `discord`.

## Direct Smoke Test

To send a test payload directly from the Edge Function path:

```json
{
  "action": "discord.notify",
  "text": "Discord fallback notification test"
}
```

When the secret is missing, `discord.notify` returns a skipped result instead of
failing deployment or Slack notification flows.
