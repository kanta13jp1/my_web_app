# Issue Fix Plan #794

- Issue: [[追加要望] Claude Opus 4.7対応の高解像度画像・図表解析機能](https://github.com/kanta13jp1/my_web_app/issues/794)
- Labels: enhancement,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25198208714

## Goal

[追加要望] Claude Opus 4.7対応の高解像度画像・図表解析機能

## Current Context

```text
## 背景
NotebookLM ノート `e89d2ca7-1dc9-41a1-8fe2-bad5103a757b` では、Claude Opus 4.7 の高解像度画像理解・図表解析能力が業務アプリに有効であることが示されています。本プロジェクトでもスクリーンショット、選挙KPI地図、学習結果画像、外部資料画像を扱う場面が増えています。

## 目的
アップロード画像や画面キャプチャから、AIが文字・表・グラフ・KPIを抽出し、追加要望、WBS、AIシェア文言、分析レポートへ再利用できるようにします。

## 主要要件
- 画像アップロードまたは既存添付画像をAI解析に渡せるサービス層を整備する
- 高解像度画像は必要に応じてリサイズし、解析精度とコストのバランスを取る
- 日本地図UIやダッシュボード画像から、主要数値・県名・KGI/KPIを抽出するユースケースを追加する
- 解析結果を追加要望フォーム、AIシェア、WBS登録補助に流用できるようにする

## 受け入れ条件
- 画像1枚から主要テキストと数値を抽出できる
- 日本地図UIのスクリーンショットから、選択県・KGI/KPI・現状当選率などの主要情報を抽出できる
- 解析結果をユーザーが確認して、追加要望またはシェア文言に反映できる

## 参考
https://notebooklm.google.com/notebook/e89d2ca7-1dc9-41a1-8fe2-bad5103a757b

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
