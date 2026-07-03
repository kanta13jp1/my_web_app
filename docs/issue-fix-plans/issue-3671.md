# Issue Fix Plan #3671

- Issue: [[追加要望] Product Hunt / Hacker News ローンチ資産一式を作成し初回ローンチを実行](https://github.com/kanta13jp1/my_web_app/issues/3671)
- Labels: priority:high,追加要望,growth,acquisition,launch
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28638350826

## Goal

[追加要望] Product Hunt / Hacker News ローンチ資産一式を作成し初回ローンチを実行

## Current Context

```text
**P1 / launch / owner=user**

アプリ・billing・PRESS_RELEASE_V1・771本のblog draftが揃っているが、最初のユーザー群を/billingへ送る具体的なPH/HNローンチ資産も日付計画も無い(future-datedドラフトのみ)。test実証済プロダクトを最初の実課金ユーザーへ転換する具体行動。

### 受け入れ条件
- PRESS_RELEASE_V1 を元にPHリスティング(タグライン/ギャラリー/maker comment/first comment)を用意
- ローンチ日を確定しスケジュール
- ローンチ導線が/billing(料金可視)へ着地することを確認
- ローンチ流入を計測できるUTM/チャネルタグを付与

統括: #3663 ／ 親: 収益化 #3639


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
