# Multi-AI Resilience Design — 自分株式会社

> 作成: PS版#2 2026-04-24
> 動機: Claude Code quota 枯渇 → 開発プロセス完全停止 の SPOF 解消

---

## 現状の問題

| 障害シナリオ | 影響範囲 | 深刻度 |
|-------------|---------|--------|
| Claude Code CLI quota 枯渇 | 全インスタンス: 新セッション不可 | 🔴 Critical |
| Anthropic API quota 枯渇 | cs-check/blog-engagement/claude-agent-review が error loop | 🔴 Critical |
| claude-agent-review.yml quota 到達 | PR レビュー毎時 → 429 loop | 🟠 High |
| deploy 時 Claude CLI timeout | CI pipeline 停止 | 🟡 Medium |

**コアな問題**: Claude Code Schedule (GHA cron) が `claude` CLI を直接呼び、
quota 枯渇でエラー → cancel-in-progress:false のため次の cron も fail → error loop。

---

## 既存の防衛線 (変更不要)

| コンポーネント | 現状 |
|--------------|------|
| `ai-assistant` EF | Claude → OpenAI → Gemini → DeepSeek の4段フォールバック実装済 ✅ |
| `quota-monitor.yml` | 毎日 09:00 JST に Anthropic 使用量チェック ✅ |
| `cs-check.yml` Step 2 | template返信 (AI 不使用) ✅ |
| blog-publish フォールバック | `ANTHROPIC_API_KEY` 未設定時 → template返信 ✅ |

---

## 新設計: 3層 Resilience Strategy

### Layer 1 — Quota Early Warning (24h前に気づく)

**実装**: `quota-monitor.yml` 拡張

```
Anthropic usage ≥ 70% → GitHub Issue #quota-warning 自動作成
                            → CLAUDE_QUOTA_WARN=1 を Supabase KV に書き込む
Anthropic usage ≥ 90% → CLAUDE_QUOTA_CRITICAL=1
                            → 全 GHA schedule の Claude CLI 呼び出しをスキップフラグ
```

**担当**: PS版#1 (WF health 専任)

### Layer 2 — Schedule Task Fallback Chain

GHA workflow が Claude CLI を使う箇所に fallback を追加:

| Workflow | 現在 | Fallback 1 | Fallback 2 |
|---------|------|------------|------------|
| `claude-agent-review.yml` | Claude Sonnet | Gemini 2.0 Flash (GEMINI_API_KEY) | スキップ (PR label 付与のみ) |
| `blog-engagement.yml` | Claude Haiku | template 返信 | スキップ |
| `github-issue-fix.yml` | Claude | Codex (OPENAI_API_KEY) | Issue comment "needs-human" |
| `blog-draft.yml` | Claude | Gemini | スキップ (下書きなし) |
| `dependency-audit.yml` | Claude | Gemini | スキップ |

**実装パターン** (各 workflow に追加):
```yaml
- name: Check quota flag
  id: quota
  run: |
    FLAG=$(curl -sf "${SUPABASE_URL}/rest/v1/rpc/get_kv?key=CLAUDE_QUOTA_CRITICAL" \
      -H "apikey: ${SUPABASE_ANON_KEY}" | jq -r '.value // "0"')
    echo "critical=$FLAG" >> $GITHUB_OUTPUT

- name: Run with Claude (primary)
  if: steps.quota.outputs.critical != '1'
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: claude ... || echo "claude_failed=1" >> $GITHUB_OUTPUT

- name: Run with Gemini (fallback)
  if: steps.quota.outputs.critical == '1' || steps.primary.outputs.claude_failed == '1'
  env:
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
  run: # Gemini CLI or API call
```

**担当**: Win版 (ai-assistant EF 拡張) + VSCode版 (GHA yaml 修正)

### Layer 3 — Developer Instance Continuity

Claude Code CLI quota 枯渇でセッション開始不可の場合:

| インスタンス | 代替ツール | 移行手順 |
|-------------|----------|---------|
| PS版#1 (WF health) | GitHub Actions GUI + gh CLI | `gh run list` + `gh run view` で監視継続 |
| PS版#2 (T-1 dispatch) | `gh workflow run` スクリプト | `scripts/t1-dispatch.sh` を整備 → Claude 不要 |
| PS版#3 (AI大学) | Gemini Code Assist (VSCode拡張) | Provider metadata は YAML → migration パターン |
| PS版#4 (競合モニタリング) | Gemini CLI + WebSearch | `gemini -p "competitor analysis"` |
| VSCode版 (UI) | GitHub Copilot Chat | デザイン token 適用は Copilot で継続 |
| Win版 (アーキテクチャ) | Gemini Code Assist + Codex | 重い設計は NotebookLM に委譲 |

---

## Multi-AI 開発プロセス マトリクス (改訂版)

```
タスク種別                     | 主担当AI        | Fallback 1      | Fallback 2
------------------------------|----------------|-----------------|---------------
行レベル補完                   | GitHub Copilot  | Gemini Assist   | —
5分以内のインライン修正          | Copilot Chat    | Gemini Chat     | Claude (最後)
アーキテクチャ設計・意思決定      | Claude Code     | NotebookLM分析  | 人間判断
500行超リファクタリング          | Gemini Code     | Claude          | —
SQL / アルゴリズム最適化        | OpenAI Codex    | Claude          | Copilot
ブログ原稿作成                  | Claude Code     | Gemini CLI      | 人間執筆
競合リサーチ                    | NotebookLM      | Gemini WebSearch| —
PR レビュー                    | Claude (GHA)    | Gemini (GHA)    | Copilot review
Supabase migration 生成        | Claude Code     | Codex           | —
Flutter UI 修正                | VSCode+Copilot  | Claude Code     | —
```

**方針**: Claude Code は「判断・設計・統合」専用に温存。
実装補完・コード生成は Copilot/Codex/Gemini に積極委譲。

---

## Slack / Notion 統合 (quota 状態を全インスタンスで共有)

### Slack アラート

`quota-monitor.yml` から Slack Webhook に POST:
```yaml
- name: Slack alert on quota warning
  if: steps.quota.outputs.usage_pct >= 70
  run: |
    curl -sf -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
      -H 'Content-Type: application/json' \
      -d "{\"text\": \"⚠️ Claude quota ${USAGE_PCT}% — switching to Gemini fallback\"}"
```

### Notion ステータスページ (optional)

`CLAUDE_STATUS` データベースに:
- quota_pct: 現在使用率
- active_model: 現在の主担当AI
- last_checked: タイムスタンプ

---

## 実装優先順位

| 優先度 | 項目 | 担当 | 工数 |
|-------|------|------|------|
| P0 | `quota-monitor.yml`: 70%/90% 警告 + KV 書き込み | PS#1 | 30min |
| P0 | `claude-agent-review.yml`: Gemini fallback 追加 | VSCode版 | 45min |
| P1 | `GEMINI_API_KEY` / `OPENAI_API_KEY` secret を GHA に追加 | Win版 | 15min |
| P1 | `scripts/t1-dispatch.sh`: Claude 不要の dispatch スクリプト | PS#2 | 30min |
| P2 | `github-issue-fix.yml`: Codex fallback | VSCode版 | 60min |
| P2 | Slack Webhook 連携 | Win版 | 30min |
| P3 | Notion quota ステータスページ | — | — |

---

## Codex 活用 (Claude 停止時の代替開発フロー)

Claude quota 枯渇時の緊急フロー:

```
1. GitHub Issues に "codex-task" label → github-issue-fix.yml (Codex fallback)
2. Codex が PR 作成 → Claude-agent-review が Gemini でレビュー
3. merge → deploy-prod は Claude 不使用 (Dart format + deploy のみ)
```

Claude 復旧後:
1. `quota-monitor.yml` が 50%以下を検出
2. CLAUDE_QUOTA_CRITICAL=0 にリセット
3. 全 workflow が自動的に Claude 優先に戻る

---

## T-1 Dispatch 無依存化 (PS#2 担当・即実施可)

`gh workflow run blog-publish.yml` は Claude Code 不使用。
blog-publish.yml 自体は ANTHROPIC_API_KEY を使わない (schedule-hub EF 経由)。

→ **PS#2 の T-1 dispatch は Claude Code quota に無依存** ✅

スクリプト化して完全自動化:
```bash
# scripts/t1-dispatch.sh
#!/bin/bash
SLUG=${1:?usage: t1-dispatch.sh <slug>}
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/${SLUG}.md" \
  -f draft_path_en="docs/blog-drafts/${SLUG}-en.md" \
  -f platforms="devto" \
  -f dry_run="false"
```
