# Issue Fix Plan #1125

- Issue: [[追加要望] Build in Public成果化パイプラインでDeveloper Winsを外部発信する](https://github.com/kanta13jp1/my_web_app/issues/1125)
- Labels: enhancement,priority:medium,ux,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26320086973

## Goal

[追加要望] Build in Public成果化パイプラインでDeveloper Winsを外部発信する

## Current Context

```text
## 背景

NotebookLM `DEV Community Newsletter: AI Evolution and Developer Wins` から、AIエージェント時代の開発成果は、機能実装だけでなく、DEV Community記事、ハッカソン応募、学習コンテンツ、Build in Public投稿として外部に見える形へ変換することが重要だと整理できる。

参照: https://notebooklm.google.com/notebook/27730002-fe8c-40ff-b2c3-431ab8f40a9a

このプロジェクトには `DevelopmentAchievementsCard`、AI大学、週次ドラフト、ブログ下書き、GitHub Issue/PR運用があるため、開発成果を自動で「発信可能な実績」に変換する土台がある。

## 追加したいもの

GitHub Issue/PR、AI大学更新、競合レポート、実装済み機能、CI復旧などのイベントから `Developer Wins` を抽出し、外部発信用ドラフトへ変換するパイプラインを追加する。

出力例:

- DEV Community向け技術記事ドラフト
- X/LinkedIn向けBuild in Public投稿
- ハッカソン応募用の成果サマリー
- AI大学の「今週の学び」カード
- ランディングページや実績カードに載せる短い成果文

## 想定スコープ

- 既存 `DevelopmentAchievementsCard` / `growth_achievement_summary` / `weekly-drafts` / `blog-drafts` のデータを再利用
- GitHub Issue/PR番号、変更ファイル、成果カテゴリ、ユーザー価値、学びを抽出する `developer_wins` 形式を定義
- `schedule-hub` または既存自動生成ワークフローで週次ドラフトを生成
- 初期版は手動承認前提で、外部投稿の自動公開は対象外
- AI大学・ニュースRSS・ブログ下書きへの導線を追加

## 受け入れ条件

- 直近1週間の開発成果から、3〜5件のDeveloper Winsが自動抽出される
- 各Winに「何を作ったか」「誰に価値があるか」「学び」「外部発信用タイトル案」が含まれる
- DEV Community記事ドラフトと短文SNSドラフトを生成できる
- 自動公開せず、ユーザー承認後に利用する設計になっている
- `flutter analyze` が通る

## 関連・重複回避

- #924 はパーソナルAIモーニング・ポッドキャスト生成が主眼。本Issueは開発成果の外部発信化が主眼。
- #975 はAI回答の永続ナレッジ化が主眼。本IssueはGitHub/開発ログをマーケティング・採用・コミュニティ成果へ変換することが主眼。

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
