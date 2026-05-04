# Issue Fix Plan #1557

- Issue: [[追加要望][P0] CI失敗Issueの重複統合・根因クラスタリング・自動クローズ](https://github.com/kanta13jp1/my_web_app/issues/1557)
- Labels: enhancement,workflow-failure,automation,追加要望,priority:critical
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25296335682

## Goal

[追加要望][P0] CI失敗Issueの重複統合・根因クラスタリング・自動クローズ

## Current Context

```text
## 背景

2026-05-02時点で `Deploy to Production (main)` の失敗Issueが複数 (#1552, #1554) あり、同一workflow/同一根因のIssueが増えるとWBSの上位タスクが見えにくくなる。Codex #2担当領域として、red CIを修復するだけでなく、失敗の重複を自動でまとめ、解決後に閉じるところまで自動化したい。

## 目的

GitHub Actions失敗Issueを workflow/run/root-cause 単位でクラスタリングし、既存Issueへ追記、重複Issueのclose、復旧検知まで自動化する。

## 受け入れ条件

- [ ] workflow name + branch + failing step + error signature から root-cause key を生成できる
- [ ] 同一keyのopen issueがある場合は新規Issueを作らずコメント追記する
- [ ] 復旧runを検知したら該当Issueへ成功run URLを追記し、条件を満たせば自動closeする
- [ ] migration衝突、Supabase push失敗、Deno lint、Flutter analyze/build、Notion sync失敗を分類できる
- [ ] `workflow-failure` Issueの件数・平均復旧時間をdaily reportまたはWBS overviewに出せる
- [ ] 自動closeはGitHub Actionsの成功runと同一root-cause key確認を必須にする

## 担当分担

- Codex #2: failure digest、GitHub Issue更新、workflow連携
- Claude Code: 自動close条件と例外ルールのレビュー
- GitHub Actions: root-cause key生成と復旧検知

## 関連

- #1552
- #1554
- #1553
- #1307
- #862
- `scripts/ci_failure_digest.py`
- `docs/automation/ci-cd-stability.md`


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
