# Issue Fix Plan #1696

- Issue: [[追加要望][P2] 自動コミット多発時のPR BEHIND解消とmerge queue運用を整備する](https://github.com/kanta13jp1/my_web_app/issues/1696)
- Labels: enhancement,priority:medium,automation,追加要望,wbs
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/27111089452

## Goal

[追加要望][P2] 自動コミット多発時のPR BEHIND解消とmerge queue運用を整備する

## Current Context

```text
﻿## 背景
Codex #2でPR #1695を処理中、`自動: ヘルスモニター` 系の定期コミットが `main` に入るたびにPRが `BEHIND` となり、同じPRで複数回のrebase / force-with-lease / CI待ちが必要になりました。

## 追加要望
スケジュールタスクや自動コミットと並行しても、Codex/Claude Codeの実装PRが安全に前へ進めるよう、PR自動更新・merge queue相当の運用を整備してください。

## 候補方針
- GitHub branch protection / merge queue の利用可否を確認する
- `main` へ頻繁に入る自動ヘルスモニターコミットをまとめる、またはPRチェック時間帯と競合しにくいスケジュールに調整する
- Codex作業PRに `BEHIND` が出たら、CI成功後に安全にrebaseして再実行するGitHub Actions/手順を用意する
- force-with-lease とPR本文のMinimal E2E宣言更新を runbook 化する

## 受け入れ条件
- [ ] PRが `BEHIND` のまま滞留する件数を可視化できる
- [ ] 自動コミットが多い時間帯でもCodex/Claude Code PRを安全にマージできる手順がある
- [ ] 必要ならGitHub Actionsまたはgh CLI runbookで自動更新できる
- [ ] WBS/Issue同期に運用手順が反映される

## 関連
- 発見元: PR #1695 / Issue #1682
- Codex #2担当領域: CI、同期、operations、GitHub Actions、deterministic automation


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
