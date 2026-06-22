# Issue Fix Plan #831

- Issue: [[追加要望] CARBS風ライフリソース最適化ダッシュボード](https://github.com/kanta13jp1/my_web_app/issues/831)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25895651447

## Goal

[追加要望] CARBS風ライフリソース最適化ダッシュボード

## Current Context

```text
## 背景

NotebookLM `2fc6d86f-2bbd-4fdc-ad9e-f302d93b5c6e` のImbue資料では、CARBS（Cost-Aware HPO）のように、性能だけでなく計算コストを含めて最適化する考え方が強調されている。

自分株式会社では、時間・体力・集中力・お金・AI実行コストがすべて「経営資源」になる。これを見える化し、ROIの高い行動へ誘導できると、経営コックピットの価値が上がる。

## 追加要望

タスクや習慣、AI実行、学習/開発活動を `期待インパクト` と `消費リソース` で比較し、今日/今週の最適な資源配分を提案するダッシュボードを追加する。

## 実装スコープ案

- タスク単位に `所要時間`、`精神負荷`、`金銭コスト`、`期待成果`、`期限リスク` を持たせる
- CFO/CSO/ホームのいずれかに「資源配分」カードを追加
- 簡易スコアリングで `高ROI`、`低コスト即効`、`保留推奨` を分類
- 将来のAIコストやNotebookLM/外部AI利用ログとも接続できる設計にする

## 受け入れ条件

- [ ] 既存タスクまたは新規入力にリソース見積もりを付与できる
- [ ] 今日/今週の推奨アクションが理由付きで表示される
- [ ] コスト過多または効果不明のタスクが警告される
- [ ] スコアリングロジックがサービス層に分離され、テストされる
- [ ] UI上で少なくとも3分類（高ROI/低コスト即効/保留推奨）が確認できる

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
