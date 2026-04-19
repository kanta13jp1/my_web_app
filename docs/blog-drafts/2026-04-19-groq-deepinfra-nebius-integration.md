---
title: "Groq・DeepInfra・Nebiusを1つのEdge Functionに統合する — 3プロバイダー並行ルーティング"
tags: Supabase,AI,Groq,個人開発,buildinpublic
published: true
---

# Groq・DeepInfra・Nebiusを1つのEdge Functionに統合する

## 背景: AIプロバイダーの使い分け

コスト・速度・品質は AIプロバイダーによって異なる:

| プロバイダー | 強み | 主なモデル |
|------------|------|----------|
| **Groq** | 超高速 (Inference Engine) | Llama 3.3 70B |
| **DeepInfra** | 多モデル・安価 | 400+ モデル |
| **Nebius** | 高品質テキスト生成 | Llama 3.1 70B |

これら3つを1つの Edge Function `ai-hub` に統合した。

## アーキテクチャ: action パターン

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
};
```

## 統合ルーター

```typescript
case 'provider.chat': {
  const { provider, messages, model } = params;
  const config = PROVIDER_CONFIGS[provider];
  
  if (!config) {
    return new Response(JSON.stringify({ error: `Unknown provider: ${provider}` }), {
      status: 400,
    });
  }

  const apiKey = Deno.env.get(config.apiKeyEnv);
  const response = await fetch(`${config.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: model ?? config.defaultModel,
      messages,
    }),
  });

  const data = await response.json();
  return new Response(JSON.stringify({
    content: data.choices[0].message.content,
    provider,
    model: data.model,
  }));
}
```

## Flutter からの呼び出し

```dart
// lib/services/ai_provider_service.dart
Future<String> chat(String provider, String userMessage) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {
      'action': 'provider.chat',
      'provider': provider,  // 'groq' | 'deepinfra' | 'nebius'
      'messages': [
        {'role': 'user', 'content': userMessage},
      ],
    },
  );
  return response.data['content'] as String;
}
```

## 自動ルーティング (provider.chat_auto)

コストと速度を自動最適化するルーター:

```typescript
case 'provider.chat_auto': {
  const { messages, priority } = params;

  // priority: 'speed' | 'cost' | 'quality'
  const providerOrder = {
    speed:   ['groq', 'deepinfra', 'nebius'],
    cost:    ['deepinfra', 'groq', 'nebius'],
    quality: ['nebius', 'groq', 'deepinfra'],
  }[priority ?? 'speed'];

  for (const provider of providerOrder) {
    try {
      const result = await callProvider(provider, messages);
      return new Response(JSON.stringify({ ...result, provider }));
    } catch (e) {
      // 次のプロバイダーにフォールバック
      console.error(`${provider} failed: ${e}`);
    }
  }
  
  return new Response(JSON.stringify({ error: 'All providers failed' }), { status: 503 });
}
```

## AI大学での活用

各プロバイダーの概要を **そのプロバイダー自身のモデル** で生成する:

```dart
// Groq の概要を Groq (llama-3.3-70b) で生成
final summary = await aiProviderService.chat(
  'groq',
  'Groqの特徴と主要モデルを200字で説明してください',
);
```

自己紹介させることで各プロバイダーの「声」が反映される。

## まとめ

| 手法 | 効果 |
|------|------|
| 単一EFに集約 | EF本数を増やさない (50本ハードキャップ) |
| PROVIDER_CONFIGS | 新プロバイダーを設定1行で追加可能 |
| フォールバック | 1社落ちても自動切替 |
| priority指定 | speed/cost/quality で用途別最適化 |

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #AI #Groq #buildinpublic #個人開発
