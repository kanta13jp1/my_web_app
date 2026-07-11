# Issue Fix Plan #3773

- Issue: [[追加要望] 🔴P0 dailyBriefingスレッド(URL最終リプライ)を投稿する日次cronを新設](https://github.com/kanta13jp1/my_web_app/issues/3773)
- Labels: 追加要望,priority:critical,growth,launch
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/29138697171

## Goal

[追加要望] 🔴P0 dailyBriefingスレッド(URL最終リプライ)を投稿する日次cronを新設

## Current Context

```text
## なぜ最優先
H5検証の前提。現在Xへ投稿するcronは `post-x-with-media.yml`(単発static)のみで、**dailyBriefingスレッド/questionPost/usefulReplyを投げるcronが0件**(.github/workflows grep=0)。→実データが溜まらずA/Bが始まらない。手動の『AIシェア→生成→投稿』に依存している。

## やること
- [AUTO] 毎日07:00 JST cron → `growth-hub x.post`(dailyBriefing variant, replyTexts populated=実スレッド, URLは最終リプライ) を DRY_RUN=false で投稿
- フックはニュース/AI briefing(実績ある高impressionパターン)。BiPは信頼層(slot2)に
- 既存 x-post-metrics-optimizer(3h cron)がインプレを自動蓄積 → performance_context が勝ちパターン学習
- concurrency + 二重投稿ガード + X API tier/レート考慮

## 受け入れ条件
- 毎日1本、URLをリプライに回したスレッドが自動投稿される
- x_post_log/x_post_metric_snapshot にvariant別データが蓄積し始める
統括 #3771 / 親 #3663

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
