# Issue Fix Plan #1787

- Issue: [[追加要望][P1][AI Tool 2026-05] Claude Code v2.1.126 + Codex gpt-5.5 + Copilot Custom Agents + Gemini 2.5 Pro/Flash GA — 開発フロー改善適用](https://github.com/kanta13jp1/my_web_app/issues/1787)
- Labels: enhancement,priority:high,automation,追加要望,ai-tool-update
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25707114335

## Goal

[追加要望][P1][AI Tool 2026-05] Claude Code v2.1.126 + Codex gpt-5.5 + Copilot Custom Agents + Gemini 2.5 Pro/Flash GA — 開発フロー改善適用

## Current Context

```text
## 概要
2026-05時点の4大AIツール最新機能をプロジェクトに反映する。

## Claude Code v2.1.126 新機能
- `claude project purge [path]` — project 状態完全削除 (--dry-run/--all 対応) → 定期クリーンアップ routine 追加候補
- `/recap` — セッション復帰時コンテキスト補完 → 12インスタンス handoff 改善
- Push notification tool — Remote Control 連携でモバイル Push 送信 → 承認待ち通知自動化 (Issue #1752 と連携)
- `/focus` コマンド — focus view トグル
- `/skills` type-to-filter — skill 検索改善

## Codex CLI 新機能
- **gpt-5.5 推奨モデル** — 複雑タスクに最適/Codex#1/#2 の推奨モデル更新必要
- Multi-environment management — 複数 worktree × remote 環境の同時管理
- AWS Bedrock 統合 — SigV4 + AWS creds → Codex on Bedrock PoC (Issue #1583 と連携)
- `codex exec --json` reasoning token 使用量報告 → コスト監視改善
- Plugin marketplace — remote bundle caching + hook enablement state

## GitHub Copilot 新機能
- **Model picker in Agents panel** — タスク種別別モデル選択 → routing matrix 更新
- **自己レビュー before PR** — PR 前に Copilot が自分で review → claude-agent-review.yml の補完として活用
- **Security scanning integration** — PR 前に自動セキュリティスキャン → CI パイプライン組込み
- **Custom Agents (.github/agents/)** — チーム固有 agent コード化 → horse racing / AI大学 専用 agent 設計
- **JetBrains agent mode GA** (2026-03) — Java/Kotlin 開発者向け

## Gemini Code Assist 新機能
- **Gemini 2.5 Pro/Flash GA** — chat/code gen/transform に採用 → fallback 品質向上
- コード補完速度改善 (VS Code Extension 2.41.0)
- IntelliJ chat stop button → 長時間応答のキャンセル対応
- Duet AI plugin preview

## 適用先
- [ ] docs/AI_FALLBACK_RUNBOOK.md — 各ツール能力/推奨モデル更新 (Win版担当)
- [ ] docs/DEV_PROCESS_MULTI_AI.md — routing matrix 更新 (Codex gpt-5.5 / Copilot model picker)
- [ ] CLAUDE.md インスタンス別推奨モデル表 — Codex#1/#2 gpt-5.5 更新
- [ ] .github/agents/ — Copilot Custom Agents 設計 (Codex#2 担当)
- [ ] inject-rules.txt / settings.json — /recap 活用 hook 追加検討

## 担当候補
- AI_FALLBACK_RUNBOOK + DEV_PROCESS_MULTI_AI: Win版
- Copilot Custom Agents: Codex#2

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
