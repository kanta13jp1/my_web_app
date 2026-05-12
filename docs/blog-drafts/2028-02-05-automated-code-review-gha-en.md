---
title: "Automate Code Review with GitHub Actions and Claude API"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# Automate Code Review with GitHub Actions and Claude API

Indie devs have no reviewers. Wire Claude API into GitHub Actions to auto-review every PR.

## Why Automate Code Review

```
Indie dev problem:
  - No reviewers → bugs reach production
  - Self-review misses your own blind spots
  - "I'll check it tomorrow" → never happens

Solution:
  PR opened → GHA trigger → Claude reviews diff → posts as PR comment
```

## GitHub Actions Workflow

```yaml
# .github/workflows/claude-pr-review.yml
name: Claude PR Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR diff
        id: diff
        run: |
          DIFF=$(git diff origin/${{ github.base_ref }}...HEAD \
            -- '*.dart' '*.ts' '*.sql' \
            | head -c 8000)
          echo "diff<<EOF" >> $GITHUB_OUTPUT
          echo "$DIFF" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Claude review
        id: review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          REVIEW=$(curl -s https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d '{
              "model": "claude-haiku-4-5-20251001",
              "max_tokens": 1024,
              "messages": [{
                "role": "user",
                "content": "Review this diff. Flag bugs, security risks, and performance issues. Also mention 1-2 things done well.\n\n```diff\n'"${{ steps.diff.outputs.diff }}"'\n```"
              }]
            }' | jq -r '.content[0].text')
          echo "review<<EOF" >> $GITHUB_OUTPUT
          echo "$REVIEW" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Post review comment
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## 🤖 Claude Review\n\n${{ steps.review.outputs.review }}`
            });
```

## Cost Optimization

```
Model choice:
  claude-haiku-4-5  → fast, cheap ($0.80/MTok input)
  claude-sonnet-4-6 → higher quality ($3/MTok input)

Cap diff at 8,000 chars:
  Large PRs: summarize or pick key files only

Monthly cost estimate (haiku, 50 PRs/mo, avg 4,000 chars):
  Input:  50 × 4,000 chars ≈ 200K tokens × $0.80 = $0.16
  Output: 50 × 1,000 tokens × $4.00             = $0.20
  Total:  ~$0.36/month
```

## Higher-Quality Review Prompt

```yaml
- name: Claude review
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    curl -s https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d '{
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1500,
        "system": "You are a senior Flutter + Supabase engineer. You are strong on security, performance, and Flutter/Dart best practices.",
        "messages": [{
          "role": "user",
          "content": "Review this PR diff across:\n1. Bugs / logic errors\n2. Security risks (missing RLS, auth gaps)\n3. Flutter performance (unnecessary rebuilds)\n4. Dart conventions (async/await, null safety)\n5. 1-2 things done well\n\n```diff\n${DIFF}\n```"
        }]
      }'
```

## Gemini Fallback

```yaml
- name: Review with fallback
  run: |
    REVIEW=$(call_claude "$DIFF") || \
    REVIEW=$(call_gemini "$DIFF")
    echo "$REVIEW"
```

## Summary

```
Trigger        → PR opened / synchronize
Get diff       → git diff, limit to relevant files + 8K chars
Claude review  → haiku model, ~$0.36/month
Post result    → PR comment via github-script
Fallback       → Gemini for redundancy
```

You don't need a team to get code review. $0.36/month cuts your bug-to-production rate significantly.

