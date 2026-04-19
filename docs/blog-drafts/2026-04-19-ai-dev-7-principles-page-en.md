---
title: "7 Principles for Safe, Fast AI Feature Development — Distilled from Real Production Incidents"
tags: AI,Flutter,buildinpublic,architecture,webdev
published: true
---

# 7 Principles for Safe, Fast AI Feature Development

## Why Principles?

AI dev tools accelerate building. They also accelerate *invisible failures*:

- API key silently overwritten → auth breaks at 2am
- Hallucination loop with no quality gate → garbage committed
- Batch job exceeds cost limit → surprise bill
- Error untraceable without `trace_id` → can't debug

I distilled these 7 principles from NotebookLM research on developers who built 23 pages of an app in a single day — and paid for the invisible defaults they missed.

## Principle 1: Auth Layer — Single Source of Truth

```typescript
// ❌ Dangerous: hardcoded fallback
const GROQ_KEY = process.env.GROQ_KEY ?? "sk-hardcoded-fallback";

// ✅ Safe: always from Secrets, fail loudly if missing
const GROQ_KEY = Deno.env.get("GROQ_API_KEY");
if (!GROQ_KEY) throw new Error("GROQ_API_KEY not set");
```

`Deno.env.get()` always reads the current secret value — no stale cache.

## Principle 2: Deny-by-Default Security

Auth, rate limiting, and input validation from day one. Adding them later costs 3× more.

```typescript
const { data: { user } } = await supabase.auth.getUser(jwt);
if (!user) return new Response('Unauthorized', { status: 401 });

const count = await redis.incr(`ratelimit:${user.id}`);
if (count === 1) await redis.expire(`ratelimit:${user.id}`, 60);
if (count > 60) return new Response('Rate limited', { status: 429 });
```

## Principle 3: Trace-based Observability

```typescript
const traceId = crypto.randomUUID();
const start = Date.now();

console.log(JSON.stringify({ traceId, action, status: "start" }));

// ... work ...

const elapsed = Date.now() - start;
if (elapsed > 5000) {
  console.warn(JSON.stringify({ traceId, elapsed, status: "slow" }));
}
```

Every AI call gets a `traceId`. Anything over 5 seconds is flagged. This is the minimal bar.

## Principle 4: Cost Circuit Breaker (4 Tiers)

| Tier | Limit | Action |
|------|-------|--------|
| Request | 500 tokens | Truncate input |
| Agent | 10 req/session | Return error |
| Business | $5/day | Send alert |
| Platform | $50/month | Disable API |

```typescript
const { data } = await supabase.rpc('get_daily_cost', { user_id: user.id });
if (data.total_usd > 5.0) {
  return new Response(JSON.stringify({ error: 'daily_limit_exceeded' }), { status: 429 });
}
```

## Principle 5: Team Memory + Effectiveness Score

Log what worked, decay what didn't.

```typescript
await supabase.from('ai_team_memory').upsert({
  action,
  prompt_hash: hashPrompt(systemPrompt),
  success: true,
  response_quality: 0.9,
});
```

Low-scoring prompts get deprioritized automatically on the next run.

## Principle 6: Checkpoint + Retry with Dead Letter Queue

```typescript
// Save intermediate state
await supabase.from('ai_checkpoints').upsert({
  job_id: jobId,
  step: 'summarize',
  result: summaryResult,
});

// On failure, route to dead letter queue
if (attempts >= 3) {
  await supabase.from('ai_dlq').insert({ job_id: jobId, error, payload });
}
```

## Principle 7: Quality Gate (Sentinel + Warden)

Before committing AI output:

```typescript
function sentinelCheck(output: string, input: string): boolean {
  // Flag entities in output that weren't in input
  const hallucinations = extractEntities(output)
    .filter(e => !extractEntities(input).includes(e));
  return hallucinations.length === 0;
}

function wardenCheck(output: string, spec: string): boolean {
  // Verify output meets the spec (length, format, required fields)
  return output.length > 50 && output.includes('##');
}
```

Both gates must pass before the output is used.

## Current Score for Existing Features

| Feature | Score | Gaps |
|---------|-------|------|
| ai-hub (tag suggest) | 5/7 | Memory + Quality gate |
| blog-publish | 2/7 | Almost everything |
| competitor-monitoring | 3/7 | Circuit breaker + retry |

**6+/7 is the bar for new AI features.** Below that means the feature isn't ready for production use.

## The Payoff

Speed without safety creates technical debt that compounds invisibly. These 7 principles are an upfront investment that pays off the first time an API key rotates, a cost spike occurs, or a hallucination would have shipped.

---
Building in public: https://my-web-app-b67f4.web.app/
#AI #Flutter #buildinpublic #architecture
