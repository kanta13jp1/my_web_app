---
title: "Indie Dev Cost Management: Designing a $0→$100/Month Stack"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Cost Management: Designing a $0→$100/Month Stack

Avoid the "suddenly I'm paying $500/month" trap. Here's a phase-based cost design I use in production.

## Early Stage ($0/month): Max the Free Tiers

```
Stack:
  Frontend:  Flutter Web → Firebase Hosting (free, 1GB/month)
  Backend:   Supabase Free Tier
    DB:                500MB
    Edge Functions:    500K executions/month
    Auth:              50K MAU
    Storage:           1GB
  AI API:    Claude Haiku ($0.80/M tokens — cheapest capable model)
  Email:     Resend Free (100 emails/day)
  CI/CD:     GitHub Actions (2,000 min/month)
```

**Free tier trap to watch for**:

```
Supabase Free: project pauses after 1 week of inactivity
→ Fix: weekly health-check cron in GHA
  on:
    schedule:
      - cron: '0 9 * * MON'
  steps:
    - run: curl -sf "$SUPABASE_URL/functions/v1/health-check"
```

## Growth Stage ($10-30/month): Minimal Paid Upgrades

```
Added cost:
  Supabase Pro: $25/month
    DB:                8GB
    Edge Functions:    2M executions/month
    Branch feature     (preview environments)
    No inactivity pause
  Total: ~$25/month
```

**Claude API cost optimization**:

```dart
// Route to haiku vs sonnet → 80% cost reduction
String selectModel(String taskType) {
  return switch (taskType) {
    'classification' => 'claude-haiku-4-5',  // $0.80/M: classify/short
    'summarization'  => 'claude-haiku-4-5',  // $0.80/M: summarize
    'analysis'       => 'claude-sonnet-4-6', // $3/M: deep reasoning
    'generation'     => 'claude-sonnet-4-6', // $3/M: content gen
    _                => 'claude-haiku-4-5',
  };
}
```

**Prompt Caching — 89% reduction**:

```python
# Cache the system prompt on first call (Claude API)
messages = [
  {
    "role": "user",
    "content": [
      {
        "type": "text",
        "text": system_prompt,
        "cache_control": {"type": "ephemeral"}  # mark for caching
      },
      {
        "type": "text",
        "text": user_input
      }
    ]
  }
]
# Second call onward: cache hit → ~90% input token cost reduction
```

## Scaling Stage ($50-100/month): Right-sized Upgrades

```
Cost breakdown:
  Supabase Pro:    $25/month (fixed)
  Firebase:        $5-20/month (Hosting + Functions)
  Claude API:      $10-30/month (depends on MAU)
  Resend:          $20/month (10K emails/month Pro)
  Vercel/CF Pages: $0 (free tiers sufficient)
  Total:           $60-95/month
```

**Weekly cost monitoring with GHA**:

```yaml
on:
  schedule:
    - cron: '0 9 * * MON'

jobs:
  cost-report:
    steps:
      - name: Claude API usage
        run: |
          USAGE=$(curl -s "https://api.anthropic.com/v1/usage" \
            -H "x-api-key: $ANTHROPIC_API_KEY")
          echo "Input tokens:  $(echo $USAGE | jq '.input_tokens')"
          echo "Output tokens: $(echo $USAGE | jq '.output_tokens')"
```

## Cost Design Principles

```
1. Never pay until you've exhausted the free tier
2. Haiku first, sonnet only when quality demands it
3. Cache aggressively — CDN + Prompt Cache
4. Weekly cost alert → Slack notification on anomalies
5. At $100/month, revisit pricing model (paid plans or feature gates)
```

**Break-even math**:

```
$100/month infra ÷ $7/user/month (≈ ¥980)
→ Break-even: ~14 paying users
→ Profitable at 20 users — very achievable
```

Cost management in indie dev is about maximizing the ceiling before you need to pay. A stack that handles hundreds of MAU under $100/month is realistic with this approach.

