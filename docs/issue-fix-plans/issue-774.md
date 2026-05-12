# Issue Fix Plan #774

- Issue: [[追加要望] PDF・非定型テキストからの構造化データ抽出パイプライン](https://github.com/kanta13jp1/my_web_app/issues/774)
- Labels: 追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25142953566

## Goal

[追加要望] PDF・非定型テキストからの構造化データ抽出パイプライン

## Current Context

```text
NotebookLM ノートブック `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`（Writer AI Studio Comprehensive Development and Management Guide）に基づく追加要望です。

## 背景
Writer AI Studio では Structured outputs、PDF parser、SDK/API連携により、PDFや自由記述テキストをJSONなどの機械可読形式へ変換するユースケースが強調されています。本プロジェクトでも、追加要望、議員データ、WBSタスク、NotebookLMメモ、スクリーンショット説明、外部レポートなど、非定型情報を手作業で整理する場面が多くあります。

## 要望
PDF・長文メモ・自由記述・メール本文・NotebookLM要約などをアップロード/貼り付けすると、AIがスキーマに沿って構造化し、WBSタスク・GitHub Issue・KGI/CSF/KPI・データテーブルへ変換できる機能を追加したいです。

## 期待する成果
- 追加要望や調査資料を手入力で整形する負担を減らせる
- AIがJSON形式で安定出力し、Supabase登録やIssue作成にそのまま使える
- PDF資料や長文NotebookLMメモから、実行可能タスクを自動抽出できる
- データ取り込み時の抜け漏れと表記ゆれを減らせる

## 実装メモ
- まずは `title`, `summary`, `category`, `priority`, `kgi`, `csf`, `kpi`, `tasks[]`, `sources[]` の共通スキーマを定義
- 追加要望フォーム、WBS、AI大学、地方選管理室など複数機能で再利用
- PDFはStorageアップロード後にテキスト抽出し、LLMで構造化
- 出力はユーザーが確認してからGitHub Issue/WBSに登録する

## 受け入れ条件
- [ ] 長文テキストから構造化JSONを生成できる
- [ ] 生成JSONをプレビューし、ユーザーが編集・承認できる
- [ ] 承認後にGitHub IssueまたはWBSタスクへ登録できる
- [ ] PDFまたは添付ファイルの取り込み導線がある

## 分類
- カテゴリ: 機能追加
- 優先度: medium
- 情報源: NotebookLM `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`

## WBS連携
このIssueは追加要望としてWBSのユーザー要望タスクにも反映対象です。

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
