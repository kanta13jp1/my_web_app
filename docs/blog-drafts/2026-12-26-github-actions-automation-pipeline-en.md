---
title: "GitHub Actions Automation Pipeline: From Blog Posts to AI Video Generation"
tags: ai,automation,indiedev,programming
published: true
---

# GitHub Actions Automation Pipeline: From Blog Posts to AI Video Generation

Running a solo dev project means you can't afford to do the same thing twice. I've automated blog publishing, video generation, competitor monitoring, and infrastructure health checks via GitHub Actions. Here's the architecture.

## Full Workflow Map

```
Daily 06:00 JST
  ├── daily-report.yml       → KPI fetch → Slack notification
  ├── cs-check.yml           → pending tickets → AI reply
  └── ai-university-update.yml → RSS feeds → DB update

Weekly Sunday JST
  ├── evaluate-predictions.yml → horse racing accuracy evaluation
  └── weekly-sns-draft.yml    → X post draft generation

Manual / PR-triggered
  ├── blog-publish.yml       → dev.to + Qiita post
  ├── deploy-prod.yml        → Firebase Hosting deploy
  └── video-pipeline.yml     → NotebookLM → ElevenLabs → video
```

## blog-publish.yml: The Orphan Branch Pattern

```yaml
on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'JA draft path'
      draft_path_en:
        description: 'EN draft path'
      platforms:
        default: 'devto'
      dry_run:
        default: 'false'
```

The key design decision is the **orphan branch pattern**:

```yaml
- name: Update published:true
  run: |
    sed -i 's/^published: false/published: true/' "${{ inputs.draft_path }}"
    git commit -m "published: ${{ inputs.draft_path }}"
    git push origin HEAD:blog-publish/${{ github.run_id }}-$(date +%Y%m%d-%H%M%S)
```

The `published: true` update goes to a dedicated branch, not `main`. Claude Code merges it after verifying the post URL. This pattern avoids branch conflicts with parallel instances.

## video-pipeline.yml: Fully Automated AI Video

```yaml
steps:
  - name: Generate script via NotebookLM
    run: notebooklm ask "$TOPIC" > script.md

  - name: Generate audio via ElevenLabs
    run: |
      curl -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
        -H "xi-api-key: $ELEVENLABS_KEY" \
        -d "{\"text\": \"$(cat script.md)\"}" \
        > audio.mp3

  - name: Render video via Remotion
    run: npx remotion render VideoTemplate --props='{"audioFile":"audio.mp3"}'

  - name: Upload to Supabase storage
    run: supabase storage upload videos/$(date +%Y%m%d).mp4 output/video.mp4
```

NotebookLM generates the script → ElevenLabs converts to audio → Remotion renders the video. Zero manual steps.

## cs-check.yml: AI Customer Support

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'  # every 6 hours

steps:
  - name: Get pending tickets
    run: |
      TICKETS=$(curl -s "$SUPABASE_URL/functions/v1/get-support-tickets" \
        -H "Authorization: Bearer $SERVICE_KEY")

  - name: AI reply via Claude Haiku
    run: |
      echo "$TICKETS" | claude --model claude-haiku-4-5 \
        "Reply to these support tickets. Be helpful and specific."
```

Every 6 hours: check tickets → Haiku drafts reply → EF posts it. Using Haiku keeps the cost minimal.

## Three Design Principles

**1. Claude-independent design for cron tasks.**  
Scheduled workflows don't depend on Claude API availability. API outages don't interrupt operations. Haiku is used for reply drafts, but design/judgment tasks are separated.

**2. dry_run on every dispatch workflow.**  
Every manually dispatched workflow has a `dry_run` input. New workflows are always verified dry before live.

**3. Right concurrency settings per workflow.**  
`deploy-prod` uses `cancel-in-progress: false` (queue, don't drop). `blog-publish` allows cancellation (duplicate-post prevention is handled by the pre-check step, not concurrency config).

## The Result

After full automation, my time on routine operations dropped to near zero. Blog posts, CS responses, competitor monitoring, video generation — all handled by cron. What remains: deciding what to build next. That's the CEO-only model applied to solo dev.
