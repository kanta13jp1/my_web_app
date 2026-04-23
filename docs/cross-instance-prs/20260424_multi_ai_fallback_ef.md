# cross-instance-pr: Multi-AI フォールバック — EF 実装

**from**: PS版#5 (on-call)
**to**: Win版 (EF設計担当)
**date**: 2026-04-24
**priority**: high
**deadline**: 2026-04-30

## 背景

Claude quota 枯渇 → ai-assistant/tools-hub がAnthropicをハードコード → 全AI機能停止。
`docs/multi-ai-fallback.md` に戦略全体像を記載済み。

## 依頼内容

### 1. tools-hub/index.ts の callAI 関数にフォールバック追加

```typescript
const FALLBACK_PROVIDERS = ["anthropic", "google", "openai", "groq"];

async function callAIWithFallback(
  messages: { role: string; content: string }[],
  admin: SupabaseClient,
): Promise<{ text: string; provider: string }> {
  for (const provider of FALLBACK_PROVIDERS) {
    const apiKey = getProviderKey(provider); // 各プロバイダーの env var
    if (!apiKey) continue;
    try {
      const result = await callSingleProvider(provider, messages, apiKey);
      if (result.ok && result.text) {
        if (provider !== "anthropic") {
          // プライマリ以外を使った = circuit open
          await openCircuitBreaker(admin, "anthropic", "429 detected, fallback to " + provider);
        }
        return { text: result.text, provider };
      }
      if (result.status === 429 || result.status === 529) {
        await openCircuitBreaker(admin, provider, `HTTP ${result.status}`);
      }
    } catch { continue; }
  }
  return { text: "AI機能は一時的に利用できません。しばらく後にお試しください。", provider: "none" };
}

async function openCircuitBreaker(
  admin: SupabaseClient,
  provider: string,
  reason: string,
) {
  await admin.from("ai_circuit_breaker").upsert({
    provider,
    state: "open",
    opened_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 3_600_000).toISOString(), // 1時間
    reason,
    updated_at: new Date().toISOString(),
  });
}
```

### 2. ai-assistant/index.ts の DEFAULT_BALTHASAR_MODEL フォールバック

```typescript
// 現在: const DEFAULT_BALTHASAR_MODEL = 'claude-sonnet-4-6';
// 変更後: provider fallback chain を内蔵

async function callWithQuotaFallback(
  anthropicKey: string,
  geminiKey: string,
  openaiKey: string,
  messages: ...,
): Promise<string> {
  // 1st: Anthropic
  if (anthropicKey) {
    try {
      const r = await callAnthropic(anthropicKey, messages, 'claude-haiku-4-5-20251001');
      if (r.ok) return r.text;
      if (r.status === 429) { /* fall through */ }
    } catch {}
  }
  // 2nd: Gemini (gemini-2.0-flash-lite = 無料枠あり)
  if (geminiKey) {
    try {
      const r = await callGemini(geminiKey, messages, 'gemini-2.0-flash-lite');
      if (r.ok) return r.text;
    } catch {}
  }
  // 3rd: OpenAI gpt-4.1-nano
  if (openaiKey) {
    try {
      const r = await callOpenAI(openaiKey, messages, 'gpt-4.1-nano');
      if (r.ok) return r.text;
    } catch {}
  }
  return "[AI一時停止中]";
}
```

### 3. quota-monitor.yml に auto-reset circuit breaker 追加

```yaml
# quota-monitor.yml の最後に追加
- name: Reset expired circuit breakers
  env:
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  run: |
    python3 - << 'EOF'
    import os, requests
    from datetime import datetime, timezone

    service_key = os.environ['SUPABASE_SERVICE_ROLE_KEY']
    base_url = 'https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/ai_circuit_breaker'
    headers = {
        'apikey': service_key,
        'Authorization': f'Bearer {service_key}',
        'Content-Type': 'application/json',
    }

    # 期限切れ circuit breaker を closed にリセット
    now = datetime.now(timezone.utc).isoformat()
    resp = requests.patch(
        f'{base_url}?state=eq.open&expires_at=lt.{now}',
        headers=headers,
        json={'state': 'closed', 'expires_at': None},
        timeout=10
    )
    print(f'Reset expired CBs: {resp.status_code}')
    EOF
```

## 関連ファイル

- `docs/multi-ai-fallback.md` — 全体戦略
- `supabase/migrations/20260424210000_create_ai_circuit_breaker.sql` — CB テーブル (適用済み)
- `supabase/functions/ai-hub/index.ts` — 参考実装 (TIER_PROVIDERS, callSingleProvider)
- `.github/workflows/cs-check.yml` — quota guard 実装例

## 受け入れ条件

- [ ] `tools-hub` の wbs.update_progress など Claude 呼び出し箇所がフォールバック済み
- [ ] `ai-assistant` の main chat 機能が Gemini/OpenAI にフォールバック可
- [ ] Anthropic 429 時に `ai_circuit_breaker.state = 'open'` に自動更新
- [ ] `deno lint` 0 エラー / `dart analyze` 0 エラー
