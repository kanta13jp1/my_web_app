---
title: "AI機能を安全に高速開発する7原則 — NotebookLMの実体験から蒸留した設計ガイド"
tags: AI,Flutter,個人開発,buildinpublic,architecture
published: false
---

# AI機能を安全に高速開発する7原則

## なぜ「原則」が必要か

AI開発ツールでスピードが上がると、**目に見えない欠陥**が増える。

実体験で踏んだ地雷:
- APIキーを上書きしてしまった (Auth失敗)
- ハルシネーションがループした (Quality gate不在)
- バッチ処理がコスト上限を超えた (Circuit breaker不在)
- エラーログが追えなくなった (trace_id不在)

NotebookLM で「AI エージェントで 1 日 23 ページ構築した開発者」の実体験を調査し、
7つの原則に蒸留した。

## AI開発 7原則

### 原則 1: Auth Layer — APIキーの source of truth を単一化

```typescript
// ❌ 危険: 各EFが独自にキーを管理
const GROQ_KEY = process.env.GROQ_KEY ?? "sk-hardcoded-fallback";

// ✅ 安全: Supabase Secrets から一元取得
const GROQ_KEY = Deno.env.get("GROQ_API_KEY");
if (!GROQ_KEY) throw new Error("GROQ_API_KEY not set");
```

古い値の上書き防止: `Deno.env.get()` は常に最新のSecret値を返す。

### 原則 2: Deny-by-default Security

MVP 段階から認証・rate limit・入力検証を入れる。後から追加するより初期に入れる方が簡単。

```typescript
// auth check (RLS より前に実施)
const { data: { user } } = await supabase.auth.getUser(jwt);
if (!user) return new Response('Unauthorized', { status: 401 });

// rate limit (1ユーザー 60リクエスト/分)
const key = `ratelimit:${user.id}`;
const count = await redis.incr(key);
if (count === 1) await redis.expire(key, 60);
if (count > 60) return new Response('Rate limited', { status: 429 });
```

### 原則 3: Trace-based Observability

```typescript
const traceId = crypto.randomUUID();
const start = Date.now();

console.log(JSON.stringify({ traceId, action, userId: user.id, status: "start" }));

// ... 処理 ...

const elapsed = Date.now() - start;
console.log(JSON.stringify({ traceId, elapsed, status: "done" }));

// 5秒超で警告
if (elapsed > 5000) {
  console.warn(JSON.stringify({ traceId, elapsed, status: "slow" }));
}
```

### 原則 4: Cost Circuit Breaker (4段階)

| 段階 | 上限 | 対応 |
|------|------|------|
| Request | 500 tokens | 入力スライス |
| Agent | 10リクエスト/session | 上限でエラー返却 |
| Business | $5/day | SNS通知 |
| Platform | $50/month | API停止 |

```typescript
// Supabase DBでコスト集計
const { data } = await supabase.rpc('get_daily_cost', { user_id: user.id });
if (data.total_usd > 5.0) {
  return new Response(JSON.stringify({ error: 'daily_limit_exceeded' }), { status: 429 });
}
```

### 原則 5: Team Memory + Effectiveness Score

成功/失敗パターンを蓄積し、低スコアのプロンプトを自動的に避ける。

```typescript
// 成功パターンを記録
await supabase.from('ai_team_memory').upsert({
  action,
  prompt_hash: hashPrompt(systemPrompt),
  success: true,
  response_quality: 0.9,
});
```

### 原則 6: Checkpoint + Retry

中間状態を保存し、失敗時に再試行できるようにする。

```typescript
// 長い処理はチェックポイント保存
await supabase.from('ai_checkpoints').upsert({
  job_id: jobId,
  step: 'summarize',
  result: summaryResult,
});
```

### 原則 7: Quality Gate (Sentinel + Warden)

出力前に自動チェック:
- **Sentinel**: 事実確認 (ハルシネーション検出)
- **Warden**: 品質確認 (出力が要件を満たすか)

```typescript
function sentinelCheck(output: string, input: string): boolean {
  // 入力にない固有名詞が出力に現れたら警告
  const inputEntities = extractEntities(input);
  const outputEntities = extractEntities(output);
  const hallucinations = outputEntities.filter(e => !inputEntities.includes(e));
  return hallucinations.length === 0;
}
```

## 採点表 (既存機能の評価)

| 機能 | スコア | 要改善箇所 |
|------|--------|-----------|
| ai-hub (タグ提案) | 5/7 | Memory + Quality gate |
| blog-publish | 2/7 | ほぼ全項目 |
| competitor-monitoring | 3/7 | Circuit breaker + retry |

**6+/7 でないと本番投入しない** — これが AI 機能の品質ゲートとして機能している。

## まとめ

速く作れるからこそ、安全の仕組みを先に入れる。
7原則は「後から追加コスト」を最小化するための投資。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#AI #Flutter #buildinpublic #architecture #個人開発
