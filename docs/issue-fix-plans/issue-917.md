# Issue Fix Plan #917

- Issue: [[追加要望] WBS/学習向け対話型AIアバターコーチ](https://github.com/kanta13jp1/my_web_app/issues/917)
- Labels: enhancement,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25616776463

## Goal

[追加要望] WBS/学習向け対話型AIアバターコーチ

## Current Context

```text
## 背景
NotebookLM対象資料では、D-ID APIの柱として「低遅延なリアルタイムAIエージェント」と、独自の知識ベース/LLMを組み合わせた対話型デジタルプレゼンターの構築が紹介されている。

my_web_appにはWBS、AI大学、ロードマップ、開発原則、ユーザータスクがあり、ユーザーが詰まった時に文章だけでなく、アバターが順を追って説明する体験にするとオンボーディングと実行支援が強くなる。

## 追加要望
WBS/学習/業務タスクに対して、AIアバターが口頭説明・質疑応答・次アクション提示を行う「対話型AIアバターコーチ」を追加する。

## MVPスコープ
- WBSユーザータスク詳細に「アバターに説明してもらう」ボタンを追加する
- タスク名、期限、進捗、関連メモをもとに説明台本を生成する
- 音声/動画生成は非同期MVP、将来的にリアルタイム対話へ拡張できる設計にする
- AI大学の学習項目でも同じ説明コンポーネントを使えるようにする
- 生成した説明履歴をタスク/学習ログに残す

## 受け入れ条件
- WBSタスクから「なぜ必要か」「何から始めるか」「次の3手」が動画または音声付きで説明される
- 生成内容に対象タスクID/生成日時/利用モデル/参照データが記録される
- 生成中、完了、失敗、再生成の状態がUIで分かる
- 将来のD-IDリアルタイムエージェントへ差し替え可能な抽象インターフェースになっている

## NotebookLM根拠
- D-ID Quickstart: リアルタイムAIエージェント、知識ベース、LLM統合、インタラクティブなデジタルプレゼンターの実装パターン
- D-ID事例資料: 医療訓練、認知症ケア、企業マーケティング等でパーソナライズ動画が信頼構築とエンゲージメント向上に寄与
- Canva連携資料: 外部制作ツール内でテキスト/音声付き動画を簡単に生成する導線が重要

Notebook: https://notebooklm.google.com/notebook/da2a95d1-2db3-4677-9e67-52fae69fb8e9

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
