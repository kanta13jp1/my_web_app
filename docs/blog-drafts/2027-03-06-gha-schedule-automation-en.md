---
title: "GitHub Actions Schedule: $0/Month Automation Infrastructure for Solo Founders"
tags: ai,automation,indiedev,programming
published: true
---

# GitHub Actions Schedule: $0/Month Automation Infrastructure for Solo Founders

This project runs fully automated infrastructure using GitHub Actions schedule triggers. Cost: $0/month. Here's the full design — what runs, how it's wired, and the three months of lessons from operating it.

## What's Running

| Workflow | Schedule | Purpose |
|---|---|---|
| `daily-report.yml` | Daily 9:00 JST | KPI aggregation → Slack |
| `cs-check.yml` | Hourly | Support tickets → AI replies |
| `blog-publish.yml` | workflow_dispatch | T-1 blog publishing |
| `ai-university-update.yml` | Daily 6:00 JST | RSS collection → Supabase |
| `competitor-monitoring.yml` | Daily 3:00 JST | 21 competitor availability checks |
| `health-monitor.yml` | Every 30 min | Infrastructure health check |
| `claude-agent-review.yml` | On PR create | AI code review |
| `wbs-staleness-audit.yml` | Weekly Monday | Task staleness detection |

## Basic Structure: schedule Trigger

```yaml
name: Daily Report
on:
  schedule:
    - cron: '0 0 * * *'  # UTC 0:00 = JST 9:00
  workflow_dispatch:       # manual trigger also available

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate report
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
        run: |
          REPORT=$(curl -sf \
            -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
            "$SUPABASE_URL/functions/v1/schedule-hub" \
            -d '{"action":"digest.run"}')
          echo "$REPORT" | jq .
```

## cs-check.yml: Automated Customer Support

```yaml
name: CS Check
on:
  schedule:
    - cron: '0 * * * *'   # hourly

jobs:
  cs-check:
    runs-on: ubuntu-latest
    steps:
      - name: Get unread tickets
        id: tickets
        run: |
          TICKETS=$(curl -sf \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_KEY }}" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/get-support-tickets")
          echo "tickets=$TICKETS" >> $GITHUB_OUTPUT
          
      - name: AI reply via Claude
        if: steps.tickets.outputs.tickets != '[]'
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          python scripts/cs_auto_reply.py \
            --tickets '${{ steps.tickets.outputs.tickets }}'
```

## Free Tier Math

```
GitHub Actions free tier: 2,000 min/month (public repos: unlimited)

Current consumption:
  daily-report: 5 min/day × 30 days = 150 min
  cs-check: 2 min/run × 24 runs × 30 days = 1,440 min
  health-monitor: 1 min/run × 48 runs × 30 days = 1,440 min
  Total: ~3,030 min

→ Public repo: free (unlimited minutes)
  Private repo: reduce cs-check to every 2 hours → 720 min
```

This project uses a public repo, so there's no limit. For private repos, reduce cs-check frequency to stay under 2,000 minutes.

## Failure Notification Design

```yaml
- name: Report on failure
  if: failure()
  run: |
    curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
      -H 'Content-type: application/json' \
      --data "{\"text\": \"❌ ${{ github.workflow }} failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\"}"
```

**Silent on success, loud on failure.** Sending notifications for every run trains you to ignore them.

## GHA + Supabase Edge Function Architecture

```
GHA (scheduler / trigger)
  ↓ HTTP POST
Supabase Edge Function (business logic)
  ↓ SQL
PostgreSQL (persistent data)
  ↓ Realtime
Flutter Web (live UI)
```

Putting logic in EFs instead of GHA scripts gives you:
- Simple, readable YAML (GHA is trigger-only)
- EFs testable in isolation locally
- Multiple workflows can share the same EF

## Semi-Automation with workflow_dispatch + inputs

```yaml
on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'Blog draft path (JA)'
        required: true
      platforms:
        description: 'Target platforms (devto,qiita)'
        default: 'devto'
        
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Publish blog post
        run: |
          python scripts/blog_publish.py \
            --draft "${{ inputs.draft_path }}" \
            --platforms "${{ inputs.platforms }}"
```

`blog-publish.yml` uses this pattern. AI instances dispatch via `gh workflow run`. Humans only review the published URL.

## Three Months of Production Data

- Total runs: ~3,000
- Failure rate: 2.1% (mostly external API timeouts)
- Human interventions: 3–5 per month (429 rate limits, expired API keys)
- Cost: $0

## Summary

Four principles for $0/month automation infrastructure:

1. **Use GHA as a scheduler only.** Logic lives in Supabase Edge Functions, not shell scripts.
2. **Notify on failure only.** Silent success prevents alert fatigue.
3. **Public repo = unlimited minutes.** Secrets stay in GitHub Secrets, sensitive config stays out of code.
4. **workflow_dispatch + inputs = semi-automation.** AI dispatches, human reviews the result.

You don't need servers to build infrastructure that runs while you sleep. GitHub Actions + Supabase Edge Functions is the most cost-effective automation stack available to solo founders in 2026.
