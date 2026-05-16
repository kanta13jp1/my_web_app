# マルチエージェント協調 5 パターン

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L207-235 を移行 (= Karpathy 80 行 KPI 達成).

新しい自動化・AI 機能を設計するとき、以下の 5 パターンから選ぶ. **最も単純なパターンから始めて、行き詰まったら進化させる**.

## 5 パターン早見表

| パターン | 採用基準 | このプロジェクトでの実例 |
| --- | --- | --- |
| **Generator-Verifier** | 品質が最重要. 評価基準を明文化できる | `claude-agent-review.yml` (PR 生成→Claude レビュー) / `ci-auto-fix.yml` (修正→CI 再実行) / `/deep-research` (NotebookLM 生成→Claude 統合) |
| **Orchestrator-Subagent** | タスク分解が明確. サブタスクが短時間で完結 | `cs-check.yml` (FAQ 返信 / バグ修正 / エスカレーション) / `github-issue-fix.yml` (Issue 一覧→1 件ずつ処理) / Claude Code Schedule (計画→実行→コミット) |
| **Agent Teams** | 並行独立した長時間タスク. 成果物が互いに干渉しない | **2 instance fleet** (Win Claude + Win Codex / 旧 12 instance dormant) + Gemini Code Assist / GitHub Copilot / Manus AI 補完 / `ai-university-update.yml` + NotebookLM Master Brain |
| **Message Bus** | イベント駆動. エコシステムが成長する | `workflow-failure-handler.yml` (失敗イベント→Issue→`cs-check`) / `feedback-issue-resolved.yml` (Issue クローズ→通知メール) / `edge-function-audit.yml` (EF 未接続→Issue→`github-issue-fix`) |
| **Shared State** | エージェントが互いの発見を活用. 単一障害点を避けたい | `memory/` + NotebookLM Master Brain (セッション横断知識) / Supabase DB (全 EF が読み書き) / `~/.claude/hooks/inject-rules.txt` (全 instance 共有 state) |

## 新機能設計フロー

```text
品質ゲートが必要? → Generator-Verifier
↓ No
ステップが事前確定? → Orchestrator-Subagent
↓ No
長時間の独立タスク? → Agent Teams (= 新 instance 起動 / 新 workflow)
↓ No
イベント駆動で拡張性が必要? → Message Bus (= 新 workflow_run トリガー)
↓ No
エージェント間でリアルタイム共有が必要? → Shared State (= Supabase テーブル活用)
```

**推奨スタート**: ほとんどのユースケースは **Orchestrator-Subagent** から始める. 行き詰まった箇所を観察してから他パターンに進化させる.

## 2026-05-17 Guarded Subagent Update (#2535)

`Orchestrator-Subagent` is now the approved first pattern for short, scoped
parallel work when it follows `docs/SUBAGENT_ORCHESTRATION_POLICY.md`.

- Claude Code #1 or Codex #1 remains the lead and owns the final decision.
- Subagents are execution helpers, not persistent project instances or WBS
  owners.
- Prefer read-only explorer/reviewer workers before worker subagents that edit
  files.
- `Agent Teams` means durable workflows or explicitly reactivated top-level
  lanes, not ad-hoc spawning of old dormant instances.
- Record role, scope, validation impact, and cleanup impact in PR/Issue/wrap-up
  whenever a subagent materially changes the outcome.

## 関連

- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](AI_FLEET_SYNERGY_PLAYBOOK.md) — fleet 7 原則
- [`docs/MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md) — 2 instance fleet
- [`docs/CODEX_MEMORY_AUTOMATIONS.md`](CODEX_MEMORY_AUTOMATIONS.md) — 25 task ownership matrix
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
