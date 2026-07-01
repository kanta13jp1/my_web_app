# Issue Fix Plan #3668

- Issue: [[追加要望] サインイン中アプリにアップグレード常設導線+使用量ナッジ(AI質問 N/30 今月)を追加](https://github.com/kanta13jp1/my_web_app/issues/3668)
- Labels: priority:high,ux,追加要望,monetization,growth
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28487230525

## Goal

[追加要望] サインイン中アプリにアップグレード常設導線+使用量ナッジ(AI質問 N/30 今月)を追加

## Current Context

```text
**P1 / conversion / owner=claude**

アプリ内アップグレード入口がツールカタログタイルとapp_hubボタンしか無く、home_pageにアップグレードバナーもAI機能近傍の使用量表示も無い。壁に当たる前に '残りN回' を見せることが転換動機になる。

### 受け入れ条件
- AI機能近傍に '今月 N/30' の使用量表示を出す
- homeに'アップグレード'チップ(/billing)を常設
- subscription_billing_page.dart:332-356 の_UsageCardに30上限+残数をprogress barで表示
- Proユーザーには上限表示を出さない(または無制限表示)

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
