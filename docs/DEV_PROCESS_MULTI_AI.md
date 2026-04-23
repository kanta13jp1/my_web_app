# 開発プロセス Multi-AI Routing Matrix — 自分株式会社

> 作成: 2026-04-24 PS#1 S26 / Win版#132 part 3 改訂
>
> **目的**: Claude Code quota枯渇・障害時に開発を停止させない。
> AI ツールを役割分担し、月 $20 プランで $200 相当の開発速度を維持する。

---

## 1. 強制 Task Routing Matrix

**このルールに従って AI を選択する。Claude Code は「判断・統合・memory管理」のみ。**

| タスク種別 | **Primary** | **Secondary** | **Tertiary** | Claude Code 役割 |
| --- | --- | --- | --- | --- |
| 行レベル補完 (< 10行) | GitHub Copilot | — | — | **不使用** |
| 5分以内の修正 | Copilot Inline Chat | — | — | **不使用** |
| 500行超リファクタリング | Gemini Code Assist | Copilot | Claude Code | 事前レビューのみ |
| SQL / アルゴリズム最適化 | OpenAI Codex | Copilot | Claude Code | 仕様確認のみ |
| Migration (DDL + seed SQL) | **Codex** (template ベース) | Copilot | Claude Code | 命名則チェック |
| AI大学 provider 追加 (seed SQL) | **Codex** (既存 SQL コピー改変) | — | Claude Code | routing 判断のみ |
| ブログ・競合リサーチ | Claude Code WEB版 (WebSearch) | NotebookLM | Gemini Search | — |
| NotebookLM Deep Research | Win版 CLI | Gemini Research | — | 統合・要約のみ |
| UI/デザイン (新コンポーネント) | Claude Code VSCode版 + design-skills | Figma MCP | Copilot | 設計レビュー |
| アーキテクチャ判断 | **Claude Code** | NotebookLM + Copilot Chat | — | **専任** |
| Dart バグ修正 (< 50行) | Copilot Inline Chat | Claude Code PS#5 | — | 必要時のみ |
| EF バグ修正 (Deno) | Copilot / Claude Code VSCode | Codex | — | 必要時のみ |
| GHA Workflow 作成・修正 | Claude Code PS#1 | Copilot | gh CLI スクリプト | WF health 専任 |
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
| `blog-engagement.yml` | Claude Haiku | ❌ 未実装 | 要対応 |
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

| 優先度 | タスク | 担当 | 完了目標 |
| --- | --- | --- | --- |
| 🔴 **P0** | blog-draft.yml Gemini fallback | ✅ PS#1 S26 | 2026-04-24 |
| 🔴 **P0** | `GOOGLE_AI_API_KEY` repo secretsに追加 | **ユーザー手動** | 2026-04-25 |
| 🟠 **P1** | ai-hub EF 自動quota routing | VSCode版 | 2026-04-26 |
| 🟠 **P1** | blog-engagement.yml Gemini fallback | PS#2 | 2026-04-28 |
| 🟠 **P1** | claude-agent-review.yml skip-on-quota | PS#1 | 2026-05-01 |
| 🟡 **P2** | cs-check.yml Gemini fallback | PS#1 | 2026-05-05 |
| 🟡 **P2** | Slack quota alert webhook | Win版 | 2026-05-10 |
| 🟢 **P3** | Notion WBS mirror | Win版 | 2026-05-15 |

---

## 7. KPI (効果測定)

| 指標 | 目標 | 現在 |
| --- | --- | --- |
| Claude quota枯渇時の継続可能タスク率 | 70%+ | ~40% |
| GHA schedule Claude依存ワークフロー中 fallback実装済み比率 | 80%+ | 12.5% (1/8) |
| EF Claude依存中 fallback実装済み比率 | 60%+ | 0% |
| 月次 Claude token 消費量削減 | -30% | 未測定 |
