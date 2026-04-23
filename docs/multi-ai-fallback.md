# Multi-AI フォールバック戦略 — 自分株式会社

> 作成: PS版#5 S33 / 2026-04-24
> 背景: Claude Code のクォータ制限に達すると開発プロセスが全停止する問題を解決する

---

## 1. 問題の全体像

```
Claude quota 枯渇
  ├── GHA Schedule タスク → EF 呼び出し → Anthropic 429 → エラーループ
  ├── Claude Code インスタンス → 操作不能
  └── スケジュールタスク → 毎時リトライ → 無限エラー
```

### 影響を受けるレイヤー

| レイヤー | 影響 | 現状 |
|---------|------|------|
| Claude Code CLI (5インスタンス) | 全操作停止 | フォールバックなし |
| Edge Functions (ai-hub, ai-assistant 等) | AI機能停止 | ai-hub は multi-provider 対応済み |
| GHA Schedule タスク | 毎時エラーループ | cs-check.yml に quota guard 追加済み (2026-04-24) |
| 開発プロセス (コード編集/PR) | 停止 | Codex/Copilot で代替可 |

---

## 2. レイヤー別フォールバック戦略

### 2-A. Claude Code インスタンス停止時 → 開発プロセス継続

```
Claude quota 枯渇
  ├── 緊急修正 (1-20行) → GitHub Copilot Inline Chat / Codex
  ├── コード補完 → GitHub Copilot (常時稼働)
  ├── 500行超リファクタリング → Gemini Code Assist (長コンテキスト)
  ├── ブログ/コンテンツ → NotebookLM (無料、Google インフラ)
  ├── SQL/アルゴリズム → Codex (コード特化)
  └── 設計判断 → 人間 (kanta) が直接決定
```

**実行手順 (Claude 停止時)**:
1. `gh issue list --label bug` でバグ確認
2. Copilot で修正 → `git commit` → `git push`
3. GHA CI が自動 deploy
4. Claude quota が回復次第 (通常 1-8時間) 再開

### 2-B. Edge Function 内 Anthropic 429 → プロバイダーフォールバック

**実装場所**: `supabase/functions/ai-hub/index.ts` (Win版担当)
**実装場所**: `supabase/functions/tools-hub/index.ts` (Win版担当)
**実装場所**: `supabase/functions/ai-assistant/index.ts` (Win版担当)

**フォールバック順序** (ai-hub に既存の TIER_ORDER を活用):

```
anthropic (premium)
  → google/gemini (performance) ← GOOGLE_AI_API_KEY
  → openai (performance)        ← OPENAI_API_KEY
  → groq (free)                 ← GROQ_API_KEY (無料枠あり)
  → deepseek (free)             ← DEEPSEEK_API_KEY (無料枠あり)
  → [graceful degradation: テンプレートベース応答]
```

**実装パターン** (Win版に cross-instance-pr 依頼済み):
```typescript
// tools-hub/index.ts の callAI 関数に追加
async function callAIWithFallback(
  prompt: string,
  preferredProvider = "anthropic"
): Promise<{ text: string; provider: string }> {
  const FALLBACK_CHAIN = ["anthropic", "google", "openai", "groq"];
  for (const provider of FALLBACK_CHAIN) {
    const key = getApiKey(provider);
    if (!key) continue;
    try {
      const result = await callProvider(provider, prompt, key);
      if (result.ok) {
        // 非プライマリプロバイダー使用時は circuit breaker に記録
        if (provider !== "anthropic") {
          await recordCircuitBreaker("anthropic", "open", "60 minutes");
        }
        return { text: result.text, provider };
      }
      if (result.status === 429 || result.status === 529) {
        await recordCircuitBreaker(provider, "open", "60 minutes");
        continue; // 次のプロバイダーへ
      }
    } catch { continue; }
  }
  return { text: "[AI一時停止中。しばらく後にお試しください。]", provider: "none" };
}
```

### 2-C. GHA Schedule タスク → Circuit Breaker + Graceful Skip

**実装済み (2026-04-24 / PS#5 S33)**:
- `ai_circuit_breaker` テーブル: Supabase に provider ごとの open/closed 状態を保存
- `cs-check.yml`: Quota Guard ステップ追加 — anthropic が open なら AI 返信スキップ

**未実装 (cross-instance-pr で依頼)**:
- `blog-draft.yml` / `ai-university-update.yml` への quota guard 追加
- `daily-report.yml` への quota guard 追加

**EF 側の circuit breaker 書き込み** (Win版担当):
```typescript
// 429 検出時に Supabase に記録
await supabase.from("ai_circuit_breaker").upsert({
  provider: "anthropic",
  state: "open",
  opened_at: new Date().toISOString(),
  expires_at: new Date(Date.now() + 3600_000).toISOString(), // 1時間
  reason: `HTTP 429 from Anthropic at ${new Date().toISOString()}`
});
```

---

## 3. 開発プロセス — Claude 停止時の代替フロー

### 通常時 (Claude 稼働)

```
Issue 発生 → PS#5 (Claude) → コード修正 → push → CI → deploy
```

### Claude 停止時 (Codex/Copilot フォールバック)

```
Issue 発生
  ↓
[人間] gh issue view <N> で確認
  ↓
[Copilot] IDE の Copilot Chat: "Fix issue #N: <title>"
  ↓
[Copilot] インライン提案を適用
  ↓
[人間] git commit -m "fix: #N" && git push
  ↓
[GHA] CI / deploy 自動実行
```

### Claude 停止時 (Codex API フォールバック)

```bash
# 緊急時: Codex で直接コード生成
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{"model":"gpt-4.1","messages":[{"role":"user","content":"Fix: <issue description>. File: <path>"}]}'
```

---

## 4. スケジュールタスク優先度マトリクス

| タスク | 頻度 | Claude依存度 | 停止時の影響 | フォールバック |
|--------|------|-------------|-------------|----------------|
| `cs-check.yml` | 毎時 | 中 (AI返信) | 低 (チケット溜まる) | テンプレ返信 or スキップ |
| `infra-health-check.yml` | 毎時 | なし | 高 (異常検知できない) | そのまま継続 |
| `daily-report.yml` | 毎日 | 高 | 低 (レポートなし) | データ集計のみ記録 |
| `ai-university-update.yml` | 毎日 | 高 | 低 (コンテンツ古くなる) | スキップ (cron pause) |
| `blog-draft.yml` | 週次 | 高 | 低 (ブログ遅延) | スキップ |
| `github-issue-fix.yml` | 毎日 | なし (PR作成のみ) | 低 | そのまま継続 |
| `quota-monitor.yml` | 毎日 | なし | 高 (quota把握できない) | そのまま継続 |

---

## 5. Circuit Breaker テーブル仕様

```sql
-- supabase/migrations/20260424210000_create_ai_circuit_breaker.sql
CREATE TABLE public.ai_circuit_breaker (
  provider    text PRIMARY KEY,             -- 'anthropic', 'openai', 'gemini'
  state       text DEFAULT 'closed',        -- 'open' | 'closed'
  opened_at   timestamptz,
  expires_at  timestamptz,                  -- NULL = 手動でのみ解除
  reason      text,
  updated_at  timestamptz DEFAULT now()
);
```

**状態遷移**:
- `closed` → `open`: EF が 429/529 を受信したとき (expires_at = +1時間)
- `open` → `closed`: expires_at 経過後 (GHA が自動確認) or 手動 UPDATE

**確認方法**:
```bash
# 現在の状態確認
curl "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/ai_circuit_breaker" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "apikey: $SERVICE_ROLE_KEY"

# 手動で closed に戻す (Claude 復旧後)
curl -X PATCH "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/ai_circuit_breaker?provider=eq.anthropic" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"state":"closed","expires_at":null}'
```

---

## 6. Slack / Notion 統合 (将来)

Claude 停止時に Slack に通知して人間が介入できる仕組み:

```yaml
# GHA: quota 枯渇検知 → Slack 通知
- name: Notify Slack on quota exceeded
  if: steps.quota_check.outputs.anthropic_available == 'false'
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    curl -X POST "$SLACK_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d '{"text":"⚠️ Anthropic quota exceeded. Schedule tasks paused. Manual intervention or wait 1h."}'
```

Notion 連携 (WBS / タスク管理):
- Claude 停止時は Notion API で直接タスク更新
- `NOTION_API_KEY` を secrets に追加すれば GHA から操作可能

---

## 7. 実装ロードマップ

### Phase 1 (完了 / PS#5 S33)
- [x] `ai_circuit_breaker` テーブル migration
- [x] `cs-check.yml` quota guard
- [x] このドキュメント

### Phase 2 (cross-instance-pr / Win版担当)
- [ ] `tools-hub/index.ts` に `callAIWithFallback` 実装
- [ ] `ai-assistant/index.ts` に provider fallback 追加
- [ ] EF が 429 受信時に `ai_circuit_breaker` を `open` に設定

### Phase 3 (cross-instance-pr / VSCode版担当)
- [ ] `blog-draft.yml` quota guard
- [ ] `ai-university-update.yml` quota guard (cron pause 実装)
- [ ] `daily-report.yml` quota guard + Gemini fallback
- [ ] Slack 通知 webhook

### Phase 4 (Win版 / 将来)
- [ ] Notion API 連携 (WBS 自動更新 when Claude down)
- [ ] NotebookLM を GHA から呼べるよう Cron タスク化
- [ ] quota-monitor.yml に auto-reset circuit breaker 追加
