---
title: "Indie Dev Launch Checklist — Product Hunt, HN, and SNS Simultaneous Rollout"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Launch Checklist — Product Hunt, HN, and SNS Simultaneous Rollout

A battle-tested checklist for maximizing your first launch. On launch day, decision fatigue is the enemy — everything must be prepared in advance.

## Pre-Launch (1 Week Before)

```markdown
## Infrastructure
- [ ] Production URL accessible (HTTPS required)
- [ ] Error monitoring (Sentry / Supabase Logs) active
- [ ] Automated DB backups configured
- [ ] Rate limiting (Edge Function throttle) set

## Assets
- [ ] OGP image (1200×630px)
- [ ] Demo video (under 60 seconds)
- [ ] 3+ screenshots
- [ ] Tagline (under 60 characters)
- [ ] "3 value propositions" in bullet form
```

## Product Hunt Post Template

```markdown
## Tagline (under 60 chars)
The AI Life OS that replaces Notion, MoneyForward, and Slack

## Description
【Problem】Too many tools, scattered information
【Solution】Jibun Inc: 21 competitors consolidated into one app
【Differentiation】AI automates daily decision-making

## First Comment (personal intro + backstory)
Hi! I'm Kanta, an indie dev from Japan.
[Background in 100-200 words]
Today only: doubling free plan storage → [URL]
```

## HN Show HN Template

```markdown
Show HN: [App Name] – [One-line description] ([URL])

[Tech stack: Flutter Web + Supabase]
[Problem in 1 paragraph]
[Numbers: user count / feature count / dev time]
[Invite feedback]
```

## Launch Day GHA Automation

```yaml
# .github/workflows/launch-day.yml
on:
  workflow_dispatch:
    inputs:
      launch_url:
        required: true

jobs:
  post-x:
    steps:
      - name: Post launch tweet
        run: |
          curl -X POST "$SUPABASE_EF_URL/post-x-update" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
            -d "{\"message\": \"We launched! ${{ inputs.launch_url }} #buildinpublic #indiedev\"}"
```

## Summary

```
Infrastructure   → error monitoring + rate limiting set up in advance
Assets           → OGP + video + tagline ready before launch day
Product Hunt     → tagline ≤60 chars + first comment adds human touch
HN               → strict Show HN: format + include technical details
SNS automation   → GHA posts automatically so you focus on responses
```

On launch day, your only job is to execute. Finish all prep the day before.
