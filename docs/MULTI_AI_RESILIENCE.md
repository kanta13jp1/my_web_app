# Multi-AI Resilience Architecture — 自分株式会社

> 作成: 2026-04-24 PS#1 S26
> 背景: Claude quota枯渇 → 開発プロセス完全停止リスクを解消するため

---

## 問題定義

Claude Code に単一依存した場合のリスク:

| リスク | 影響 |
| --- | --- |
| Claude quota枯渇 | スケジュールタスク全停止・エラーループ |
| Claude API 障害 | EF 10本が同時停止 (ai-hub等) |
| Claude Code インスタンス制限 | 開発作業ブロック |

---

## Provider Tier 設計

### Tier 1: 一次プロバイダー

| タスク種別 | 一次 | 理由 |
| --- | --- | --- |
| アーキテクチャ判断 / complex code | Claude Code | Memory + プロジェクト文脈 |
| GHA バッチ生成 (blog draft等) | Claude Haiku 4.5 | 低コスト・高速 |
| EF API routing | Claude Haiku 4.5 | ai-hub provider |
| 行補完 | GitHub Copilot | ゼロ待機・常時利用可 |

### Tier 2: 一次フォールバック (quota/障害時)

| タスク種別 | 二次 | トリガー条件 |
| --- | --- | --- |
| GHA バッチ生成 | Gemini Flash 2.0 | HTTP 429/529 or API key未設定 |
| EF API routing | Gemini Flash 2.0 | Anthropic quota exhausted |
| 500行超リファクタリング | Gemini Code Assist | Claude token budget超過 |
| SQL/アルゴリズム最適化 | OpenAI Codex | Claude quota枯渇時 |

### Tier 3: 最終フォールバック

| タスク種別 | 三次 | トリガー条件 |
| --- | --- | --- |
| blog draft生成 | static template | Gemini も失敗 |
| EF API routing | OpenAI GPT-4o-mini | Gemini quota |
| 開発作業 | GitHub Copilot inline | 全Claude quota枯渇 |

---

## GHA スケジュールタスク フォールバック対応状況

| Workflow | Claude依存 | フォールバック | 状態 |
| --- | --- | --- | --- |
| `blog-draft.yml` | Claude Haiku | ✅ Gemini Flash → template | **実装済 (PS#1 S26)** |
| `ai-university-update.yml` | なし (REST直接) | N/A | ✅ 問題なし |
| `blog-engage.yml` | Claude Haiku | ❌ 未実装 | 要対応 |
| `blog-backfill.yml` | Claude Haiku | ❌ 未実装 | 要対応 |
| `claude-agent-review.yml` | Claude Sonnet | ❌ skip-on-quota | 要対応 |
| `blog-verify.yml` | Claude Haiku | ❌ 未実装 | 要対応 |
| `quota-monitor.yml` | 監視のみ | N/A | ✅ 問題なし |

---

## EF (Edge Function) フォールバック対応状況

| EF | Claude依存 | フォールバック | 状態 |
| --- | --- | --- | --- |
| `ai-hub` | Anthropic primary | ⚠️ 他provider選択可 (UI) | 要自動routing改善 |
| `ai-assistant` | Anthropic | ❌ | VSCode版 handoff |
| `competitor-feature-sync` | Anthropic | ❌ | VSCode版 handoff |
| `tools-hub` | なし | N/A | ✅ 問題なし |
| その他 | Gemini/OpenAI | N/A | ✅ provider分散済 |

---

## Quota枯渇時の緊急プロトコル

### Claude quota hit → 即時対応

```
1. [CLAUDE.md注意書き参照] "現在Claudeがクォータ制限に達している"
2. WBS確認 → 着手予定タスクをCodex/VSCode手動に振り替え
3. docs/cross-instance-prs/ に handoff PR 作成
4. GHA スケジュールタスク → Gemini fallback が自動作動
```

### インスタンス優先タスク振り替え表 (quota枯渇時)

| 元担当 | フォールバック手段 |
| --- | --- |
| Win版 (migration/EF) | Codex + GitHub MCP (EF deploy) |
| VSCode版 (UI) | GitHub Copilot inline |
| PS#1 (WF health) | gh CLI + Python スクリプトで自動化 |
| PS#2 (blog dispatch) | blog-draft Gemini fallback + gh workflow run |
| PS#3 (AI大学) | ai-university-update.yml (Claude不要) |
| PS#4 (競合モニタリング) | check-competitor-updates EF (Claude不要) |
| PS#5 (bug fix) | GitHub Copilot + GitHub MCP |
| PS#6 (horse_racing) | cron-batch.yml (Claude不要) |

---

## GHA Quota Guard パターン (再利用テンプレ)

Claude API 呼び出し前に quota チェックを挟むパターン:

```yaml
- name: Check Anthropic quota
  id: quota_check
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    if [ -z "$ANTHROPIC_API_KEY" ]; then
      echo "skip_claude=true" >> $GITHUB_OUTPUT
      echo "⚠️ ANTHROPIC_API_KEY not set"
      exit 0
    fi
    # 429/529 probe
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "https://api.anthropic.com/v1/messages" \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}')
    if [ "$STATUS" = "429" ] || [ "$STATUS" = "529" ]; then
      echo "skip_claude=true" >> $GITHUB_OUTPUT
      echo "⚠️ Claude quota exhausted (HTTP $STATUS) — will use fallback"
    else
      echo "skip_claude=false" >> $GITHUB_OUTPUT
    fi
```

---

## 開発ツール振り分け早見表 (Quota枯渇対応版)

| タスク | 通常時 | Claudeクォータ枯渇時 |
| --- | --- | --- |
| アーキテクチャ判断 | Claude Code | NotebookLM Ask + Copilot Chat |
| コード生成 (< 100行) | Claude Code | GitHub Copilot |
| コード生成 (100-500行) | Claude Code | Codex / Gemini Code Assist |
| Migration SQL | Claude Code | Codex |
| blog draft生成 | Claude Haiku | **Gemini Flash 自動切替** |
| EF api routing | Claude Haiku | **Gemini Flash 自動切替** |
| 競合リサーチ | Claude Code WEB版 | NotebookLM Deep Research |
| PR review | claude-agent-review.yml | GitHub Copilot PR review |
| CI 修復 | PS#1 Claude Code | gh CLI スクリプト |

---

## NotebookLM を開発プロセスに統合

Claude quota枯渇時の重いリサーチは NotebookLM が代替:

```bash
# 競合調査
notebooklm source add-research "Notion 2026 pricing changes competitor analysis"
notebooklm ask "主要変更点と自分株式会社への影響"

# コードリサーチ
notebooklm source add "./lib/pages/landing_page.dart"
notebooklm ask "このファイルのアーキテクチャ上の問題点"

# 過去意思決定の参照
notebooklm use jibun-master-brain
notebooklm ask "Edge Function設計方針の過去の経緯"
```

---

## Slack / Notion 統合 (将来実装候補)

| 機能 | 実装方法 | 優先度 |
| --- | --- | --- |
| Slack quota alert | Supabase EF → Slack webhook | 中 |
| Notion WBS mirror | tools-hub → Notion API sync | 低 |
| Slack daily digest | schedule-hub → Slack DM | 低 |

> **Note**: Slack/Notion 統合は EF-CAP-50 制約を考慮し、既存 hub に action 追加で実装する。

---

## 実装ロードマップ

| 優先度 | タスク | 担当 | 期限 |
| --- | --- | --- | --- |
| 🔴 高 | blog-draft.yml Gemini fallback | ✅ PS#1 S26 完了 | 2026-04-24 |
| 🔴 高 | GOOGLE_AI_API_KEY を repo secretsに追加 | ユーザー手動 | 2026-04-25 |
| 🟠 中 | ai-hub EF: Gemini自動routing改善 | VSCode版 handoff | 2026-04-26 |
| 🟠 中 | blog-engagement.yml Gemini fallback | PS#2 | 2026-04-28 |
| 🟡 低 | claude-agent-review.yml skip-on-quota | PS#1 | 2026-05-01 |
| 🟡 低 | Slack quota alert webhook | Win版 | 2026-05-10 |
