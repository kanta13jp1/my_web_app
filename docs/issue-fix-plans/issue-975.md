# Issue Fix Plan #975

- Issue: [[追加要望] Query to Wiki: AI回答を永続ナレッジ化する保存ワークフロー](https://github.com/kanta13jp1/my_web_app/issues/975)
- Labels: enhancement,priority:medium,ux,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26263614793

## Goal

[追加要望] Query to Wiki: AI回答を永続ナレッジ化する保存ワークフロー

## Current Context

```text
## 背景
NotebookLM「Claude Code and Obsidian: Building Your AI Second Brain」では、AIとのQueryで得た良い比較表、洞察、手順、意思決定を一時的なチャット回答で終わらせず、Wikiへ保存して次回以降の文脈に再利用することがAI第二の脳の価値として説明されている。

本プロジェクトにはAIシェア、WBSユーザータスクAI支援、AI大学、成長診断など、価値あるAI出力が複数ある。これらを永続ノート化できる導線があると、ユーザーの知識資産が積み上がる。

Source: https://notebooklm.google.com/notebook/9871b0b1-0748-4d7d-99bc-bd6aea2231f6

## 要望
AI回答・診断結果・WBS手順・比較表などに「Wikiへ保存」ボタンを追加し、Markdownノートとして永続保存できるようにする。

## 想定仕様
- 対象画面: WBSユーザータスク、AIシェア、成長診断、AI大学、競合比較、NotebookLM連携画面
- 保存時にAIがタイトル、要約、タグ、関連タスク、関連Issue、関連ノート候補を生成
- 保存先ノートを新規作成または既存ノートへ追記できる
- 保存後は該当タスクやIssueから逆参照できる
- ノート本文には「生成日時」「入力元」「利用モデル」「元リンク」を残す

## 受け入れ条件
- AI回答のUIから1クリックで保存ダイアログを開ける
- 保存前にMarkdownプレビューを確認できる
- 保存されたノートが検索対象になる
- WBSタスクまたはGitHub Issueに関連づけた場合、元画面から保存ノートへ遷移できる
- 同じ回答を重複保存しようとした場合、既存ノート候補が提示される

## 補足
最初は「WBSユーザータスクAI支援」の分割結果・詳細手順から実装すると効果検証しやすい。

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
