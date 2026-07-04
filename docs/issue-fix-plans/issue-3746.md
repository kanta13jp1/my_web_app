# Issue Fix Plan #3746

- Issue: [[追加要望][first-user] T2: 知人5人へ直接DM招待（テンプレ完成済）](https://github.com/kanta13jp1/my_web_app/issues/3746)
- Labels: 追加要望,priority:critical,acquisition,first-user
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28694540873

## Goal

[追加要望][first-user] T2: 知人5人へ直接DM招待（テンプレ完成済）

## Current Context

```text
**P0 / owner=user（送信）+claude（テンプレ済）**

最初の1人の最短経路。**知人・同僚・家族から5人**に直接DM。

### DMテンプレ（完成済・関係性に合わせ調整）
```
久しぶり！実は1人でWebアプリをずっと作ってて、やっと人に見せられる形になったんだ。

「自分株式会社」っていう、人生を会社経営っぽく管理するアプリ（家計・資産・タスク・AI相談が1つになってる）。

無料だから5分だけ触ってみてもらえないかな？
「ここ分かりにくい」だけでもすごく助かる🙏
https://my-web-app-b67f4.web.app/
```

### 手順
1. 「触ってくれそうな人」を5人リストアップ（テック系でなくてOK。家計管理は万人向け）
2. 個別に送る（一斉送信しない）
3. 触ってくれたら**感想を1つだけ**聞く（「どこで詰まった？」）

### 受け入れ条件
- 5人に送付済
- 1人以上がサインアップ（=スプリント成功）
- 詰まりフィードバックを Issue 化

統括: #3744


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
