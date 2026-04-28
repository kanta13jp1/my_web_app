---
title: "Claude API Cost Optimization: Haiku vs Sonnet and Prompt Caching Cut My Bill 70%"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# Claude API Cost Optimization: Haiku vs Sonnet and Prompt Caching Cut My Bill 70%

My Claude API costs went from $80/month to $24/month. Here's exactly what I changed.

## Model Selection Principle

```
claude-haiku-4-5:    lightweight tasks / high-frequency calls (cheapest)
claude-sonnet-4-6:   complex reasoning / design work (balanced)
claude-opus-4-7:     maximum accuracy only (most expensive)
```

**Rough cost ratio**:
```
haiku : sonnet : opus = 1 : 5 : 15
```

## Routing Tasks to the Right Model

```typescript
function selectModel(taskType: string): string {
  switch (taskType) {
    case 'cs_reply':          return 'claude-haiku-4-5-20251001';
    case 'competitor_check':  return 'claude-haiku-4-5-20251001';
    case 'daily_judgment':    return 'claude-haiku-4-5-20251001';
    case 'code_review':       return 'claude-sonnet-4-6';
    case 'architecture':      return 'claude-sonnet-4-6';
    default:                  return 'claude-haiku-4-5-20251001';  // default to cheapest
  }
}
```

## Prompt Caching: 90% Off Repeated Tokens

Sending a long system prompt on every call means paying for it every time. With Prompt Caching, cached tokens cost **90% less**.

```typescript
const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 1024,
  system: [
    {
      type: 'text',
      text: LONG_SYSTEM_PROMPT,  // thousands of tokens
      cache_control: { type: 'ephemeral' },  // enable caching
    },
  ],
  messages: [{ role: 'user', content: userMessage }],
});
```

**Cost example**:

```
System prompt: 2,000 tokens
Daily calls:   100

Without cache: 2,000 × 100 = 200,000 tokens/day
With cache:    2,000 (first) + 2,000 × 0.1 × 99 = 21,800 tokens/day
Reduction:     89%
```

## Minimize Input Tokens

```typescript
// ❌ BAD: passing entire context every time
const response = await anthropic.messages.create({
  messages: [{
    role: 'user',
    content: `${entireUserHistory}\n\n${question}`,
  }],
});

// ✅ GOOD: only recent relevant context
const recentHistory = userHistory.slice(-5);
const response = await anthropic.messages.create({
  messages: [
    ...recentHistory,
    { role: 'user', content: question },
  ],
});
```

## Batch Processing for Throughput

```typescript
// ❌ BAD: sequential — 100 items × 1s = 100s
for (const item of items) {
  const result = await callClaude(item);
}

// ✅ GOOD: parallel batches within rate limits
const BATCH_SIZE = 5;
for (let i = 0; i < items.length; i += BATCH_SIZE) {
  const batch = items.slice(i, i + BATCH_SIZE);
  const results = await Promise.all(batch.map(callClaude));
  if (i + BATCH_SIZE < items.length) {
    await new Promise(resolve => setTimeout(resolve, 500));
  }
}
```

## Cost Monitoring via GHA

```yaml
# .github/workflows/cost-monitor.yml
on:
  schedule:
    - cron: '0 9 * * *'  # 9am daily

jobs:
  check:
    steps:
      - name: Check API usage
        run: |
          USAGE=$(curl -s "https://api.anthropic.com/v1/usage" \
            -H "x-api-key: $ANTHROPIC_API_KEY")
          TOTAL=$(echo $USAGE | jq '.total_tokens')
          if [ $TOTAL -gt 10000000 ]; then
            echo "⚠️ Monthly token usage exceeded threshold: $TOTAL"
            # trigger Slack alert or GitHub Issue
          fi
```

## Actual Results

```
Before (January 2026):
  claude-opus:   60% → $62
  claude-sonnet: 30% → $18
  Total: $80/month

After (April 2026):
  claude-haiku:  80% → $12
  claude-sonnet: 20% → $12 (with Prompt Caching)
  Total: $24/month
  Reduction: 70%
```

## Summary

```
Cost reduction priority:
  1. Model routing (haiku for everything it can handle)
  2. Prompt Caching (repeated system prompts)
  3. Minimize input tokens (trim context windows)
  4. Batch processing (parallelize within rate limits)
  5. Usage monitoring (auto-alert via GHA)
```

With smart model routing and Prompt Caching, you can build production-quality AI features at a fraction of the naive cost. Start with "haiku first" — the savings are immediate.
