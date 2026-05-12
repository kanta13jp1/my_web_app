# Issue Fix Plan #924

- Issue: [[追加要望] パーソナルAIモーニング・ポッドキャストを自動生成する](https://github.com/kanta13jp1/my_web_app/issues/924)
- Labels: enhancement,priority:medium,ux,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25708023379

## Goal

[追加要望] パーソナルAIモーニング・ポッドキャストを自動生成する

## Current Context

```text
## 背景
NotebookLM `jibun-master-brain` では、WBS、AI大学、NotebookLM、Slack/Notion、動画・音声生成パイプラインなどが横断的に運用されています。一方で、ユーザーは当日の重要タスクや学習進捗、家計・コスト状況を画面で能動的に確認する必要があります。

## 要望
毎朝、ユーザーの当日優先タスク、予定、AI大学の学習進捗、家計・AIコストの注意点をAIが短い台本にまとめ、音声ブリーフィングとして生成・再生できるようにしたいです。

## 期待する挙動
- WBS / スケジュール / AI大学 / 家計・コスト情報から当日の要点を収集する
- AIが1〜3分程度の日本語ブリーフィング台本を生成する
- ElevenLabs等のTTSで音声化し、ホーム画面に「今日のポッドキャスト」として表示する
- 生成に失敗した場合は、テキスト版ブリーフィングをフォールバック表示する

## 受け入れ条件
- Edge Function または既存 hub に `morning_briefing.audio_generate` 相当のアクションがある
- GitHub Actions またはスケジューラで毎朝自動生成できる
- ホーム画面から最新音声を再生できる
- 生成元データと生成日時がUIで確認できる

## 優先度
Medium

## NotebookLM根拠
- Notebook: `jibun-master-brain` / `ea6cff25-574d-4b8b-ad72-ab47cf1ed01f`
- 3層メモリアーキテクチャ、WBS同期、音声・動画生成パイプラインの運用記録に基づく追加要望

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
