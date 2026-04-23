---
date: 2026-04-24
from: VSCode版 (Multi-AI resilience 設計 / S2)
to: Win版 (Supabase EF + Migration)
status: pending
priority: HIGH
deadline: 2026-05-07
related: 20260424_multi_ai_fallback_ps1.md (GHA 側フォールバック)
---

# Schedule-hub EF Claude クォータ枯渇時 Gemini フォールバック実装

## 背景

`schedule-hub` / `ai-hub` Edge Function が直接 Anthropic API を呼ぶ設計のため、
Claude クォータ枯渇時にスケジュールタスクが全て失敗し続ける。
Gemini Flash 2.0 をフォールバックとして組み込み、クォータ非依存な設計に移行する。

## 実装内容

### 1. `ai_quota_status` テーブル Migration

**ファイル名**: `supabase/migrations/20260424210000_create_ai_circuit_breaker.sql`

```sql
-- AI クォータ枯渇検知 + circuit breaker テーブル
CREATE TABLE IF NOT EXISTS ai_quota_status (
  provider        TEXT PRIMARY KEY,          -- 'claude' | 'gemini' | 'openai'
  status          TEXT NOT NULL DEFAULT 'ok', -- 'ok' | 'warning' | 'exhausted'
  exhausted_at    TIMESTAMPTZ,
  recovery_at     TIMESTAMPTZ,               -- 推定回復時刻 (任意)
  error_message   TEXT,
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- 初期データ (全プロバイダー ok 状態)
INSERT INTO ai_quota_status (provider, status)
VALUES ('claude', 'ok'), ('gemini', 'ok'), ('openai', 'ok')
ON CONFLICT DO NOTHING;

-- RLS: service role のみ書込み可
ALTER TABLE ai_quota_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_write" ON ai_quota_status
  FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON ai_quota_status
  FOR SELECT TO anon USING (true);

COMMENT ON TABLE ai_quota_status IS 'AI provider quota/health state for circuit breaker pattern';
```

### 2. `callAiWithFallback` ユーティリティ関数

**追加先**: `supabase/functions/schedule-hub/index.ts` (既存の Claude 呼び出し部分を置き換え)

```typescript
// ============================================================
// AI Circuit Breaker — Multi-provider fallback
// ============================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';

async function logQuotaExhaustion(provider: string, error: unknown) {
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/ai_quota_status`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: JSON.stringify({
        provider,
        status: 'exhausted',
        exhausted_at: new Date().toISOString(),
        error_message: String(error).slice(0, 500),
        updated_at: new Date().toISOString(),
      }),
    });
  } catch (e) {
    console.error('[circuit-breaker] Failed to log quota exhaustion:', e);
  }
}

function isQuotaError(e: unknown): boolean {
  const msg = String(e).toLowerCase();
  return msg.includes('529') ||       // Anthropic overloaded
    msg.includes('rate_limit') ||
    msg.includes('quota') ||
    msg.includes('overloaded') ||
    msg.includes('too many requests');
}

async function callGemini(prompt: string, maxTokens = 1024): Promise<string> {
  if (!GEMINI_API_KEY) throw new Error('GEMINI_API_KEY not set');

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: maxTokens },
      }),
    },
  );

  if (!res.ok) throw new Error(`Gemini API error: ${res.status}`);
  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
}

async function callClaude(prompt: string, maxTokens = 1024): Promise<string> {
  const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!;
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5',
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error: ${res.status} — ${errText}`);
  }
  const data = await res.json();
  return data.content?.[0]?.text ?? '';
}

/**
 * Claude → Gemini フォールバック付き AI 呼び出し
 * クォータ枯渇 (529 / rate_limit) の場合のみ Gemini に切り替える。
 */
export async function callAiWithFallback(
  prompt: string,
  options?: { primary?: 'claude' | 'gemini'; maxTokens?: number },
): Promise<{ text: string; provider: 'claude' | 'gemini' }> {
  const primary = options?.primary ?? 'claude';
  const maxTokens = options?.maxTokens ?? 1024;

  if (primary === 'claude') {
    try {
      const text = await callClaude(prompt, maxTokens);
      return { text, provider: 'claude' };
    } catch (e) {
      if (isQuotaError(e)) {
        console.warn('[circuit-breaker] Claude quota exhausted → falling back to Gemini');
        await logQuotaExhaustion('claude', e);
        const text = await callGemini(prompt, maxTokens);
        return { text, provider: 'gemini' };
      }
      throw e;
    }
  } else {
    const text = await callGemini(prompt, maxTokens);
    return { text, provider: 'gemini' };
  }
}
```

### 3. schedule-hub 既存 Claude 呼び出しの置き換え

`callAiWithFallback` を使うように既存の直接 API 呼び出しを置き換える。

**例 (cs-check action)**:

```typescript
// Before
const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
  // ... Claude 直呼び ...
});

// After
const { text: analysisText, provider } = await callAiWithFallback(prompt, {
  primary: 'claude',
  maxTokens: 2048,
});
console.log(`[cs-check] Analyzed by: ${provider}`);
```

### 4. `wbs.quota_status` action を tools-hub に追加 (オプション)

WBS ダッシュボードでクォータ状態を可視化したい場合:

```typescript
// tools-hub/index.ts に追加
case 'wbs.quota_status': {
  const { data } = await supabase
    .from('ai_quota_status')
    .select('*')
    .order('provider');
  return new Response(JSON.stringify({ quota: data }), { headers });
}
```

### 5. GitHub Secrets 追加 ✅ 設定済み

`GEMINI_API_KEY` は GitHub Secrets に設定済み (2026-04-24 確認)。
Supabase Edge Function secrets への追加のみ残り:

## 前提条件

- Win版ワークフロー: `my_web_app_win` worktree で作業
- `GEMINI_API_KEY` を Supabase Edge Function secrets にも追加:

  ```bash
  supabase secrets set GEMINI_API_KEY=<キー>
  ```

- migration 適用後に `ai_quota_status` テーブル存在確認

## 実装ステップ

- [ ] `20260424210000_create_ai_circuit_breaker.sql` migration 作成・適用
- [ ] `schedule-hub/index.ts` に `callAiWithFallback` 追加
- [ ] cs-check / competitor-monitoring アクションを `callAiWithFallback` に移行
- [ ] Supabase secrets に `GEMINI_API_KEY` 追加
- [ ] smoke test: `curl -X POST .../schedule-hub -d '{"action":"cs.check"}'` で動作確認
- [ ] quota 強制テスト: 無効な API キーで Claude を失敗させ Gemini fallback 発火確認

## Philosophy Alignment

- 原則1 (CEO感): システム停止を防ぐ = CEO の判断力を維持する基盤
- 原則5 (商品=ユーザー価値): CS・コンテンツ配信が止まらない = サービス継続性
- 原則2 (ミッション駆動): 技術的障害がミッション実行を阻まない設計
