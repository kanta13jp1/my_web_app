# Issue Fix Plan #926

- Issue: [[追加要望] 12インスタンス並行開発のリアルタイム競合予測を追加する](https://github.com/kanta13jp1/my_web_app/issues/926)
- Labels: enhancement,priority:high,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25086042680

## Goal

[追加要望] 12インスタンス並行開発のリアルタイム競合予測を追加する

## Current Context

```text
## 背景
NotebookLM `jibun-master-brain` には、Claude Code 10インスタンス + Codex 2インスタンスの並行開発、固定worktree、WBS/GitHub同期、Deno linterによる巻き戻し対策、migration衝突対策などの運用知見が蓄積されています。今後さらに並行度が上がるほど、同一ファイル編集やmigration timestamp衝突の予防が重要になります。

## 要望
各インスタンスの作業開始時・git add前・migration作成時に、他インスタンスの作業状況や直近PR/コミットを見て競合リスクを予測し、High/Medium/Lowで警告する仕組みを追加したいです。

## 期待する挙動
- session start / handoff / git add 前に、対象ファイルと他インスタンスの担当範囲を照合する
- migration作成時に空いているtimestampを提案する
- 競合リスクと理由をコンソール、Slack、Notion/WBSのいずれかへ通知する
- NotebookLM Master Brainへ競合事例と回避策を蓄積できる

## 受け入れ条件
- `.claude` hook または既存スクリプトに競合予測ステップが追加される
- 競合リスク、該当ファイル、関連PR/Issue、推奨アクションが表示される
- migration timestamp の衝突候補を検出し、代替timestampを提案できる
- 通知先（Slack/Notion/WBS）の有効/無効を設定できる

## 優先度
High

## NotebookLM根拠
- Notebook: `jibun-master-brain` / `ea6cff25-574d-4b8b-ad72-ab47cf1ed01f`
- 12インスタンス運用、WBS同期、Deno lint巻き戻し、migration競合対策の記録に基づく追加要望

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
