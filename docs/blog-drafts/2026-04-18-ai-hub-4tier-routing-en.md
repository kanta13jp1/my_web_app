---
title: "Building a 4-Tier AI Cost Auto-Router with Deno Edge Functions"
tags: Flutter,Supabase,buildinpublic,webdev,AI
published: false
---

# Building a 4-Tier AI Cost Auto-Router with Deno Edge Functions

When your app supports 33 AI providers, you need a smart way to route requests. I built a 4-tier cost auto-router that starts cheap and escalates only when needed.

## The Problem

With 33 providers in my AI Hub, picking one manually is painful. I needed:

- **Cost optimization**: Use free providers when they work
- **Automatic failover**: If one provider is down, try the next
- **Quality tiers**: Different tasks need different quality levels

## The 4-Tier Design

```typescript
const TIER_PROVIDERS: Record<Tier, string[]> = {
  free:        ["deepseek", "groq", "cerebras", "siliconflow", "novita_ai"],
  budget:      ["sambanova", "arcee_ai", "minimax", "deepinfra", "together_ai", "fireworks_ai", "moonshot"],
  performance: ["openai", "google", "mistral", "cohere", "perplexity", "nebius", "qwen"],
  premium:     ["anthropic", "openai", "google"],
};

const TIER_COST_USD_PER_1K: Record<Tier, number> = {
  free:        0.0001,
  budget:      0.001,
  performance: 0.01,
  premium:     0.05,
};
```

| Tier | Est. cost/1K tokens | When to use |
|------|---------------------|-------------|
| **Free** | $0.0001 | Routine tasks, prototyping |
| **Budget** | $0.001 | General inference |
| **Performance** | $0.01 | Quality-critical tasks |
| **Premium** | $0.05 | Complex reasoning, max quality |

## The Router Logic

The key insight: try providers in order, escape immediately on success.

```typescript
outerLoop:
for (let ti = startTierIndex; ti < TIER_ORDER.length; ti++) {
  const tier = TIER_ORDER[ti];
  const providers = TIER_PROVIDERS[tier].filter((p) => p in PROVIDER_CONFIGS);
  for (const pid of providers) {
    const result = await callSingleProvider(pid, finalMessages, undefined);
    if (result.ok && result.text) {
      resultText = result.text;
      usedProvider = pid;
      usedTier = tier;
      usedModel = result.modelUsed;
      break outerLoop;  // ← escape both loops on first success
    }
  }
}
```

You can also pass a `startTier` to skip directly to a higher tier when you know cheap won't cut it.

## Calling It from Flutter

```dart
final resp = await _supabase.functions.invoke(
  'ai-hub',
  body: {
    'action': 'provider.chat_auto',
    'message': userMessage,
    // 'tier': 'performance',  // optional: skip to a specific tier
  },
);
final data = resp.data as Map<String, dynamic>;
// data contains: provider, tier, model, text
```

The response tells you *which provider actually answered* — useful for transparency and debugging.

## Cost Logging

Every successful call logs to `ai_hub_chat_logs`:

```typescript
await admin.from("ai_hub_chat_logs").insert({
  provider: usedProvider,
  tier: usedTier,
  success: true,
  estimated_cost_usd: TIER_COST_USD_PER_1K[usedTier] * (messageLength / 1000),
  model: usedModel,
});
```

This lets you see distribution over time: how often does free tier succeed? When do you escalate to premium?

## Results

In practice, the **free tier handles ~80% of requests** (DeepSeek and Groq are very reliable). Budget tier picks up the rest. Premium is rarely needed — and that's the point.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #DenoJS
