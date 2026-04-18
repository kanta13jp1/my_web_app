---
title: "AIエージェントを「安全に」使うための7原則 — 自分株式会社の実装事例"
tags: Flutter,Supabase,AI,個人開発,buildinpublic
published: true
---

# AIエージェントを「安全に」使うための7原則

## はじめに

Claude Code・Gemini Code Assist・GitHub Copilotを並行して使う個人開発をしていると、ある日気づきます。

「AIが便利すぎて、気づかないうちに**見えない穴**が増えていた」

APIキーの上書き、ハルシネーションループ、自動投稿スパム化…
これらは全て「AI使用時に埋め込まれた隠れた欠陥」です。

この記事では、私が[自分株式会社](https://my-web-app-b67f4.web.app/)（Flutter Web + Supabase）の開発で実践している **AI開発7原則** を紹介します。

## AI開発7原則とは

NotebookLMで調査した「AIエージェント使用時の実体験」から蒸留した7つのガード。

### 原則1: Auth Layer（認証の単一化）

```typescript
// ❌ Bad: 複数箇所でAPIキー取得
const key1 = Deno.env.get("OPENAI_API_KEY") || "fallback";
const key2 = process.env.ANTHROPIC_KEY;

// ✅ Good: 1箇所のsource of truth
const getApiKey = (provider: string) => {
  const key = Deno.env.get(`${provider.toUpperCase()}_API_KEY`);
  if (!key) throw new Error(`${provider} API key not configured`);
  return key;
};
```

**なぜ重要か**: AIが「便利に」古い値を上書きすることがある。source of truthを1箇所に集めれば上書きを即検出できる。

### 原則2: Deny-by-default Security

```typescript
// MVP段階から認証・rate limit・入力検証を入れる
const corsHeaders = { "Access-Control-Allow-Origin": ALLOWED_ORIGIN };

// ユーザーIDなしのリクエストは全拒否
const { data: { user } } = await supabase.auth.getUser();
if (!user) return new Response("Unauthorized", { status: 401 });
```

**なぜ重要か**: 「後で入れよう」は永遠に来ない。AIが生成したコードはデフォルトでオープンになりがち。

### 原則3: Trace-based Observability

```typescript
const traceId = crypto.randomUUID();
const startTime = Date.now();

// 処理
const result = await callAI(prompt);

const elapsed = Date.now() - startTime;
if (elapsed > 5000) {
  console.warn(`[${traceId}] Slow AI call: ${elapsed}ms`);
  // アラート送信
}
```

**なぜ重要か**: 5秒超のAI呼び出しはコストと品質の問題を示す。`trace_id`がないと原因追跡が不可能になる。

### 原則4: Cost Circuit Breaker（4段階）

```typescript
const LIMITS = {
  request: 0.10,   // 1リクエスト上限 $0.10
  agent: 1.00,     // 1エージェント実行上限 $1.00
  business: 10.00, // 1日上限 $10.00
  platform: 50.00, // 月上限 $50.00
};

if (estimatedCost > LIMITS.request) {
  throw new Error("Cost limit exceeded");
}
```

**なぜ重要か**: AIエージェントが無限ループした場合、circuit breakerがなければ請求額が爆発する。

### 原則5: Team Memory + Effectiveness Score

```sql
-- AI呼び出しの成功/失敗をスコアで管理
CREATE TABLE ai_call_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text,
  prompt_hash text,
  success boolean,
  score numeric, -- 0.0-1.0
  created_at timestamptz DEFAULT now()
);
```

**なぜ重要か**: 低スコアのプロンプトパターンを蓄積して自動的に減衰させることで、同じ失敗を繰り返さない。

### 原則6: Checkpoint + Retry + Dead Letter Queue

```typescript
// 中間状態を保存してから次ステップへ
await supabase.from("job_checkpoints").upsert({
  job_id: jobId,
  step: "generate",
  data: generatedContent,
});

// 失敗時はDLQへ
if (retryCount >= 3) {
  await supabase.from("dead_letter_queue").insert({
    job_id: jobId,
    error: error.message,
  });
}
```

**なぜ重要か**: 長時間処理がクラッシュした場合、最初からやり直しにならないようにする。

### 原則7: Quality Gate（Sentinel + Warden）

```typescript
// Sentinel: 事実確認（ハルシネーション検出）
const sentinelCheck = async (content: string) => {
  // 固有名詞・数値・URLを抽出して検証
  const claims = extractClaims(content);
  return claims.every(claim => verifyFact(claim));
};

// Warden: 品質確認
const wardenCheck = async (content: string) => {
  const score = await evaluateQuality(content);
  return score > 0.7; // 70%以上で合格
};

if (!await sentinelCheck(output) || !await wardenCheck(output)) {
  throw new Error("Quality gate failed");
}
```

**なぜ重要か**: AI出力を自動公開する前に事実と品質の両方を確認する二重チェック。

## チェックリストの使い方

新しいAI機能を作るとき、7項目にチェックを入れる:

| 原則 | チェック |
|------|---------|
| Auth Layer | ✅/❌ |
| Deny-by-default | ✅/❌ |
| Observability | ✅/❌ |
| Circuit Breaker | ✅/❌ |
| Team Memory | ✅/❌ |
| Checkpoint/Retry | ✅/❌ |
| Quality Gate | ✅/❌ |

- **6+** ✅ → 実装OK
- **4-5** ✅ → 設計再考
- **3以下** → 見送り

## 自分株式会社での既存機能スコア

| 機能 | スコア | 課題 |
|------|--------|------|
| ai-assistant EF | 5/7 | Memory + Quality Gate 未実装 |
| competitor-monitoring | 3/7 | Circuit Breaker + Retry + Memory 不足 |
| blog-publish | 2/7 | Quality Gate + Circuit Breaker 必須 |

低スコアの機能は段階的に改善予定。

## まとめ

AIエージェントは「便利すぎる」がゆえに、見えない穴を埋め込みやすい。
7原則を checklist として使うことで、MVP段階から安全なAI機能を作れる。

完璧な実装を目指すより、**まず checklist を通すことを習慣化** することが重要です。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #AI開発 #buildinpublic #個人開発
