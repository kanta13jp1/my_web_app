---
date: 2026-04-17
from: Windowsアプリ版#74
to: VSCode版, PowerShell版
status: pending
priority: medium
---

# AIプロバイダー Phase 2 実装依頼 (要APIキー 13社の実コール実装)

## 概要

Phase 1 (Windows版#74) で `lib/models/ai_provider_registry.dart` にステータスカタログを作成・
`/ai-provider-status` ページで可視化を完了しました。

次は Phase 2 として、**要APIキー** 状態の以下13社の実API呼び出しを実装してください。

## 優先度順 (OpenAI互換グループから着手推奨)

### Group A: OpenAI 互換 (実装難易度 低)

以下は OpenAI SDK を `base_url` だけ差し替えで動く。`ai-assistant/index.ts` の
`createProviderModels()` や `ai-hub:ai.chat` action に追加すると最小差分で取り込める。

1. **xAI (Grok)** — `https://api.x.ai/v1` / Secret: `XAI_API_KEY`
2. **DeepSeek** — `https://api.deepseek.com/v1` / Secret: `DEEPSEEK_API_KEY`
3. **Groq** — `https://api.groq.com/openai/v1` / Secret: `GROQ_API_KEY`
4. **SambaNova** — `https://api.sambanova.ai/v1` / Secret: `SAMBANOVA_API_KEY`
5. **OpenRouter** — `https://openrouter.ai/api/v1` / Secret: `OPENROUTER_API_KEY`
6. **Fireworks AI** — `https://api.fireworks.ai/inference/v1` / Secret: `FIREWORKS_API_KEY`
7. **Together AI** — `https://api.together.xyz/v1` / Secret: `TOGETHER_API_KEY`

### Group B: 独自 API (実装難易度 中)

8. **Perplexity** — Sonar API 独自エンドポイント / Secret: `PERPLEXITY_API_KEY`
9. **Mistral** — `https://api.mistral.ai/v1/chat/completions` / Secret: `MISTRAL_API_KEY`
10. **Cohere** — `https://api.cohere.com/v2/chat` (OpenAI非互換) / Secret: `COHERE_API_KEY`

### Group C: 画像/動画 系 (実装難易度 中〜高)

11. **Stability AI** — `https://api.stability.ai/v2beta/stable-image/generate` / Secret: `STABILITY_API_KEY`
12. **Runware** — `https://api.runware.ai/v1/image-inference` / Secret: `RUNWARE_API_KEY`
13. **Replicate** — `https://api.replicate.com/v1/predictions` / Secret: `REPLICATE_API_TOKEN`

## 推奨実装パターン

### Step 1: ai-hub に `provider.chat` / `provider.image` action を追加

```typescript
case "provider.chat": {
  const providerId = String(body.provider ?? "");
  const messages = body.messages;
  const cfg = PROVIDER_CONFIGS[providerId];
  if (!cfg) return json({ error: `Unknown provider: ${providerId}` }, 400);
  const key = Deno.env.get(cfg.envKey) ?? "";
  if (!key) return json({ success: false, status: "apiKeyRequired", secret_needed: cfg.envKey });

  const resp = await fetch(`${cfg.baseUrl}/chat/completions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: body.model ?? cfg.defaultModel, messages }),
  });
  // ... error handling + paid_plan_required 検知
}
```

### Step 2: `ai_provider_registry.dart` のステータス更新

実装完了後、該当エントリを `AiProviderStatus.implemented` に変更してください。

### Step 3: Secret を Supabase Dashboard に追加

各プロバイダーで API キーを発行し `supabase secrets set <ENVKEY>=...` で登録。

### Step 4: `/ai-provider-status` ページから呼び出しテスト用ボタンを追加 (任意)

各カードに「テスト呼び出し」ボタンを追加して、ボタン押下で `ai-hub:provider.chat` を
`messages: [{role:"user", content:"hello"}]` で叩き、成功/失敗を表示する機能があると
ユーザーがステータスの正しさを視覚的に検証できます。

## 完了条件

- [ ] Group A (7社) が OpenAI 互換で動作
- [ ] Group B (3社) 実装
- [ ] Group C (3社) 実装
- [ ] `ai_provider_registry.dart` 13社のステータス更新
- [ ] `/ai-provider-status` から各プロバイダーの動作確認可能

完了したら `done/` に移動してください。

## 関連ファイル

- `lib/models/ai_provider_registry.dart` (本体)
- `lib/pages/ai_provider_status_page.dart` (UI)
- `supabase/functions/ai-hub/index.ts` (EF — Phase 2 で追加する action を配置)
- `supabase/functions/ai-assistant/index.ts` (参考: 既存3プロバイダー実装例)
