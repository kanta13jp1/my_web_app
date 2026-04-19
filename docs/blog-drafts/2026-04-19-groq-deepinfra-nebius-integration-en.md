---
title: "Integrating Groq, DeepInfra, and Nebius in One Edge Function — 3-Provider AI Routing"
tags: Supabase,AI,Groq,buildinpublic,webdev
published: true
---

# Integrating Groq, DeepInfra, and Nebius in One Edge Function

## Why Three Providers?

Each AI provider has different strengths:

| Provider | Strength | Model |
|----------|----------|-------|
| **Groq** | Extremely fast (custom Inference Engine) | Llama 3.3 70B |
| **DeepInfra** | 400+ models, lowest cost | Llama 3.3 70B Turbo |
| **Nebius** | High quality prose generation | Llama 3.1 70B |

Rather than three separate Edge Functions, I integrated all three into a single `ai-hub` EF using an action dispatch pattern.

## Architecture: PROVIDER_CONFIGS Map

```typescript
// supabase/functions/ai-hub/index.ts
const PROVIDER_CONFIGS = {
  groq: {
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'llama-3.3-70b-versatile',
    apiKeyEnv: 'GROQ_API_KEY',
  },
  deepinfra: {
    baseUrl: 'https://api.deepinfra.com/v1/openai',
    defaultModel: 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
    apiKeyEnv: 'DEEPINFRA_API_KEY',
  },
  nebius: {
    baseUrl: 'https://api.studio.nebius.ai/v1',
    defaultModel: 'meta-llama/Meta-Llama-3.1-70B-Instruct',
    apiKeyEnv: 'NEBIUS_API_KEY',
  },
} as const;
```

Adding a new provider is one config entry — no new EF needed.

## The Router Case

```typescript
case 'provider.chat': {
  const { provider, messages, model } = params;
  const config = PROVIDER_CONFIGS[provider as keyof typeof PROVIDER_CONFIGS];

  if (!config) {
    return err(`Unknown provider: ${provider}`);
  }

  const apiKey = Deno.env.get(config.apiKeyEnv);
  const res = await fetch(`${config.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: model ?? config.defaultModel, messages }),
  });

  const data = await res.json();
  return ok({ content: data.choices[0].message.content, provider, model: data.model });
}
```

## Flutter Client

```dart
// Single method works for all three providers
Future<String> chat(String provider, String message) async {
  final res = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {
      'action': 'provider.chat',
      'provider': provider,   // 'groq' | 'deepinfra' | 'nebius'
      'messages': [{'role': 'user', 'content': message}],
    },
  );
  return res.data['content'] as String;
}
```

## Auto-Routing with Priority

```typescript
case 'provider.chat_auto': {
  const { messages, priority = 'speed' } = params;

  const providerOrder: Record<string, string[]> = {
    speed:   ['groq', 'deepinfra', 'nebius'],
    cost:    ['deepinfra', 'groq', 'nebius'],
    quality: ['nebius', 'groq', 'deepinfra'],
  };

  for (const provider of providerOrder[priority]) {
    try {
      return ok(await callProvider(provider, messages));
    } catch (e) {
      console.error(`${provider} failed, trying next...`);
    }
  }
  return err('All providers failed', 503);
}
```

Pass `priority: 'speed'` for chat, `priority: 'quality'` for summaries, `priority: 'cost'` for batch jobs.

## AI University Use Case

Each provider introduces itself using its own model:

```dart
// Groq explains itself via its own Llama model
final summary = await chat('groq', 
  'Explain Groq in 100 words — what makes it unique?');
```

The self-description approach gives each provider a distinctive "voice" in the learning content.

## Result

| Approach | Benefit |
|----------|---------|
| Single EF | Stays under 50-EF hard cap |
| PROVIDER_CONFIGS | New provider = one config entry |
| Fallback loop | Auto-failover if one provider is down |
| Priority routing | Speed/cost/quality optimization per use case |

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #AI #Groq #buildinpublic #EdgeFunctions
