# Issue Fix Plan #3744

- Issue: [[追加要望] 🎯 最初の外部ユーザー1人獲得 統括（first-user sprint）](https://github.com/kanta13jp1/my_web_app/issues/3744)
- Labels: 追加要望,priority:critical,growth,acquisition,first-user
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28768624953

## Goal

[追加要望] 🎯 最初の外部ユーザー1人獲得 統括（first-user sprint）

## Current Context

```text
## 🎯 最初の外部ユーザー「1人」を獲得する（first-user sprint）

課金パイプライン・法務・使用量ゲートは完成済み（#3639）。成長基盤の監査も完了（#3663）。
**しかしユーザーが0なら入金は永遠に発生しない。** 本Issueは「最初の1人」に特化した最小・即実行のスプリントを統括する。

### 戦略（SEOや自動投稿は"待ち"の施策 → 1人目は"攻め"で獲る）
1人目に最も確率が高いのは **(a) 知人への直接招待** と **(b) X個人開発コミュニティへの手動ローンチ投稿**。既存の自動コンテンツ投稿（Qiita/dev.to日次）は中長期の畑であり、1人目には遅い。

### 子タスク
- [ ] T1 (P0/user): X ローンチ投稿（下書き完成済 → コピペ+スクショ1枚で投稿）
- [ ] T2 (P0/user): 知人5人へ直接DM招待（テンプレ完成済）
- [ ] T3 (P0/claude): 新規ユーザー初回動線スモークチェック（landing→サインアップ→初価値到達の詰まり検査）
- [ ] T4 (P1/claude): 新規サインアップのSlack即時通知（ユーザー#1到来を見逃さない）
- [ ] T5 (P1/user+claude): Zenn/note 個人開発ストーリー記事（一人称「作った理由」+リンク）
- [ ] T6 (P2/user): 個人開発コミュニティ投稿（r/SideProject 等）

### 成功条件
**運営者本人以外の新規サインアップ +1**（admin analytics の users.list / daily-metrics users.total で確認）

親: 成長統括 #3663 ／ 収益化統括 #3639（PHローンチ #3671 は次波）


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
