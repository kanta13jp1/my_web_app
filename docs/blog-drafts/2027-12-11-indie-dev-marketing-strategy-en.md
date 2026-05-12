---
title: "Indie Dev Marketing Strategy: Product Hunt, X, and dev.to"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Marketing Strategy: Product Hunt, X, and dev.to

"Built it, but no one showed up" is the most common failure pattern. Three channels to market while you build.

## The Reality of Indie Dev Marketing

```
Common failure path:
  build (3 months) → launch → no visitors (1 week) → give up

Right approach:
  market while building → launch with an audience already waiting
```

## Channel 1: dev.to for Organic Traffic

```
dev.to strengths:
  - Strong SEO (ranks on Google page 1 reliably)
  - English posts reach a global developer audience
  - Cost: $0
  - 100 posts → ~5,000-10,000 organic visits/month
```

**Strategy: target competitor + tech keyword combinations**:

```
Post title examples:
  "Supabase vs Firebase: Which to Choose for Flutter in 2026"
  "Flutter Web vs React: Performance Comparison"
  "Claude API vs OpenAI: Cost and Capabilities for Indie Devs"

→ rides competitor search volume
→ naturally mentions your product in the comparison
```

**Automate with GHA**:

```yaml
on:
  schedule:
    - cron: '0 9 * * MON'
jobs:
  check-drafts:
    steps:
      - run: |
          COUNT=$(find docs/blog-drafts -name "*-en.md" \
            | xargs grep -l "^published: false" | wc -l)
          if [ "$COUNT" -gt 2 ]; then
            echo "⚠️ $COUNT unpublished drafts — post this week"
          fi
```

## Channel 2: X (Twitter) — Build in Public

```
#buildinpublic impact:
  - Show the process → followers become advocates
  - Post failures → most retweeted content
  - Share KPIs openly → builds trust and accountability
```

**Weekly KPI post template**:

```
This week's #buildinpublic update 📊

MAU:  234 (+12%↑)
MRR: $156 (+8%↑)
Posts published: 3

What I did:
- Shipped Supabase Auth MFA
- Improved Flutter Web LCP: 3.2s → 1.8s
- Published 3 dev.to articles

Next week:
- Prep Product Hunt listing
- 2 user interviews

#flutter #supabase #indiedev
```

**Auto-post with GHA**:

```yaml
on:
  schedule:
    - cron: '0 9 * * MON'
jobs:
  post-weekly-kpi:
    steps:
      - name: Fetch KPI from Supabase
        run: |
          KPI=$(curl -s "$SUPABASE_URL/functions/v1/kpi-weekly" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY")
          echo "MAU=$(echo $KPI | jq '.mau')" >> $GITHUB_ENV
      - name: Post to X
        run: |
          curl -X POST "$SUPABASE_URL/functions/v1/post-x-update" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
            -d "{\"text\": \"Weekly #buildinpublic update: MAU $MAU\"}"
```

## Channel 3: Product Hunt — One-Shot Awareness Spike

```
Launch timing:
  - Tue–Thu (avoid Mon, Fri, weekends)
  - Starts at PST 00:01 — 24-hour window
  - Prepare 50+ supporters before launch day

Launch checklist:
  ✅ Landing page finished
  ✅ 60-second demo video (silent + subtitles)
  ✅ Tagline under 60 characters
  ✅ 5 gallery images (1200×630px)
  ✅ Message supporters (day before + morning of launch)
```

**Launch day playbook**:

```
9:00 AM PST:  launch notification → share on Twitter/Slack/Discord
12:00 PM:     reply to every comment (response rate affects ranking)
6:00 PM:      progress update "Currently #X on Product Hunt 🚀"
Midnight:     post final result (publish no matter what rank)
```

## Time Allocation

```
For an indie dev with 20 hours/week:
  Building:             12h (60%)
  dev.to articles:       3h (15%)
  X #buildinpublic:      1h (5%)
  Product Hunt prep:     1h (5%)
  User support:          3h (15%)
```

## Summary

```
Long-term organic traffic → dev.to (SEO compound effect)
Community building        → X #buildinpublic (weekly KPI sharing)
One-shot awareness spike  → Product Hunt launch
Automation                → GHA for KPI posts + draft reminders
```

Don't build then market. Build AND market simultaneously. dev.to for steady trust, X for the ongoing narrative, Product Hunt for the launch moment. That three-part combination is the indie dev marketing playbook.

