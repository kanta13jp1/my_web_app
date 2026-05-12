# Cross-Instance PR: ai-hub EF 自動 Quota Routing [Done]

**From**: PS#1  
**To**: VSCode版  
**Priority**: P1 (🟠)  
**Created**: 2026-04-24

---

## 背景

Claude quota枯渇時、`ai-hub` EF がユーザー向けにエラーを返し続ける。
現状: UI上でプロバイダーを手動切替する必要がある。
目標: quota枯渇を検知したら自動で次プロバイダーにフォールバックする。

---

## 実装内容

`supabase/functions/ai-hub/index.ts` に以下を追加:

### 1. quota エラー判定ヘルパー

```typescript
function isQuotaError(status: number, body: string): boolean {
  if (status === 429 || status === 529) return true;
  const lower = body.toLowerCase();
  return lower.includes("rate limit") || lower.includes("quota") || lower.includes("overloaded");
}
```

### 2. 既存の provider call をラップするフォールバックチェーン

現在の `callProvider()` 関数の呼び出し箇所を以下に変更:

```typescript
// Before (現状):
const result = await callProvider(providerId, messages, model);

// After (fallback chain):
const FALLBACK_CHAIN: ProviderKey[] = ["anthropic", "google", "openai"];
let lastError: Error | null = null;

for (const pid of [providerId, ...FALLBACK_CHAIN.filter(p => p !== providerId)]) {
  try {
    const r = await callProvider(pid, messages, undefined); // use default model
    if (pid !== providerId) {
      console.warn(`[ai-hub] fell back from ${providerId} → ${pid}`);
    }
    return r;
  } catch (e) {
    const msg = String(e);
    if (isQuotaError(500, msg) || msg.includes("429") || msg.includes("529")) {
      lastError = e as Error;
      continue; // try next provider
    }
    throw e; // non-quota error → propagate immediately
  }
}
throw lastError ?? new Error("All providers exhausted");
```

### 3. callProvider での HTTP status チェック改善

現在の `catch` ブロックで HTTP status を読めるよう修正:

```typescript
// 既存の callProvider 内:
if (!resp.ok) {
  const body = await resp.text();
  if (isQuotaError(resp.status, body)) {
    throw new Error(`QUOTA:${resp.status}:${body.slice(0, 100)}`);
  }
  throw new Error(`Provider ${providerId} returned ${resp.status}: ${body.slice(0, 200)}`);
}
```

---

## 影響範囲

- `supabase/functions/ai-hub/index.ts` のみ (1ファイル)
- EF deploy 必要
- Dart コード変更不要

---

## テスト確認

1. `ANTHROPIC_API_KEY` を無効化 → `google` provider で自動フォールバック確認
2. `ANTHROPIC_API_KEY` + `GOOGLE_AI_API_KEY` 両方無効化 → `openai` fallback確認
3. 全無効化 → エラーメッセージが "All providers exhausted" であること

---

## 参照ドキュメント

- `docs/DEV_PROCESS_MULTI_AI.md` Section 4
- `docs/MULTI_AI_RESILIENCE.md`

## ✅ 完了 (VSCode版 S15 2026-04-29)
- commit: 10b5dd71b
- callSingleProvider isRetriable=true 時 anthropic→google→openai フォールバックチェーン
