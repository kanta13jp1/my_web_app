# Issue Fix Plan #772

- Issue: [[追加要望] Writer AI Studio型ナレッジグラフ/RAG検索アシスタント](https://github.com/kanta13jp1/my_web_app/issues/772)
- Labels: 追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25029207574

## Goal

[追加要望] Writer AI Studio型ナレッジグラフ/RAG検索アシスタント

## Current Context

```text
NotebookLM ノートブック `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`（Writer AI Studio Comprehensive Development and Management Guide）に基づく追加要望です。

## 背景
Writer AI Studio は Knowledge Graph / RAG を中核に、社内ドキュメントや業務ナレッジを根拠付きで検索・回答できるエンタープライズAI基盤として整理されています。本プロジェクトにも CLAUDE.md、WBS、GitHub Issues、ROADMAP、NotebookLMメモ、Supabaseデータなど知識源が分散しており、ユーザーが「どこに何があるか」を毎回探す負荷が高くなっています。

## 要望
プロジェクト内の主要データを横断検索し、回答に引用元を付ける「自分株式会社 Knowledge Graph / RAG アシスタント」を追加したいです。

## 期待する成果
- GitHub Issues / WBS / docs / memory / NotebookLM由来メモを自然言語で横断検索できる
- 回答に根拠リンクや参照元を出せるため、AI回答の信頼性が上がる
- 「過去に似た要望があるか」「この機能の仕様はどこか」を即時確認できる
- サイト内チャットボットの回答品質を底上げできる

## 実装メモ
- 既存のサイト質問チャットボット / ai-hub / WBS連携と接続
- docs、GitHub Issues、WBSタスク、schedule_task_runs などをインデックス対象にする
- 回答には `source_type`, `source_url`, `confidence`, `last_synced_at` を含める
- 初期版は Supabase pgvector または既存テーブル検索 + LLM要約で開始し、後続でKnowledge Graph化

## 受け入れ条件
- [ ] ユーザーが自然言語でプロジェクト情報を質問できる
- [ ] 回答に少なくとも1件以上の引用元が表示される
- [ ] GitHub Issues / WBS / docs のうち2種類以上を横断検索できる
- [ ] 既存チャットボットまたは専用ページから利用できる

## 分類
- カテゴリ: 機能追加
- 優先度: high
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
