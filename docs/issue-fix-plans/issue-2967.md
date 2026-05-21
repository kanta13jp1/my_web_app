# Issue Fix Plan #2967

- Issue: [[追加要望][P1][NotebookLM] Requirements to Issues の認証Secret復旧と失敗時Issue通知](https://github.com/kanta13jp1/my_web_app/issues/2967)
- Labels: enhancement,priority:high,automation,追加要望,wbs,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26199880176

## Goal

[追加要望][P1][NotebookLM] Requirements to Issues の認証Secret復旧と失敗時Issue通知

## Current Context

```text
## 背景
`NotebookLM Requirements to Issues` は「notebooklm list で取得できる全Notebookから追加要望を3件ずつ抽出し、GitHub Issuesへ登録する」日次自動化の本線です。

直近2回の実行は `NOTEBOOKLM_STORAGE_STATE_JSON` が空のため、`Restore NotebookLM auth` で失敗しています。

- 失敗run: https://github.com/kanta13jp1/my_web_app/actions/runs/26129712472
- 失敗run: https://github.com/kanta13jp1/my_web_app/actions/runs/26064395006
- ローカル確認: `notebooklm list --json` も認証切れ

## 要望
- GitHub Actions secret `NOTEBOOKLM_STORAGE_STATE_JSON` を最新のNotebookLM storage stateで復旧する
- 復旧後に `NotebookLM Requirements to Issues` を manual dispatch し、全Notebookを対象に3件ずつ追加要望を抽出する
- 成功後、`GitHub Issues WBS Sync` と `WBS Auto Reschedule` を実行してWBSへ反映する
- Secret未設定/期限切れ時は単に赤いworkflowで終わらせず、既存Issueへコメントまたは専用Issueを更新して次アクションを明示する

## 受け入れ条件
- `NotebookLM Requirements to Issues` が成功する
- `docs/notebooklm-requirements/latest-report.md` に実行サマリが残る
- 既存 marker `notebooklm-requirement:<notebook-id>:<slot>` による重複Issue抑止が効く
- 作成された追加要望IssueがWBSへ同期され、現実的な日程にリスケされる

## 2インスタンス運用
- Claude Code #1: NotebookLM認証更新と抽出内容の妥当性レビュー
- Codex #1: workflow/Issue/WBS同期、CI確認、重複抑止、失敗時の自動通知修正

## WBSメモ
`SUPABASE_SERVICE_ROLE_KEY` がローカルに無いため、WBS反映は `GitHub Issues WBS Sync` と `WBS Auto Reschedule` 経由で行う。

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
