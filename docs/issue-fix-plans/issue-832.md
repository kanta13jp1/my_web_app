# Issue Fix Plan #832

- Issue: [[追加要望] 評価データ品質ゲートと自己ベンチマーク再設計](https://github.com/kanta13jp1/my_web_app/issues/832)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25411900264

## Goal

[追加要望] 評価データ品質ゲートと自己ベンチマーク再設計

## Current Context

```text
## 背景

NotebookLM `2fc6d86f-2bbd-4fdc-ad9e-f302d93b5c6e` のImbue資料では、70Bモデル評価において低品質な評価データを除外し、推論・コード理解を測るための評価セットを整える姿勢が重要視されている。

自分株式会社でも、AI役員会議、AI大学、競合比較、WBS進捗などのAI生成情報が増えている。出力量が増えるほど、根拠の薄い情報や曖昧な自己評価が混じるリスクがあるため、評価品質を管理する仕組みが必要。

## 追加要望

AI出力・学習記録・タスク進捗に対して、根拠、再現性、成果への接続を評価する「品質ゲート」と「自己ベンチマーク」を追加する。

## 実装スコープ案

- AI出力に `根拠あり/要確認/推測` の分類を付与
- タスク完了時に `成果物`、`検証方法`、`学び`、`次回改善` を記録
- AI大学やNotebookLM由来コンテンツにはソース・更新日・信頼度を表示
- 自己ベンチマークとして、意思決定品質や学習定着度を週次で振り返る

## 受け入れ条件

- [ ] AI生成コンテンツまたはタスク報告に品質ステータスを保存できる
- [ ] 根拠不足の項目がUI上で識別できる
- [ ] 完了タスクに検証方法と成果物リンク/メモを記録できる
- [ ] 週次の自己ベンチマーク画面またはカードで品質推移が見える
- [ ] 評価ロジックと表示のテストが追加される

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
