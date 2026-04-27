---
title: "Supabase Edge Functions + AI: Real Cost Breakdown and Optimization Patterns"
tags: supabase,ai,programming,saas
published: true
---

# Supabase Edge Functions + AI: Real Cost Breakdown and Optimization Patterns

## "What Does It Actually Cost to Run AI Through Edge Functions?"

Jibun Kaisha routes all AI API calls through Supabase Edge Functions (Deno). When I started building this architecture, the cost picture was completely opaque. Here's what twelve months of real usage revealed.

---

## The Architecture

```
Flutter Web
  └→ Supabase Edge Function (Deno)
        ├→ Claude API (Anthropic)
        ├→ Gemini API (Google)
        └→ OpenAI API
```

**Why not call APIs directly from the frontend?** API keys stay server-side, and Row Level Security lets us enforce per-user rate limits without custom auth logic.

---

## Real Monthly Cost Breakdown

### Supabase (Edge Functions)

| Plan | Monthly | Edge Function Calls | Overage |
|------|---------|---------------------|---------|
| Free | $0 | 500,000 | Stops |
| Pro | $25 | 2,000,000 | $2/1M |

**Actual usage**: Pro plan. ~150,000 Edge Function calls per month. Well within limits.

### AI API Costs

| API | Monthly Tokens | Monthly Cost |
|-----|---------------|--------------|
| Claude Sonnet 4.6 | 8M input + 1.2M output | ~$30 |
| Gemini 1.5 Flash | 12M input + 2M output | ~$4 |
| OpenAI GPT-4o mini | 3M input + 0.5M output | ~$2 |

**Total**: Supabase $25 + AI APIs $36 ≈ **$61/month**

---

## Edge Functions Runtime Costs

### Cold Start Latency

Deno Edge Functions cold-start in **200–500ms**. Since AI API calls already take 1–5 seconds, the user experience impact is minimal — but infrequently-called functions will cold-start on every request.

**Fix**: Warm up key functions via GHA cron:

```yaml
# .github/workflows/keep-warm.yml
- name: Warm up AI functions
  run: |
    curl -s "https://${PROJECT_REF}.supabase.co/functions/v1/ai-assistant?ping=1" \
      -H "Authorization: Bearer $ANON_KEY" &
    curl -s "https://${PROJECT_REF}.supabase.co/functions/v1/daily-judgment?ping=1" \
      -H "Authorization: Bearer $ANON_KEY" &
    wait
```

### Timeout Limit

Default timeout is **150 seconds**. Long Claude outputs can breach this.

**Fix**: Use streaming responses:

```typescript
const stream = await anthropic.messages.stream({
  model: "claude-sonnet-4-6",
  max_tokens: 2048,
  messages: [{ role: "user", content: prompt }],
});

return new Response(stream.toReadableStream(), {
  headers: {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    ...corsHeaders,
  },
});
```

---

## Cost Optimization Patterns

### 1. Circuit Breaker

When an AI API starts returning errors, stop sending requests immediately.

```typescript
const { data: breaker } = await supabase
  .from("ai_circuit_breaker")
  .select("state, expires_at")
  .eq("provider", "anthropic")
  .single();

if (breaker?.state === "open" && new Date(breaker.expires_at) > new Date()) {
  return json({ error: "AI service temporarily unavailable" }, 503);
}
```

### 2. Response Caching

Cache identical prompts in Supabase DB to avoid redundant API calls:

```typescript
const cacheKey = createHash("sha256").update(prompt).toString();
const { data: cached } = await supabase
  .from("ai_cache")
  .select("response")
  .eq("key", cacheKey)
  .gt("expires_at", new Date().toISOString())
  .single();

if (cached) return json({ result: cached.response, cached: true });
```

**Real result**: Daily report functions hit ~**40% cache rate** — multiple users requesting the same data on the same day.

### 3. Model Tiering

Match model cost to task complexity:

| Task | Model | Reason |
|------|-------|--------|
| Complex reasoning / strategy | claude-sonnet-4-6 | Accuracy-first |
| Templated report generation | gemini-1.5-flash | Cost-first |
| Tagging / classification | gpt-4o-mini | Speed + cost |
| Batch processing | claude-haiku-4-5 | High-volume |

### 4. Prompt Caching (Anthropic)

Anthropic's Prompt Caching gives **90% discount** on repeated system prompt tokens:

```typescript
const response = await anthropic.messages.create({
  model: "claude-sonnet-4-6",
  system: [
    {
      type: "text",
      text: LONG_SYSTEM_PROMPT, // 2000+ tokens
      cache_control: { type: "ephemeral" },
    },
  ],
  messages: [{ role: "user", content: userMessage }],
});
```

**Real result**: The `cs-check` function (automated customer support replies) has a 3,000-token system prompt. After enabling caching: **63% reduction in input costs**.

---

## EF Cost Attribution

| Edge Function | Monthly Calls | AI Model | Est. Monthly Cost |
|--------------|---------------|----------|-------------------|
| `ai-assistant` | 1,200 | claude-sonnet-4-6 | $8 |
| `daily-judgment` | 30 | claude-sonnet-4-6 | $4 |
| `cs-check` (GHA) | 60 | claude-sonnet-4-6 + cache | $3 |
| `ai-university-update` | 1,440 | gemini-1.5-flash | $2 |
| `get-home-dashboard` | 8,000 | (no AI) | $0 |
| Others | 140,000 | (no AI) | $0 |

---

## Summary: What to Expect

- **$60–80/month** covers Supabase Pro + Claude/Gemini/OpenAI for a solo project
- Circuit breaker + caching + Prompt Caching can cut costs by **40–60%**
- The real cost driver is AI API usage, not Supabase itself
- Cold starts are manageable with scheduled warmup requests

Supabase Edge Functions are production-ready for AI backends. If you need API key protection and per-user rate limiting without running your own server, this architecture is worth the setup cost.

---

## Related Posts

- [litellm: One Gateway for All AI APIs](./2026-08-01-litellm-unified-ai-gateway-en.md)
- [LangGraph State Machine Patterns in Practice](./2026-08-08-langgraph-state-machine-patterns-en.md)
- [Real Costs of a Multi-AI Workflow](./2026-07-25-multi-ai-workflow-real-costs-en.md)

---

*Jibun Kaisha — integrating the best of 21 competitors into one life management app*  
*Live: https://my-web-app-b67f4.web.app/*
