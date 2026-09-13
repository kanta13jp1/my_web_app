# 開発プロセス Multi-AI Routing Matrix — 自分株式会社

> 作成: 2026-04-24 PS#1 S26 / Win版#132 part 3 改訂
>
> **目的**: Claude Code quota枯渇・障害時に開発を停止させない。
> AI ツールを役割分担し、月 $20 プランで $200 相当の開発速度を維持する。

---

## #2535 Guarded Subagent Routing Update (2026-05-17)

Live top-level owners: Claude Code #1 and Codex #1 only. Do not start old Codex
#2/#3 or PowerShell lane instances for normal WBS execution. Guarded child
subagents are allowed under Claude Code #1 or Codex #1 when they follow
`docs/SUBAGENT_ORCHESTRATION_POLICY.md`: bounded scope, explicit return
contract, deterministic validation, resource hygiene, and no independent WBS
ownership. Historical tables below are retained as migration context, but this
section is the current override when a row mentions dormant lanes.

| Surface | Current owner | Notes |
| --- | --- | --- |
| AI tool release adoption and risk decision | Claude Code #1 | Verify official release notes before adopting Claude Code, Codex CLI, Copilot, Gemini, Cursor, or Devin signals. |
| Scoped implementation, CI, PR, merge follow-up, and cleanup | Codex #1 | Codex #1 absorbs the old Codex #2 implementation lane for CI, sync, GitHub Actions, Edge Functions, and docs/script PRs. |
| Guarded subagent orchestration | Lead instance that spawned the worker | Use for isolated research, rubric critique, large-output inspection, memory review, or disjoint scoped implementation. Record subagent evidence in PR/Issue/wrap-up. |
| GitHub Copilot Custom Agents | Advisory only | Use `.github/agents/README.md` as the design registry. Copilot agents must not merge, deploy, or run side-effecting automation. |
| Gemini Code Assist / Cursor / Devin signals | Candidate fallback or review input | Use only after local availability and official source verification; never as an extra autonomous project instance. |

For monthly AI-tool updates, start from
`docs/ai-tool-changelog/2026-05.md` and
`docs/cross-instance-prs/drafts/ai-tool-update/2026-05_ai_tool_update_cross_instance_drafts.md`.
Claude Code #1 decides adopt/defer/ignore; Codex #1 implements the approved
scoped slice and records memory/disk hygiene before wrap-up.

## 1. 強制 Task Routing Matrix

**このルールに従って AI を選択する。Claude Code は「設計判断・大きめ実装・既存設計に沿った機能追加・並列ワーカー・統合・memory管理」を担う。**

12 インスタンス並行開発では、作業そのものと同時に運用改善も見る。正本は GitHub Issues / PR、WBS / Notion、NotebookLM、Slack、各 worktree / branch に分散しているため、作業開始時に状態の食い違いと担当領域の衝突を確認する。

12 インスタンス並行開発では、作業そのものと同時に運用改善も見る。正本は GitHub Issues / PR、WBS / Notion、NotebookLM、Slack、各 worktree / branch に分散しているため、作業開始時に状態の食い違いと担当領域の衝突を確認する。

| タスク種別 | **Primary** | **Secondary** | **Tertiary** | Claude Code 役割 |
| --- | --- | --- | --- | --- |
| 行レベル補完 (< 10行) | GitHub Copilot | — | — | **不使用** |
| 5分以内の修正 | Copilot Inline Chat | — | — | **不使用** |
| 500行超リファクタリング | Gemini Code Assist | Copilot | Claude Code | 事前レビューのみ |
| 横断調査 / 修正PR / レビュー補助 | **Codex #1** | Claude Code #1 | Copilot advisory | 仕様確認のみ |
| CI / 同期 / 運用まわり | **Codex #1** | Claude Code #1 | gh CLI / Python | 完了判定のみ |
| SQL / アルゴリズム最適化 | **Codex #1** | Copilot | Claude Code #1 | 仕様確認のみ |
| Migration (DDL + seed SQL) | **Codex#1** (template ベース) | Copilot | Claude Code | 命名則チェック |
| AI大学 provider 追加 (seed SQL) | **Codex#1** (既存 SQL コピー改変) | — | Claude Code | routing 判断のみ |
| ブログ・競合リサーチ | Claude Code WEB版 (WebSearch) | NotebookLM | Gemini Search | — |
| NotebookLM Deep Research | Win版 CLI | Gemini Research | — | 統合・要約のみ |
| UI/デザイン (新コンポーネント) | Claude Code VSCode版 + design-skills | Figma MCP | Copilot | 設計レビュー |
| ブラウザ操作 / 外部SaaS確認 / 長手順実行 | Manus AI | Claude Code | — | 結果確認のみ |
| アーキテクチャ判断 | **Claude Code** | NotebookLM + Copilot Chat | — | **専任** |
| Dart バグ修正 (< 50行) | Copilot Inline Chat | Claude Code PS#5 | — | 必要時のみ |
| EF バグ修正 (Deno) | **Codex #1** / Copilot | Claude Code #1 | — | deny-by-default確認 |
| GHA Workflow 作成・修正 | **Codex #1** / Claude Code #1 | Copilot | gh CLI スクリプト | WF health 専任 |
| PR review (自動) | claude-agent-review.yml | GitHub Copilot PR review | — | — |
| quota監視・アラート | quota-monitor.yml (Python) | — | — | **不使用** |

---

## 2. Claude Quota 枯渇時 緊急プロトコル

### 検知方法

```bash
# quota-monitor.yml が毎日 09:00 JST に自動実行
# 手動確認:
curl -s -o /dev/null -w "%{http_code}" \
  -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}'
# → 429 or 529 = quota枯渇
```

### 即時対応 (5分以内)

1. `CLAUDE.md` 冒頭の注意書きを更新 (枯渇日時記録)
2. `docs/WBS.md` の担当インスタンスを Codex / Copilot に振り替え
3. `docs/cross-instance-prs/YYYYMMDD_quota_hit.md` を作成してall instancesに通知

### インスタンス別フォールバック

| インスタンス | 通常 | Claudeクォータ枯渇時 |
| --- | --- | --- |
| **Win版** | migration / EF / AI大学追加 | Codex で migration生成 + gh CLI でEF deploy |
| **VSCode版** | UI / design / リファクタ | GitHub Copilot + Figma MCP |
| **PS#1** | WF health / CI修復 | gh CLI + Python スクリプト (Claude不要) |
| **PS#2** | blog dispatch | blog-draft.yml **Gemini自動fallback** ✅ |
| **PS#3** | AI大学コンテンツ | ai-university-update.yml (Claude不要) ✅ |
| **PS#4** | 競合モニタリング | check-competitor-updates EF (Claude不要) ✅ |
| **PS#5** | on-call バグ修正 | GitHub Copilot + GitHub MCP |
| **PS#6** | horse_racing / バッチ | cron-batch.yml (Claude不要) ✅ |
| **WEB版** | Issue起票 | GitHub MCP のみ (元々Claude不要) ✅ |
| **Codex #1** | 横断調査 / 修正PR / SQL・migrationレビュー補助 / CI / 同期 / 運用 / EF・GHA補助 | Codex Windows app worktree で継続 ✅ |
| **Codex #2** | historical only | 2026-05 two-instance policy: do not start; work is absorbed by Codex #1 |

**✅ = Claude quota枯渇でも自動継続**

---

## 3. GHA スケジュールタスク Quota耐性

### 対応状況

| Workflow | Claude依存 | Fallback実装 | 状態 |
| --- | --- | --- | --- |
| `blog-draft.yml` | Claude Haiku | **Gemini Flash → template** | ✅ 完了 (PS#1 S26) |
| `ai-university-update.yml` | なし (REST直接) | N/A | ✅ 問題なし |
| `quota-monitor.yml` | なし (監視のみ) | N/A | ✅ 問題なし |
| `cs-check.yml` | Claude Schedule | ❌ 未実装 | 要対応 |
| `blog-engagement.yml` | Claude Haiku | **Gemini → template** | ✅ 完了 (Codex#2 2026-04-28) |
| `blog-backfill.yml` | Claude Haiku | ❌ 未実装 | 要対応 |
| `claude-agent-review.yml` | Claude Sonnet | skip-on-quota 推奨 | 要対応 |
| `blog-verify.yml` | Claude Haiku | ❌ 未実装 | 要対応 |
| `cron-batch.yml` | なし | N/A | ✅ 問題なし |
| `daily-report.yml` | なし (GHA生成) | N/A | ✅ 問題なし |

### GHA Quota Guard 再利用テンプレ

```yaml
- name: Check Anthropic quota (skip-on-quota)
  id: quota
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    if [ -z "$ANTHROPIC_API_KEY" ]; then
      echo "provider=gemini" >> $GITHUB_OUTPUT; exit 0
    fi
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "https://api.anthropic.com/v1/messages" \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}')
    if [ "$STATUS" = "429" ] || [ "$STATUS" = "529" ]; then
      echo "⚠️ Claude quota exhausted (HTTP $STATUS)" >&2
      echo "provider=gemini" >> $GITHUB_OUTPUT
    else
      echo "provider=claude" >> $GITHUB_OUTPUT
    fi
```

---

## 4. EF (Edge Function) Model Routing

### 対応状況

| EF | Claude依存 | Fallback | 状態 |
| --- | --- | --- | --- |
| `ai-hub` | Anthropic primary (UI選択) | ⚠️ UI手動切替のみ | 要自動routing |
| `ai-assistant` | Anthropic | なし | VSCode handoff |
| `competitor-feature-sync` | Anthropic | なし | VSCode handoff |
| `tools-hub` / `schedule-hub` 等 | なし | N/A | ✅ 問題なし |

### ai-hub 自動routing改善 (VSCode版 handoff)

`supabase/functions/ai-hub/index.ts` に以下のフォールバックロジックを追加:

```typescript
// Provider priority chain (quota-resilient)
const PROVIDER_CHAIN = ["anthropic", "google", "openai"] as const;

async function callWithFallback(messages: Message[], providers = PROVIDER_CHAIN) {
  for (const provider of providers) {
    try {
      const result = await callProvider(provider, messages);
      return result;
    } catch (e) {
      if (isQuotaError(e)) {
        console.warn(`[ai-hub] ${provider} quota exhausted, trying next`);
        continue;
      }
      throw e; // non-quota errors propagate
    }
  }
  throw new Error("All AI providers exhausted");
}

function isQuotaError(e: unknown): boolean {
  const msg = String(e);
  return msg.includes("429") || msg.includes("529") || msg.includes("quota");
}
```

> ⚠️ この変更は Deno EF 編集のため **VSCode版担当**。
> `docs/cross-instance-prs/20260424_ai_hub_quota_fallback.md` で handoff済。

---

## 5. NotebookLM を開発プロセスに統合

Claude quota枯渇時の重いリサーチは NotebookLM が完全代替:

```bash
# 競合調査 (Claude不要)
notebooklm source add-research "Notion 2026 pricing competitor analysis"
notebooklm ask "主要変更と自分株式会社への影響"

# コード分析 (Claude不要)
notebooklm source add "./lib/pages/landing_page.dart"
notebooklm ask "アーキテクチャ上の問題点"

# 過去意思決定参照 (Claude不要)
notebooklm use jibun-master-brain
notebooklm ask "Edge Function設計方針の経緯"
```

---

## 6. 実装ロードマップ

### 6a. GHA Fallback 広域ロードマップ

| 優先度 | タスク | 担当 | 完了目標 |
| --- | --- | --- | --- |
| 🔴 **P0** | blog-draft.yml Gemini fallback | ✅ PS#1 S26 | 2026-04-24 |
| 🔴 **P0** | `GOOGLE_AI_API_KEY` + `GEMINI_API_KEY` + `SLACK_WEBHOOK_URL` secrets | ✅ **設定済 (2026-04-24)** | — |
| 🟠 **P1** | ai-hub EF 自動quota routing | VSCode版 | 2026-04-26 |
| 🟠 **P1** | blog-engagement.yml Gemini fallback | ✅ Codex#2 | 2026-04-28 |
| 🟠 **P1** | claude-agent-review.yml skip-on-quota | PS#1 | 2026-05-01 |
| 🟡 **P2** | cs-check.yml Gemini fallback | PS#1 | 2026-05-05 |
| 🟢 **P3** | Notion WBS mirror | Win版 | 2026-05-15 |

### 6b. Circuit Breaker Backlog (Supabase ai_quota_status)

| # | タスク | 担当 | 期限 | 優先度 | 依存 |
|---|--------|------|------|-------|------|
| 1 | `ai_quota_status` テーブル migration 作成 | **Win版** | 2026-04-25 | 🔴 緊急 | — |
| 2 | `cs-check.yml` quota pre-check + lite mode | **PS#1** | 2026-04-26 | 🔴 | #1 |
| 3 | `daily-report.yml` quota pre-check + lite mode | **PS#1** | 2026-04-26 | 🔴 | #1 |
| 4 | `quota-monitor.yml` 自動フラグ設定ロジック | **PS#1** | 2026-04-28 | 🔴 | #1 |
| 5 | `GEMINI_API_KEY` / `SLACK_WEBHOOK_URL` secrets | ~~Win版~~ | ~~2026-04-28~~ | ✅ **設定済 (2026-04-24)** | — |
| 6 | `pr-auto-review` / `github-issue-fix` quota skip | **PS#1** | 2026-04-30 | 🟡 | #1 |
| 7 | `cs_queue` テーブル + 復旧後一括処理 | **Win版** | 2026-05-07 | 🟢 | #1 |
| 9 | KPI 計測 (token 削減率 week 比較) | **PS#4** | 2026-05-15 | 🟢 | — |

**cross-instance-pr 発行**: `docs/cross-instance-prs/20260424_quota_circuit_breaker.md`

---

## 7. KPI (効果測定)

| 指標 | 目標 | 現在 |
| --- | --- | --- |
| Claude quota枯渇時の継続可能タスク率 | 70%+ | ~40% |
| GHA schedule Claude依存ワークフロー中 fallback実装済み比率 | 80%+ | 12.5% (1/8) |
| EF Claude依存中 fallback実装済み比率 | 60%+ | 0% |
| 月次 Claude token 消費量削減 | -30% | 未測定 |

---

## 8. Slack 統合 — 非同期通知 + 緊急連絡バックアップ (Win版#132 part 4 追記)

> **発端**: Anthropic outage 時、cross-instance-pr 作成 (Claude 依存) 不能 = 10 インスタンス間の連絡手段自体が Claude 経由に集中。Claude 独立な非同期連絡 channel が必要。

### 8-1. Slack が担う 4 つの役割

| 役割 | 契機 | 実装 |
|------|------|------|
| **A. quota alert** | `ai_circuit_breaker.state` が closed→open | Supabase trigger → `core-hub:slack.notify` → Incoming Webhook |
| **B. WF failure 通知** | deploy-prod / scheduled task fail | 既存 `workflow-failure-handler.yml` 拡張 |
| **C. cross-instance 非同期 handoff** | Claude outage 時の緊急 handoff | 手動 post or GHA `gh issue` 経由で投稿 |
| **D. daily digest** | 毎朝 08:00 JST | Supabase `schedule-daily-digest` EF → Slack |

### 8-2. Slack Channel 構成 (推奨)

| Channel | 目的 | 投稿元 |
|---------|------|--------|
| `#jibun-quota` | Claude / OpenAI / Gemini quota 状態変化のみ | Supabase trigger |
| `#jibun-ci` | GHA workflow 失敗通知 | workflow-failure-handler |
| `#jibun-daily` | 毎朝のメトリクス digest | schedule-daily-digest EF |
| `#jibun-handoff` | インスタンス間の非同期 handoff | 手動 post / GHA |
| `#jibun-alerts` | 本番障害・P0/P1 | health-check EF |

### 8-3. 実装ステップ (ユーザー手動 + Win版 EF 追加)

```bash
# 1. Slack Workspace で Incoming Webhook app 作成
#    https://api.slack.com/messaging/webhooks
#    → Webhook URL 取得 (例: https://hooks.slack.com/services/T.../B.../xxx)

# 2. Supabase Secrets + GitHub Secrets に 3 つ追加
supabase secrets set SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
supabase secrets set SLACK_WEBHOOK_QUOTA="https://hooks.slack.com/services/..."
supabase secrets set SLACK_WEBHOOK_CI="https://hooks.slack.com/services/..."
gh secret set SLACK_WEBHOOK_URL SLACK_WEBHOOK_QUOTA SLACK_WEBHOOK_CI

# 3. core-hub に slack.notify action 追加 (Win版 Backlog)
# 4. ai_circuit_breaker → Slack post trigger 作成 (Win版 Backlog)
```

### 8-4. core-hub:slack.notify action (✅ 実装済 Win版#132 part 36 / 2026-04-26)

```typescript
// supabase/functions/core-hub/index.ts
case 'slack.notify': {
  const { channel = 'default', text, blocks } = payload;
  const webhookEnv = {
    'default': 'SLACK_WEBHOOK_URL',
    'quota':   'SLACK_WEBHOOK_QUOTA',
    'ci':      'SLACK_WEBHOOK_CI',
  }[channel] ?? 'SLACK_WEBHOOK_URL';

  const url = Deno.env.get(webhookEnv);
  if (!url) return jsonResponse({ success: false, error: 'webhook not configured' }, 500);

  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(blocks ? { blocks } : { text }),
  });
  return jsonResponse({ success: resp.ok, status: resp.status });
}
```

### 8-5. Supabase trigger: circuit breaker OPEN で Slack 通知 (✅ 実装済 Win版#132 part 36 / 2026-04-26)

実装: `supabase/migrations/20260426253000_ai_circuit_breaker_slack_trigger.sql`

**ユーザー手動 setup (一度のみ)**:

Supabase Studio → SQL Editor で SERVICE_ROLE_KEY を Vault に保存:

```sql
-- Settings → API → service_role secret をコピーして以下に貼付
SELECT vault.create_secret(
  '<paste_service_role_key_here>',
  'service_role_key'
);
```

未保存時の挙動: trigger は NOTICE を出して silent skip (本体 UPDATE は影響なし)。

**動作確認**:

```sql
-- Test: anthropic を closed→open に変更 → Slack #jibun-quota に通知届くはず
UPDATE public.ai_circuit_breaker
SET state = 'open',
    reason = 'manual test',
    expires_at = NOW() + INTERVAL '1 minute'
WHERE provider = 'anthropic';

-- 確認後 closed に戻す
UPDATE public.ai_circuit_breaker
SET state = 'closed', reason = NULL, expires_at = NULL
WHERE provider = 'anthropic';
```

---

### 8-5b. (旧設計参考) — 元の設計 sketch

```sql
CREATE OR REPLACE FUNCTION notify_circuit_breaker_open()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  IF NEW.state = 'open' AND (OLD.state IS NULL OR OLD.state = 'closed') THEN
    PERFORM net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/core-hub',
      headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')),
      body := jsonb_build_object(
        'action', 'slack.notify',
        'channel', 'quota',
        'text', format('🚨 %s quota OPEN at %s (expires: %s / reason: %s)',
          NEW.provider, NEW.opened_at, NEW.expires_at, NEW.reason)
      )
    );
  END IF;
  RETURN NEW;
END;
$fn$;

CREATE TRIGGER ai_circuit_breaker_notify
  AFTER UPDATE ON public.ai_circuit_breaker
  FOR EACH ROW EXECUTE FUNCTION notify_circuit_breaker_open();
```

### 8-6. Fallback: Slack 自体が停止したら?

- **Slack outage** (発生頻度 <1 回/年): Discord webhook を secondary channel として併設推奨
- **webhook URL 紛失**: `.env.local` + 1Password に複製保存 (Secrets 一元管理 + 二重化)

---

## 9. Notion 統合 — human-readable mirror (Claude 不使用で閲覧可能) (Win版#132 part 4 追記)

> **発端**: Anthropic outage 時、「今日の WBS は?」「前回の memory は?」をユーザーが確認する手段が Claude 経由のみに集中。Claude 不使用でも閲覧可能な mirror が必要。

### 9-1. Notion が担う 3 つの役割

| 役割 | 元データ | 同期方法 |
|------|---------|---------|
| **A. ROADMAP mirror** | `docs/GROWTH_STRATEGY_ROADMAP.md` | GHA cron (1h 毎) → Notion API push |
| **B. WBS mirror** | Supabase `wbs_tasks` テーブル | `schedule-hub:notion.sync_wbs` EF → Notion Database upsert |
| **C. memory/ index mirror** | `memory/MEMORY.md` | GHA cron (毎朝) → Notion page replace |

### 9-2. 既存 Notion AI との棲み分け

- **既存 Notion AI** (5/4 課金開始): Notion 社側の AI (草案作成・文書作成)
- **新 Notion mirror**: 自分株式会社側から Notion に**書き込む** (Notion = 単なる DB)

→ Notion AI 課金有無に関わらず使える (base plan で十分)。

### 9-3. Notion Database 構成

```
Workspace: 自分株式会社 mirror
  ├── 📄 Page: ROADMAP (long-form / replace 全文)
  ├── 🗂 Database: WBS Tasks
  │     Properties: id (text) / title (text) / instance (select) /
  │                 status (select) / progress (number) / deadline (date) /
  │                 updated_at (datetime)
  ├── 🗂 Database: Memory Index
  │     Properties: filename / type (feedback_success/correction/project) /
  │                 timestamp / description (rich_text)
  └── 📄 Page: Today's Digest (毎朝 replace)
```

### 9-4. 実装ステップ (ユーザー手動 + Win版 EF 追加)

```bash
# 1. Notion API token 取得 (https://www.notion.so/my-integrations)
#    - Internal Integration 作成 → "Read + Update + Insert content" 権限
#    - Token = secret_xxx

# 2. Workspace に手動で Database/Page 作成
#    - "自分株式会社 mirror" 階層
#    - 3 つの DB/Page を作成 → integration を "Connections" で invite
#    - 各 DB の ID (URL から 32 文字 hash) を控える

# 3. Supabase Secrets + GitHub Secrets に追加
supabase secrets set NOTION_API_TOKEN="secret_xxx"
supabase secrets set NOTION_WBS_DATABASE_ID="xxx..."
supabase secrets set NOTION_WBS_DATA_SOURCE_ID="xxx..." # 複数 data source 時は必須
supabase secrets set NOTION_MEMORY_DATABASE_ID="xxx..."
supabase secrets set NOTION_MEMORY_DATA_SOURCE_ID="xxx..."
supabase secrets set NOTION_ROADMAP_PAGE_ID="xxx..."

# 4. schedule-hub に notion.sync_wbs action 追加 (Win版 Backlog)
# 5. GHA cron 1h 毎に notion.sync_roadmap 呼び出し (Win版 Backlog)
```

### 9-5. schedule-hub:notion.sync_wbs action (実装済み)

```typescript
// 2025-09-03 API の実装は以下を参照する。
// - supabase/functions/schedule-hub/index.ts
// - supabase/functions/_shared/notion_data_source.ts
// Database ID は container の data_sources 解決にだけ使用し、レコードは
// POST /v1/data_sources/{data_source_id}/query で取得する。
// 複数 data source の database は NOTION_*_DATA_SOURCE_ID または
// NOTION_*_DATA_SOURCE_NAME を Secret として明示する。
```

### 9-6. Notion mirror 停止時の fallback

- **Notion outage**: GitHub `docs/` の Markdown 版が primary source として機能
- **token 失効**: 月次動作確認 (PS#1 rule17 skill に組込推奨)

### 9-7. 重要原則: 書き込み側を Notion にしない

❌ Notion → Supabase の逆方向同期は避ける (ユーザーが Notion で WBS 編集 → Supabase と乖離)
✅ **Supabase = source of truth / Notion = read-only mirror** に限定
→ 唯一の例外: quota outage 時の緊急 roadmap 追記 → 復旧後に手動で GitHub に反映

---

## 10. Slack + Notion Backlog (Win版 担当)

| # | タスク | 期限 | 優先度 | 依存 |
|---|--------|------|-------|------|
| S1 | Slack Webhook 3 ch 設定 | 2026-04-28 | 🔴 | ユーザー手動 |
| S2 | `core-hub:slack.notify` action 追加 | 2026-04-30 | ✅ Win版#132 part 36 (2026-04-26) | S1 |
| S3 | ai_circuit_breaker Supabase trigger (Slack post) | 2026-04-30 | ✅ Win版#132 part 36 (2026-04-26) — 🔧 vault 手動 setup 必須 (下記参照) | S2 |
| S4 | Discord webhook secondary channel | 2026-05-15 | 🟢 | S1 |
| N1 | Notion Integration token + DB 3 つ設計 | 2026-05-01 | 🟡 | ユーザー手動 |
| N2 | `schedule-hub:notion.sync_wbs` action | 2026-05-05 | 🟡 | N1 |
| N3 | `schedule-hub:notion.sync_roadmap` action | 2026-05-05 | 🟢 | N1 |
| N4 | `schedule-hub:notion.sync_memory_index` action | 2026-05-07 | 🟢 | N1 |
| N5 | GHA cron 1h 毎 notion sync 起動 | 2026-05-10 | 🟢 | N2-N4 |

**関連ドキュメント**:
- `docs/MULTI_INSTANCE_FLEET.md` — 10 Claude + 2 Codex の canonical roster
- `docs/CODEX_WORKFLOW.md` — Codex#1/#2 の起動・push・handoff 手順
- `docs/AI_FALLBACK_RUNBOOK.md` (PS#6 S26) — 開発ワークフロー別 fallback 手順
- `docs/PROMPT_CACHING_OPUS47_COST_GUIDE.md` (Win版#132 part 177) — Prompt Caching × Opus 4.7 88% コスト削減戦略
- `supabase/migrations/20260424210000_create_ai_circuit_breaker.sql` (PS#1 S26) — quota 状態集約テーブル
| AI | 用途 | セットアップ状態 | アクセス方法 |
|----|------|----------------|------------|
| **GitHub Copilot** | inline補完 / Chat | ✅ VS Code統合済 | Editor内 |
| **OpenAI Codex** | SQL / GHA / EF Deno | ✅ Web + CLIあり | `codex` CLI / Web |
| **Gemini Code Assist** | 長文refactor | ✅ VS Code拡張 | Editor内 |
| **NotebookLM** | リサーチ / URL分析 | ✅ CLI認証済 | `notebooklm` CLI |
| **Gemini API (direct)** | schedule fallback LLM | ✅ **GitHub Secret 設定済** | `GEMINI_API_KEY` |
| **Slack** | quota alert通知 | ✅ **GitHub Secret 設定済** | `SLACK_WEBHOOK_URL` |
| **Notion AI** | 草案作成 (human review後) | ⚠️ 5/4課金開始 | Web |

---

## コスト tier ルーティング — 従量課金時代のモデル使い分け (= Issue #2694 基準 1 正本)

> Win版#132 part 261 (2026-06-10): §1 (instance 振分) / §4 (EF provider routing) を**コスト軸**で補完。
> 主要 AI ツールの従量課金化を前提に、「タスク難易度 → コスト tier」の使い分けを定義する。

### 原則

1. **モデル名を本表に固定しない** — モデルは数か月で世代交代する ([AI-TOOL-VERIFY])。本表は **tier (役割)** で指定し、tier→実モデルの対応は各ツールの設定 (`/model` picker / [`AI_FALLBACK_RUNBOOK.md`](AI_FALLBACK_RUNBOOK.md)) を正とする。
2. **routing の第 1 判断は §1 (誰がやるか) → 第 2 判断が本節 (どの tier でやるか)**。
3. 迷ったら 1 tier 下で試行 → 品質不足なら上げる (逆方向は気付きにくい / コスト超過は静かに進行する)。

### 難易度 → tier 表

| タスク類型 | 例 | tier | 根拠 |
|-----------|----|------|------|
| 定型・機械的 | Flutter 定型 widget / 既存 SQL コピー改変 / format 修正 / 単純リネーム | **低 tier** (各ツールの軽量モデル / inline 補完) | 失敗してもレビューで止まる・再試行が安い |
| 中規模実装 | EF action 追加 / migration 作成 / テスト実装 / バグ fix | **中 tier** (L2 既定 = Codex 標準) | §1 matrix の L2 既定運用そのまま |
| 複雑設計・横断判断 | アーキ設計 / セキュリティ境界 / Supabase 複雑ロジック / 障害調査 / レビュー gate | **高 tier** (L3 = Claude 上位モデル) | 誤判断のコスト >> 推論コスト |
| 大量バッチ・요約 | リサーチ / URL 分析 / 競合調査 | **ゼロトークン経路優先** (NotebookLM / 既存 cron 成果物) | §5 既定 / 推論を買う前に既存知識を引く |

### コスト消費の既存ガードレール (実在 / 基準 2-3 の現状)

- **可視化 (部分既存)**: `quota-monitor.yml` (毎日 09:00 JST / §2) + claude.ai Routine `ci-cd-cost-audit` (毎日 23:00 JST / CI/CD 冗長検出)。**モデル別トークン消費の集計は未実装** → 拡張は L2 (Issue #2694 基準 2 として継続)。
- **暴走停止 (部分既存)**: [AUTO-REPLY] の MAX_REPLIES cap / EF リトライ上限。**包括的なコスト上限アラート + エージェントループ自動停止は未実装** → L2 (同基準 3)。
- 未実装 2 点は「ある」と主張しない — 本節は使い分けガイドライン (基準 1) の正本であり、計測・アラートの実装は Issue #2694 を open のまま L2 が拾う。

### 関連正本

[`PROMPT_CACHING_OPUS47_COST_GUIDE.md`](PROMPT_CACHING_OPUS47_COST_GUIDE.md) (キャッシュで 88% 削減 = tier を上げる前にキャッシュ設計) / [`AI_FALLBACK_RUNBOOK.md`](AI_FALLBACK_RUNBOOK.md) (quota 枯渇時の代替経路) / [`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md) §4 (vendor 最新情報の取得機構)。

*Win版#132 part 261 / 2026-06-10 追記 / Issue #2694 ([notebooklm:fdea9e6d:2]) 基準 1 充足 — Issue 中の特定モデル名 (Composer 2 等) は未検証ベンダー主張として採用せず、tier 抽象で定義*
